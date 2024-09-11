import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:thermion_dart/thermion_dart/compatibility/compatibility.dart';
import 'package:thermion_dart/thermion_dart/entities/gizmo.dart';
import 'package:thermion_dart/thermion_dart/matrix_helper.dart';
import 'package:thermion_dart/thermion_dart/scene.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
import 'thermion_viewer.dart';
import 'scene_impl.dart';
import 'package:logging/logging.dart';

typedef ThermionViewerImpl = ThermionViewerFFI;

// ignore: constant_identifier_names
const ThermionEntity _FILAMENT_ASSET_ERROR = 0;

typedef RenderCallback = Pointer<NativeFunction<Void Function(Pointer<Void>)>>;

double kNear = 0.05;
double kFar = 1000.0;
double kFocalLength = 28.0;

class ThermionViewerFFI extends ThermionViewer {
  final _logger = Logger("ThermionViewerFFI");

  SceneImpl? _scene;
  Scene get scene => _scene!;

  double pixelRatio = 1.0;

  Pointer<Void>? _sceneManager;

  Pointer<Void>? _viewer;

  final String? uberArchivePath;

  final _initialized = Completer<bool>();
  Future<bool> get initialized => _initialized.future;

  ///
  ///
  ///
  @override
  Stream<FilamentPickResult> get pickResult => _pickResultController.stream;
  final _pickResultController =
      StreamController<FilamentPickResult>.broadcast();

  @override
  Stream<FilamentPickResult> get gizmoPickResult =>
      _gizmoPickResultController.stream;
  final _gizmoPickResultController =
      StreamController<FilamentPickResult>.broadcast();

  final Pointer<Void> resourceLoader;

  var _driver = nullptr.cast<Void>();

  late final RenderCallback _renderCallback;
  var _renderCallbackOwner = nullptr.cast<Void>();

  var _sharedContext = nullptr.cast<Void>();

  ///
  /// This controller uses platform channels to bridge Dart with the C/C++ code for the Filament API.
  /// Setting up the context/texture (since this is platform-specific) and the render ticker are platform-specific; all other methods are passed through by the platform channel to the methods specified in ThermionFlutterApi.h.
  ///
  ThermionViewerFFI(
      {RenderCallback? renderCallback,
      Pointer<Void>? renderCallbackOwner,
      required this.resourceLoader,
      Pointer<Void>? driver,
      Pointer<Void>? sharedContext,
      this.uberArchivePath}) {
    this._renderCallbackOwner = renderCallbackOwner ?? nullptr;
    this._renderCallback = renderCallback ?? nullptr;
    this._driver = driver ?? nullptr;
    this._sharedContext = sharedContext ?? nullptr;

    _onPickResultCallable =
        NativeCallable<Void Function(EntityId entityId, Int x, Int y)>.listener(
            _onPickResult);

    _onGizmoPickResultCallable =
        NativeCallable<Void Function(EntityId entityId, Int x, Int y)>.listener(
            _onGizmoPickResult);

    _initialize();
  }

  Future createRenderTarget(
      double width, double height, int textureHandle) async {
    await withVoidCallback((callback) => create_render_target_ffi(
        _viewer!, textureHandle, width.toInt(), height.toInt(), callback));
  }

  Future updateViewportAndCameraProjection(double width, double height) async {
    viewportDimensions = (width * pixelRatio, height * pixelRatio);
    update_viewport(_viewer!, width.toInt(), height.toInt());
    var mainCamera = get_camera(_viewer!, await getMainCamera());
    var near = await getCameraCullingNear();
    if (near.abs() < 0.000001) {
      near = kNear;
    }
    var far = await getCameraCullingFar();
    if (far.abs() < 0.000001) {
      far = kFar;
    }

    var aspect = viewportDimensions.$1 / viewportDimensions.$2;
    var focalLength = get_camera_focal_length(mainCamera);
    if (focalLength.abs() < 0.1) {
      focalLength = kFocalLength;
    }
    set_camera_lens_projection(mainCamera, near, far, aspect, focalLength);
  }

  Future createSwapChain(double width, double height,
      {Pointer<Void>? surface}) async {
    await withVoidCallback((callback) {
      create_swap_chain_ffi(_viewer!, surface ?? nullptr, width.toInt(),
          height.toInt(), callback);
    });
  }

  Future destroySwapChain() async {
    await withVoidCallback((callback) {
      destroy_swap_chain_ffi(_viewer!, callback);
    });
  }

  Gizmo? _gizmo;
  Gizmo? get gizmo => _gizmo;

  Future _initialize() async {
    final uberarchivePtr =
        uberArchivePath?.toNativeUtf8(allocator: allocator).cast<Char>() ??
            nullptr;
    var viewer = await withVoidPointerCallback(
        (Pointer<NativeFunction<Void Function(Pointer<Void>)>> callback) {
      create_filament_viewer_ffi(_sharedContext, _driver, uberarchivePtr,
          resourceLoader, _renderCallback, _renderCallbackOwner, callback);
    });
    _viewer = Pointer.fromAddress(viewer);
    allocator.free(uberarchivePtr);
    if (_viewer!.address == 0) {
      throw Exception("Failed to create viewer. Check logs for details");
    }

    _sceneManager = get_scene_manager(_viewer!);
    _scene = SceneImpl(this);

    await setCameraManipulatorOptions(zoomSpeed: 1.0);

    final gizmoEntities = allocator<Int32>(4);
    get_gizmo(_sceneManager!, gizmoEntities);
    _gizmo = Gizmo(gizmoEntities[0], gizmoEntities[1], gizmoEntities[2],
        gizmoEntities[3], this);
    allocator.free(gizmoEntities);
    this._initialized.complete(true);
  }

  bool _rendering = false;

  ///
  ///
  ///
  @override
  bool get rendering => _rendering;

  ///
  ///
  ///
  @override
  Future setRendering(bool render) async {
    _rendering = render;
    await withVoidCallback((cb) {
      set_rendering_ffi(_viewer!, render, cb);
    });
  }

  ///
  ///
  ///
  @override
  Future render() async {
    render_ffi(_viewer!);
  }

  ///
  ///
  ///
  @override
  Future<Uint8List> capture() async {
    final length = this.viewportDimensions.$1.toInt() *
        this.viewportDimensions.$2.toInt() *
        4;
    final out = allocator<Uint8>(length);
    await withVoidCallback((cb) {
      capture_ffi(_viewer!, out, cb);
    });
    final data = Uint8List.fromList(out.asTypedList(length));
    allocator.free(out);
    return data;
  }

  ///
  ///
  ///
  @override
  Future setFrameRate(int framerate) async {
    final interval = 1000.0 / framerate;
    set_frame_interval_ffi(_viewer!, interval);
  }

  final _onDispose = <Future Function()>[];

  ///
  ///
  ///
  @override
  Future dispose() async {
    if (_viewer == null) {
      // we've already cleaned everything up, ignore the call to dispose
      return;
    }
    await setRendering(false);
    await clearEntities();
    await clearLights();
    await _scene!.dispose();
    _scene = null;
    destroy_filament_viewer_ffi(_viewer!);

    _sceneManager = null;
    _viewer = null;
    await _pickResultController.close();

    for (final callback in _onDispose) {
      await callback.call();
    }
    _onDispose.clear();
  }

  ///
  ///
  ///
  void onDispose(Future Function() callback) {
    _onDispose.add(callback);
  }

  ///
  ///
  ///
  @override
  Future clearBackgroundImage() async {
    clear_background_image_ffi(_viewer!);
  }

  ///
  ///
  ///
  @override
  Future setBackgroundImage(String path, {bool fillHeight = false}) async {
    final pathPtr = path.toNativeUtf8(allocator: allocator).cast<Char>();
    await withVoidCallback((cb) {
      set_background_image_ffi(_viewer!, pathPtr, fillHeight, cb);
    });

    allocator.free(pathPtr);
  }

  ///
  ///
  ///
  @override
  Future setBackgroundColor(double r, double g, double b, double a) async {
    set_background_color_ffi(_viewer!, r, g, b, a);
  }

  ///
  ///
  ///
  @override
  Future setBackgroundImagePosition(double x, double y,
      {bool clamp = false}) async {
    set_background_image_position_ffi(_viewer!, x, y, clamp);
  }

  ///
  ///
  ///
  @override
  Future loadSkybox(String skyboxPath) async {
    final pathPtr = skyboxPath.toNativeUtf8(allocator: allocator).cast<Char>();

    await withVoidCallback((cb) {
      load_skybox_ffi(_viewer!, pathPtr, cb);
    });

    allocator.free(pathPtr);
  }

  ///
  ///
  ///
  @override
  Future createIbl(double r, double g, double b, double intensity) async {
    create_ibl(_viewer!, r, g, b, intensity);
  }

  ///
  ///
  ///
  @override
  Future loadIbl(String lightingPath, {double intensity = 30000}) async {
    final pathPtr =
        lightingPath.toNativeUtf8(allocator: allocator).cast<Char>();
    load_ibl_ffi(_viewer!, pathPtr, intensity);
  }

  ///
  ///
  ///
  @override
  Future rotateIbl(Matrix3 rotationMatrix) async {
    var floatPtr = allocator<Float>(9);
    for (int i = 0; i < 9; i++) {
      floatPtr[i] = rotationMatrix.storage[i];
    }
    rotate_ibl(_viewer!, floatPtr);
    allocator.free(floatPtr);
  }

  ///
  ///
  ///
  @override
  Future removeSkybox() async {
    remove_skybox_ffi(_viewer!);
  }

  ///
  ///
  ///
  @override
  Future removeIbl() async {
    remove_ibl_ffi(_viewer!);
  }

  ///
  ///
  ///
  @override
  Future<ThermionEntity> addLight(
      LightType type,
      double colour,
      double intensity,
      double posX,
      double posY,
      double posZ,
      double dirX,
      double dirY,
      double dirZ,
      {double falloffRadius = 1.0,
      double spotLightConeInner = pi / 8,
      double spotLightConeOuter = pi / 4,
      double sunAngularRadius = 0.545,
      double sunHaloSize = 10.0,
      double sunHaloFallof = 80.0,
      bool castShadows = true}) async {
    var entity = await withIntCallback((callback) => add_light_ffi(
        _viewer!,
        type.index,
        colour,
        intensity,
        posX,
        posY,
        posZ,
        dirX,
        dirY,
        dirZ,
        falloffRadius,
        spotLightConeInner,
        spotLightConeOuter,
        sunAngularRadius = 0.545,
        sunHaloSize = 10.0,
        sunHaloFallof = 80.0,
        castShadows,
        callback));
    if (entity == _FILAMENT_ASSET_ERROR) {
      throw Exception("Failed to add light to scene");
    }

    _scene!.registerLight(entity);
    return entity;
  }

  ///
  ///
  ///
  @override
  Future removeLight(ThermionEntity entity) async {
    _scene!.unregisterLight(entity);
    remove_light_ffi(_viewer!, entity);
  }

  ///
  ///
  ///
  @override
  Future clearLights() async {
    clear_lights_ffi(_viewer!);

    _scene!.clearLights();
  }

  ///
  ///
  ///
  @override
  Future<ThermionEntity> createInstance(ThermionEntity entity) async {
    var created = create_instance(_sceneManager!, entity);
    if (created == _FILAMENT_ASSET_ERROR) {
      throw Exception("Failed to create instance");
    }
    return created;
  }

  ///
  ///
  ///
  @override
  Future<int> getInstanceCount(ThermionEntity entity) async {
    return get_instance_count(_sceneManager!, entity);
  }

  ///
  ///
  ///
  @override
  Future<List<ThermionEntity>> getInstances(ThermionEntity entity) async {
    var count = await getInstanceCount(entity);
    var out = allocator<Int32>(count);
    get_instances(_sceneManager!, entity, out);
    var instances = <ThermionEntity>[];
    for (int i = 0; i < count; i++) {
      instances.add(out[i]);
    }
    allocator.free(out);
    return instances;
  }

  ///
  ///
  ///
  @override
  Future<ThermionEntity> loadGlb(String path,
      {bool unlit = false, int numInstances = 1, bool keepData = false}) async {
    if (unlit) {
      throw Exception("Not yet implemented");
    }
    final pathPtr = path.toNativeUtf8(allocator: allocator).cast<Char>();
    var entity = await withIntCallback((callback) => load_glb_ffi(
        _sceneManager!, pathPtr, numInstances, keepData, callback));
    allocator.free(pathPtr);
    if (entity == _FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading the asset at $path");
    }
    _scene!.registerEntity(entity);

    return entity;
  }

  ///
  ///
  ///
  @override
  Future<ThermionEntity> loadGlbFromBuffer(Uint8List data,
      {bool unlit = false, int numInstances = 1, bool keepData = false}) async {
    if (unlit) {
      throw Exception("Not yet implemented");
    }

    var entity = await withIntCallback((callback) => load_glb_from_buffer_ffi(
        _sceneManager!,
        data.address,
        data.length,
        numInstances,
        keepData,
        callback));

    if (entity == _FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading GLB from buffer");
    }
    _scene!.registerEntity(entity);
    return entity;
  }

  ///
  ///
  ///
  @override
  Future<ThermionEntity> loadGltf(String path, String relativeResourcePath,
      {bool keepData = false}) async {
    final pathPtr = path.toNativeUtf8(allocator: allocator).cast<Char>();
    final relativeResourcePathPtr =
        relativeResourcePath.toNativeUtf8(allocator: allocator).cast<Char>();
    var entity = await withIntCallback((callback) => load_gltf_ffi(
        _sceneManager!, pathPtr, relativeResourcePathPtr, keepData, callback));
    allocator.free(pathPtr);
    allocator.free(relativeResourcePathPtr);
    if (entity == _FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading the asset at $path");
    }
    _scene!.registerEntity(entity);

    return entity;
  }

  ///
  ///
  ///
  @override
  Future panStart(double x, double y) async {
    grab_begin(_viewer!, x * pixelRatio, y * pixelRatio, true);
  }

  ///
  ///
  ///
  @override
  Future panUpdate(double x, double y) async {
    grab_update(_viewer!, x * pixelRatio, y * pixelRatio);
  }

  ///
  ///
  ///
  @override
  Future panEnd() async {
    grab_end(_viewer!);
  }

  ///
  ///
  ///
  @override
  Future rotateStart(double x, double y) async {
    grab_begin(_viewer!, x * pixelRatio, y * pixelRatio, false);
  }

  ///
  ///
  ///
  @override
  Future rotateUpdate(double x, double y) async {
    grab_update(_viewer!, x * pixelRatio, y * pixelRatio);
  }

  ///
  ///
  ///
  @override
  Future rotateEnd() async {
    grab_end(_viewer!);
  }

  ///
  ///
  ///
  @override
  Future setMorphTargetWeights(
      ThermionEntity entity, List<double> weights) async {
    if (weights.isEmpty) {
      throw Exception("Weights must not be empty");
    }
    var weightsPtr = allocator<Float>(weights.length);

    for (int i = 0; i < weights.length; i++) {
      weightsPtr[i] = weights[i];
    }
    var success = await withBoolCallback((cb) {
      set_morph_target_weights_ffi(
          _sceneManager!, entity, weightsPtr, weights.length, cb);
    });
    allocator.free(weightsPtr);

    if (!success) {
      throw Exception(
          "Failed to set morph target weights, check logs for details");
    }
  }

  ///
  ///
  ///
  @override
  Future<List<String>> getMorphTargetNames(
      ThermionEntity entity, ThermionEntity childEntity) async {
    var names = <String>[];

    var count = await withIntCallback((callback) =>
        get_morph_target_name_count_ffi(
            _sceneManager!, entity, childEntity, callback));
    var outPtr = allocator<Char>(255);
    for (int i = 0; i < count; i++) {
      get_morph_target_name(_sceneManager!, entity, childEntity, outPtr, i);
      names.add(outPtr.cast<Utf8>().toDartString());
    }
    allocator.free(outPtr);
    return names.cast<String>();
  }

  Future<List<String>> getBoneNames(ThermionEntity entity,
      {int skinIndex = 0}) async {
    var count = get_bone_count(_sceneManager!, entity, skinIndex);
    var out = allocator<Pointer<Char>>(count);
    for (int i = 0; i < count; i++) {
      out[i] = allocator<Char>(255);
    }

    get_bone_names(_sceneManager!, entity, out, skinIndex);
    var names = <String>[];
    for (int i = 0; i < count; i++) {
      var namePtr = out[i];
      names.add(namePtr.cast<Utf8>().toDartString());
    }
    return names;
  }

  ///
  ///
  ///
  @override
  Future<List<String>> getAnimationNames(ThermionEntity entity) async {
    var animationCount = get_animation_count(_sceneManager!, entity);
    var names = <String>[];
    var outPtr = allocator<Char>(255);
    for (int i = 0; i < animationCount; i++) {
      get_animation_name(_sceneManager!, entity, outPtr, i);
      names.add(outPtr.cast<Utf8>().toDartString());
    }
    allocator.free(outPtr);

    return names;
  }

  ///
  ///
  ///
  @override
  Future<double> getAnimationDuration(
      ThermionEntity entity, int animationIndex) async {
    var duration =
        get_animation_duration(_sceneManager!, entity, animationIndex);

    return duration;
  }

  ///
  ///
  ///
  @override
  Future<double> getAnimationDurationByName(
      ThermionEntity entity, String name) async {
    var animations = await getAnimationNames(entity);
    var index = animations.indexOf(name);
    if (index == -1) {
      throw Exception("Failed to find animation $name");
    }
    return getAnimationDuration(entity, index);
  }

  Future clearMorphAnimationData(ThermionEntity entity) async {
    var meshEntities = await getChildEntities(entity, true);

    for (final childEntity in meshEntities) {
      clear_morph_animation(_sceneManager!, childEntity);
    }
  }

  ///
  ///
  ///
  @override
  Future setMorphAnimationData(
      ThermionEntity entity, MorphAnimationData animation,
      {List<String>? targetMeshNames}) async {
    var meshNames = await getChildEntityNames(entity, renderableOnly: true);
    if (targetMeshNames != null) {
      for (final targetMeshName in targetMeshNames) {
        if (!meshNames.contains(targetMeshName)) {
          throw Exception(
              "Error: mesh ${targetMeshName} does not exist under the specified entity. Available meshes : ${meshNames}");
        }
      }
    }

    var meshEntities = await getChildEntities(entity, true);

    // Entities are not guaranteed to have the same morph targets (or share the same order),
    // either from each other, or from those specified in [animation].
    // We therefore set morph targets separately for each mesh.
    // For each mesh, allocate enough memory to hold FxM 32-bit floats
    // (where F is the number of Frames, and M is the number of morph targets in the mesh).
    // we call [extract] on [animation] to return frame data only for morph targets that present in both the mesh and the animation
    for (int i = 0; i < meshNames.length; i++) {
      var meshName = meshNames[i];
      var meshEntity = meshEntities[i];

      if (targetMeshNames?.contains(meshName) == false) {
        _logger.info("Skipping $meshName, not contained in target");
        continue;
      }

      var meshMorphTargets = await getMorphTargetNames(entity, meshEntity);

      var intersection = animation.morphTargets
          .toSet()
          .intersection(meshMorphTargets.toSet())
          .toList();

      if (intersection.isEmpty) {
        throw Exception(
            """No morph targets specified in animation are present on mesh $meshName. 
            If you weren't intending to animate every mesh, specify [targetMeshNames] when invoking this method.
            Animation morph targets: ${animation.morphTargets}\n
            Mesh morph targets ${meshMorphTargets}
            Child meshes: ${meshNames}""");
      }

      var indices =
          intersection.map((m) => meshMorphTargets.indexOf(m)).toList();

      var frameData = animation.extract(morphTargets: intersection);

      assert(frameData.length == animation.numFrames * intersection.length);

      var dataPtr = allocator<Float>(frameData.length);

      // not currently working on WASM :( wasted a lot of time figuring that out as no error is thrown
      // dataPtr
      //     .asTypedList(frameData.length)
      //     .setRange(0, frameData.length, frameData);
      for (int i = 0; i < frameData.length; i++) {
        dataPtr[i] = frameData[i];
      }

      final idxPtr = allocator<Int>(indices.length);

      for (int i = 0; i < indices.length; i++) {
        idxPtr[i] = indices[i];
      }

      var result = set_morph_animation(
          _sceneManager!,
          meshEntity,
          dataPtr,
          idxPtr,
          indices.length,
          animation.numFrames,
          animation.frameLengthInMs);
      allocator.free(dataPtr);
      allocator.free(idxPtr);
      if (!result) {
        throw Exception("Failed to set morph animation data for ${meshName}");
      }
    }
  }

  ///
  /// Currently, scale is not supported.
  ///
  @override
  Future addBoneAnimation(ThermionEntity entity, BoneAnimationData animation,
      {int skinIndex = 0,
      double fadeOutInSecs = 0.0,
      double fadeInInSecs = 0.0,
      double maxDelta = 1.0}) async {
    if (animation.space != Space.Bone &&
        animation.space != Space.ParentWorldRotation) {
      throw UnimplementedError("TODO - support ${animation.space}");
    }
    if (skinIndex != 0) {
      throw UnimplementedError("TODO - support skinIndex != 0 ");
    }
    var boneNames = await getBoneNames(entity);
    var restLocalTransformsRaw = allocator<Float>(boneNames.length * 16);
    get_rest_local_transforms(_sceneManager!, entity, skinIndex,
        restLocalTransformsRaw, boneNames.length);
    var restLocalTransforms = <Matrix4>[];
    for (int i = 0; i < boneNames.length; i++) {
      var values = <double>[];
      for (int j = 0; j < 16; j++) {
        values.add(restLocalTransformsRaw[(i * 16) + j]);
      }
      restLocalTransforms.add(Matrix4.fromList(values));
    }
    allocator.free(restLocalTransformsRaw);

    var numFrames = animation.frameData.length;

    var data = allocator<Float>(numFrames * 16);

    var bones = await Future.wait(List<Future<ThermionEntity>>.generate(
        boneNames.length, (i) => getBone(entity, i)));

    for (int i = 0; i < animation.bones.length; i++) {
      var boneName = animation.bones[i];
      var entityBoneIndex = boneNames.indexOf(boneName);
      if (entityBoneIndex == -1) {
        _logger.warning("Bone $boneName not found, skipping");
        continue;
      }
      var boneEntity = bones[entityBoneIndex];

      var baseTransform = restLocalTransforms[entityBoneIndex];

      var world = Matrix4.identity();
      // this odd use of ! is intentional, without it, the WASM optimizer gets in trouble
      var parentBoneEntity = (await getParent(boneEntity))!;
      while (true) {
        if (!bones.contains(parentBoneEntity!)) {
          break;
        }
        world = restLocalTransforms[bones.indexOf(parentBoneEntity!)] * world;
        parentBoneEntity = (await getParent(parentBoneEntity))!;
      }

      world = Matrix4.identity()..setRotation(world.getRotation());
      var worldInverse = Matrix4.identity()..copyInverse(world);

      for (int frameNum = 0; frameNum < numFrames; frameNum++) {
        var rotation = animation.frameData[frameNum][i].rotation;
        var translation = animation.frameData[frameNum][i].translation;
        var frameTransform =
            Matrix4.compose(translation, rotation, Vector3.all(1.0));
        var newLocalTransform = frameTransform.clone();
        if (animation.space == Space.Bone) {
          newLocalTransform = baseTransform * frameTransform;
        } else if (animation.space == Space.ParentWorldRotation) {
          newLocalTransform =
              baseTransform * (worldInverse * frameTransform * world);
        }
        for (int j = 0; j < 16; j++) {
          data.elementAt((frameNum * 16) + j).value =
              newLocalTransform.storage[j];
        }
      }

      add_bone_animation(
          _sceneManager!,
          entity,
          skinIndex,
          entityBoneIndex,
          data,
          numFrames,
          animation.frameLengthInMs,
          fadeOutInSecs,
          fadeInInSecs,
          maxDelta);
    }
    allocator.free(data);
  }

  ///
  ///
  ///
  Future<Matrix4> getLocalTransform(ThermionEntity entity) async {
    final ptr = allocator<Float>(16);

    get_local_transform(_sceneManager!, entity, ptr);
    var data = List<double>.filled(16, 0.0);
    for (int i = 0; i < 16; i++) {
      data[i] = ptr[i];
    }
    allocator.free(ptr);
    return Matrix4.fromList(data);
  }

  ///
  ///
  ///
  Future<Matrix4> getWorldTransform(ThermionEntity entity) async {
    final ptr = allocator<Float>(16);

    get_world_transform(_sceneManager!, entity, ptr);
    var data = List<double>.filled(16, 0.0);
    for (int i = 0; i < 16; i++) {
      data[i] = ptr[i];
    }
    allocator.free(ptr);
    return Matrix4.fromList(data);
  }

  ///
  ///
  ///
  Future setTransform(ThermionEntity entity, Matrix4 transform) async {
    final ptr = allocator<Float>(16);
    for (int i = 0; i < 16; i++) {
      ptr[i] = transform[i];
    }
    set_transform(_sceneManager!, entity, ptr);
    allocator.free(ptr);
  }

  ///
  ///
  ///
  Future updateBoneMatrices(ThermionEntity entity) async {
    var result = await withBoolCallback((cb) {
      update_bone_matrices_ffi(_sceneManager!, entity, cb);
    });
    if (!result) {
      throw Exception("Failed to update bone matrices");
    }
  }

  ///
  ///
  ///
  Future<Matrix4> getInverseBindMatrix(ThermionEntity parent, int boneIndex,
      {int skinIndex = 0}) async {
    final ptr = allocator<Float>(16);

    get_inverse_bind_matrix(_sceneManager!, parent, skinIndex, boneIndex, ptr);
    var data = List<double>.filled(16, 0.0);
    for (int i = 0; i < 16; i++) {
      data[i] = ptr[i];
    }
    allocator.free(ptr);
    return Matrix4.fromList(data);
  }

  ///
  ///
  ///
  Future<ThermionEntity> getBone(ThermionEntity parent, int boneIndex,
      {int skinIndex = 0}) async {
    if (skinIndex != 0) {
      throw UnimplementedError("TOOD");
    }
    return get_bone(_sceneManager!, parent, skinIndex, boneIndex);
  }

  ///
  ///
  ///
  @override
  Future setBoneTransform(
      ThermionEntity entity, int boneIndex, Matrix4 transform,
      {int skinIndex = 0}) async {
    if (skinIndex != 0) {
      throw UnimplementedError("TOOD");
    }
    final ptr = allocator<Float>(16);
    for (int i = 0; i < 16; i++) {
      ptr[i] = transform.storage[i];
    }
    var result = await withBoolCallback((cb) {
      set_bone_transform_ffi(
          _sceneManager!, entity, skinIndex, boneIndex, ptr, cb);
    });

    allocator.free(ptr);
    if (!result) {
      throw Exception("Failed to set bone transform");
    }
  }

  ///
  ///
  ///
  ///
  ///
  ///
  @override
  Future resetBones(ThermionEntity entity) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    await withVoidCallback((cb) {
      reset_to_rest_pose_ffi(_sceneManager!, entity, cb);
    });
  }

  ///
  ///
  ///
  ///
  ///
  ///
  @override
  Future removeEntity(ThermionEntity entity) async {
    _scene!.unregisterEntity(entity);

    await withVoidCallback(
        (callback) => remove_entity_ffi(_viewer!, entity, callback));
  }

  ///
  ///
  ///
  ///
  ///
  ///
  @override
  Future clearEntities() async {
    await withVoidCallback((callback) {
      clear_entities_ffi(_viewer!, callback);
    });
    _scene!.clearEntities();
  }

  ///
  ///
  ///
  ///
  ///
  ///
  @override
  Future zoomBegin() async {
    scroll_begin(_viewer!);
  }

  ///
  ///
  ///
  @override
  Future zoomUpdate(double x, double y, double z) async {
    scroll_update(_viewer!, x, y, z);
  }

  ///
  ///
  ///
  @override
  Future zoomEnd() async {
    scroll_end(_viewer!);
  }

  ///
  ///
  ///
  @override
  Future playAnimation(ThermionEntity entity, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      double startOffset = 0.0}) async {
    play_animation(_sceneManager!, entity, index, loop, reverse, replaceActive,
        crossfade, startOffset);
  }

  ///
  ///
  ///
  @override
  Future stopAnimation(ThermionEntity entity, int animationIndex) async {
    stop_animation(_sceneManager!, entity, animationIndex);
  }

  ///
  ///
  ///
  @override
  Future stopAnimationByName(ThermionEntity entity, String name) async {
    var animations = await getAnimationNames(entity);
    await stopAnimation(entity, animations.indexOf(name));
  }

  ///
  ///
  ///
  @override
  Future playAnimationByName(ThermionEntity entity, String name,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      bool wait = false}) async {
    var animations = await getAnimationNames(entity);
    var index = animations.indexOf(name);
    var duration = await getAnimationDuration(entity, index);
    await playAnimation(entity, index,
        loop: loop,
        reverse: reverse,
        replaceActive: replaceActive,
        crossfade: crossfade);
    if (wait) {
      await Future.delayed(Duration(milliseconds: (duration * 1000).toInt()));
    }
  }

  ///
  ///
  ///
  @override
  Future setAnimationFrame(
      ThermionEntity entity, int index, int animationFrame) async {
    set_animation_frame(_sceneManager!, entity, index, animationFrame);
  }

  ///
  ///
  ///
  @override
  Future setMainCamera() async {
    set_main_camera(_viewer!);
  }

  Future<ThermionEntity> getMainCamera() async {
    return get_main_camera(_viewer!);
  }

  ///
  ///
  ///
  @override
  Future setCamera(ThermionEntity entity, String? name) async {
    var cameraNamePtr =
        name?.toNativeUtf8(allocator: allocator).cast<Char>() ?? nullptr;
    var result = set_camera(_viewer!, entity, cameraNamePtr);
    allocator.free(cameraNamePtr);
    if (!result) {
      throw Exception("Failed to set camera");
    }
  }

  ///
  ///
  ///
  @override
  Future setToneMapping(ToneMapper mapper) async {
    set_tone_mapping_ffi(_viewer!, mapper.index);
  }

  ///
  ///
  ///
  @override
  Future setPostProcessing(bool enabled) async {
    set_post_processing_ffi(_viewer!, enabled);
  }

  ///
  ///
  ///
  @override
  Future setShadowsEnabled(bool enabled) async {
    set_shadows_enabled(_viewer!, enabled);
  }

  ///
  ///
  ///
  Future setShadowType(ShadowType shadowType) async {
    set_shadow_type(_viewer!, shadowType.index);
  }

  ///
  ///
  ///
  Future setSoftShadowOptions(
      double penumbraScale, double penumbraRatioScale) async {
    set_soft_shadow_options(_viewer!, penumbraScale, penumbraRatioScale);
  }

  ///
  ///
  ///
  @override
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa) async {
    set_antialiasing(_viewer!, msaa, fxaa, taa);
  }

  ///
  ///
  ///
  @override
  Future setBloom(double bloom) async {
    set_bloom_ffi(_viewer!, bloom);
  }

  ///
  ///
  ///
  @override
  Future setCameraFocalLength(double focalLength) async {
    throw Exception("DONT USE");
  }

  ///
  ///
  ///
  Future<double> getCameraFov(bool horizontal) async {
    var mainCamera = get_camera(_viewer!, await getMainCamera());
    return get_camera_fov(mainCamera, horizontal);
  }

  ///
  ///
  ///
  @override
  Future setCameraFov(double degrees, {bool horizontal = true}) async {
    throw Exception("DONT USE");
  }

  ///
  ///
  ///
  @override
  Future setCameraCulling(double near, double far) async {
    throw Exception("DONT USE");
  }

  ///
  ///
  ///
  @override
  Future<double> getCameraCullingNear() async {
    return getCameraNear();
  }

  Future<double> getCameraNear() async {
    var mainCamera = get_camera(_viewer!, await getMainCamera());
    return get_camera_near(mainCamera);
  }

  ///
  ///
  ///
  @override
  Future<double> getCameraCullingFar() async {
    var mainCamera = get_camera(_viewer!, await getMainCamera());
    return get_camera_culling_far(mainCamera);
  }

  ///
  ///
  ///
  @override
  Future setCameraFocusDistance(double focusDistance) async {
    var mainCamera = get_camera(_viewer!, await getMainCamera());
    set_camera_focus_distance(mainCamera, focusDistance);
  }

  ///
  ///
  ///
  @override
  Future setCameraPosition(double x, double y, double z) async {
    var modelMatrix = await getCameraModelMatrix();
    modelMatrix.setTranslation(Vector3(x, y, z));
    await setCameraModelMatrix4(modelMatrix);
  }

  ///
  ///
  ///
  @override
  Future moveCameraToAsset(ThermionEntity entity) async {
    throw Exception("DON'T USE");
  }

  ///
  ///
  ///
  @override
  Future setViewFrustumCulling(bool enabled) async {
    set_view_frustum_culling(_viewer!, enabled);
  }

  ///
  ///
  ///
  @override
  Future setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity) async {
    var mainCamera = get_camera(_viewer!, await getMainCamera());
    set_camera_exposure(mainCamera, aperture, shutterSpeed, sensitivity);
  }

  ///
  ///
  ///
  @override
  Future setCameraRotation(Quaternion quaternion) async {
    var modelMatrix = await getCameraModelMatrix();
    modelMatrix.setRotation(quaternion.asRotationMatrix());
    await setCameraModelMatrix(modelMatrix.storage);
  }

  ///
  ///
  ///
  @override
  Future setCameraModelMatrix(List<double> matrix) async {
    assert(matrix.length == 16);
    await setCameraModelMatrix4(Matrix4.fromList(matrix));
  }

  ///
  ///
  ///
  @override
  Future setCameraModelMatrix4(Matrix4 modelMatrix) async {
    var mainCamera = get_camera(_viewer!, await getMainCamera());
    final out = allocator<double4x4>(1);
    set_camera_model_matrix(mainCamera, out.ref);
    allocator.free(out);
  }

  ///
  ///
  ///
  @override
  Future setCameraLensProjection(
      double near, double far, double aspect, double focalLength) async {
    var mainCamera = get_camera(_viewer!, get_main_camera(_viewer!));
    set_camera_lens_projection(mainCamera, near, far, aspect, focalLength);
  }

  ///
  ///
  ///
  @override
  Future setMaterialColor(ThermionEntity entity, String meshName,
      int materialIndex, double r, double g, double b, double a) async {
    var meshNamePtr = meshName.toNativeUtf8(allocator: allocator).cast<Char>();
    var result = set_material_color(
        _sceneManager!, entity, meshNamePtr, materialIndex, r, g, b, a);
    allocator.free(meshNamePtr);
    if (!result) {
      throw Exception("Failed to set material color");
    }
  }

  ///
  ///
  ///
  @override
  Future transformToUnitCube(ThermionEntity entity) async {
    transform_to_unit_cube(_sceneManager!, entity);
  }

  ///
  ///
  ///
  @override
  Future setPosition(
      ThermionEntity entity, double x, double y, double z) async {
    set_position(_sceneManager!, entity, x, y, z);
  }

  ///
  ///
  ///
  @override
  Future setLightPosition(
      ThermionEntity lightEntity, double x, double y, double z) async {
    set_light_position(_viewer!, lightEntity, x, y, z);
  }

  ///
  ///
  ///
  @override
  Future setLightDirection(
      ThermionEntity lightEntity, Vector3 direction) async {
    direction.normalize();
    set_light_direction(
        _viewer!, lightEntity, direction.x, direction.y, direction.z);
  }

  ///
  ///
  ///
  @override
  Future setRotationQuat(ThermionEntity entity, Quaternion rotation,
      {bool relative = false}) async {
    set_rotation(_sceneManager!, entity, rotation.radians, rotation.x,
        rotation.y, rotation.z, rotation.w);
  }

  ///
  ///
  ///
  @override
  Future setRotation(
      ThermionEntity entity, double rads, double x, double y, double z) async {
    var quat = Quaternion.axisAngle(Vector3(x, y, z), rads);
    await setRotationQuat(entity, quat);
  }

  ///
  ///
  ///
  @override
  Future setScale(ThermionEntity entity, double scale) async {
    set_scale(_sceneManager!, entity, scale);
  }

  ///
  ///
  ///
  Future queueRotationUpdateQuat(ThermionEntity entity, Quaternion rotation,
      {bool relative = false}) async {
    queue_rotation_update(_sceneManager!, entity, rotation.radians, rotation.x,
        rotation.y, rotation.z, rotation.w, relative);
  }

  ///
  ///
  ///
  @override
  Future queueRotationUpdate(
      ThermionEntity entity, double rads, double x, double y, double z,
      {bool relative = false}) async {
    var quat = Quaternion.axisAngle(Vector3(x, y, z), rads);
    await queueRotationUpdateQuat(entity, quat, relative: relative);
  }

  ///
  ///
  ///
  @override
  Future queuePositionUpdate(
      ThermionEntity entity, double x, double y, double z,
      {bool relative = false}) async {
    queue_position_update(_sceneManager!, entity, x, y, z, relative);
  }

  ///
  /// Queues an update to the worldspace position for [entity] to the viewport coordinates {x,y}.
  /// The actual update will occur on the next frame, and will be subject to collision detection.
  ///
  Future queuePositionUpdateFromViewportCoords(
      ThermionEntity entity, double x, double y) async {
    queue_position_update_from_viewport_coords(_sceneManager!, entity, x, y);
  }

  ///
  ///
  ///
  Future queueRelativePositionUpdateWorldAxis(ThermionEntity entity,
      double viewportX, double viewportY, double x, double y, double z) async {
    queue_relative_position_update_world_axis(
        _sceneManager!, entity, viewportX, viewportY, x, y, z);
  }

  ///
  ///
  ///
  @override
  Future hide(ThermionEntity entity, String? meshName) async {
    final meshNamePtr =
        meshName?.toNativeUtf8(allocator: allocator).cast<Char>() ?? nullptr;
    if (hide_mesh(_sceneManager!, entity, meshNamePtr) != 1) {}
    allocator.free(meshNamePtr);
  }

  ///
  ///
  ///
  @override
  Future reveal(ThermionEntity entity, String? meshName) async {
    final meshNamePtr =
        meshName?.toNativeUtf8(allocator: allocator).cast<Char>() ?? nullptr;
    final result = reveal_mesh(_sceneManager!, entity, meshNamePtr) == 1;
    allocator.free(meshNamePtr);
    if (!result) {
      throw Exception("Failed to reveal mesh $meshName");
    }
  }

  ///
  ///
  ///
  @override
  String? getNameForEntity(ThermionEntity entity) {
    final result = get_name_for_entity(_sceneManager!, entity);
    if (result == nullptr) {
      return null;
    }
    return result.cast<Utf8>().toDartString();
  }

  void _onPickResult(ThermionEntity entityId, int x, int y) {
    _pickResultController.add((
      entity: entityId,
      x: (x / pixelRatio).toDouble(),
      y: (viewportDimensions.$2 - y) / pixelRatio
    ));
    _scene!.registerSelected(entityId);
  }

  void _onGizmoPickResult(ThermionEntity entityId, int x, int y) {
    _gizmoPickResultController.add((
      entity: entityId,
      x: (x / pixelRatio).toDouble(),
      y: (viewportDimensions.$2 - y) / pixelRatio
    ));
  }

  late NativeCallable<Void Function(EntityId entityId, Int x, Int y)>
      _onPickResultCallable;
  late NativeCallable<Void Function(EntityId entityId, Int x, Int y)>
      _onGizmoPickResultCallable;

  ///
  ///
  ///
  @override
  void pick(int x, int y) async {
    _scene!.unregisterSelected();

    x = (x * pixelRatio).ceil();
    y = (viewportDimensions.$2 - (y * pixelRatio)).ceil();

    filament_pick(_viewer!, x, y, _onPickResultCallable.nativeFunction);
  }

  ///
  ///
  ///
  @override
  void pickGizmo(int x, int y) async {
    x = (x * pixelRatio).ceil();
    y = (viewportDimensions.$2 - (y * pixelRatio)).ceil();
    pick_gizmo(_sceneManager!, x, y, _onGizmoPickResultCallable.nativeFunction);
  }

  ///
  ///
  ///
  @override
  Future<Matrix4> getCameraViewMatrix() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }
    var mainCamera = get_camera(_viewer!, await getMainCamera());
    var matrixStruct = get_camera_view_matrix(mainCamera);
    return double4x4ToMatrix4(matrixStruct);
  }

  ///
  ///
  ///
  @override
  Future<Matrix4> getCameraModelMatrix() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }
    var mainCamera = get_camera(_viewer!, await getMainCamera());
    var matrixStruct = get_camera_model_matrix(mainCamera);
    return double4x4ToMatrix4(matrixStruct);
  }

  ///
  ///
  ///
  @override
  Future<Matrix4> getCameraProjectionMatrix() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }
    var mainCamera = get_camera(_viewer!, await getMainCamera());
    var matrixStruct = get_camera_projection_matrix(mainCamera);
    return double4x4ToMatrix4(matrixStruct);
  }

  ///
  ///
  ///
  @override
  Future<Matrix4> getCameraCullingProjectionMatrix() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }
    var mainCamera = get_camera(_viewer!, await getMainCamera());
    var matrixStruct = get_camera_culling_projection_matrix(mainCamera);
    return double4x4ToMatrix4(matrixStruct);
  }

  ///
  ///
  ///
  @override
  Future<Vector3> getCameraPosition() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }
    var modelMatrix = await getCameraModelMatrix();
    return modelMatrix.getColumn(3).xyz;
  }

  ///
  ///
  ///
  @override
  Future<Matrix3> getCameraRotation() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }
    var modelMatrix = await getCameraModelMatrix();
    var rotationMatrix = Matrix3.identity();
    modelMatrix.copyRotation(rotationMatrix);
    return rotationMatrix;
  }

  ManipulatorMode _cameraMode = ManipulatorMode.ORBIT;

  ///
  ///
  ///
  @override
  Future setCameraManipulatorOptions(
      {ManipulatorMode? mode,
      double orbitSpeedX = 0.01,
      double orbitSpeedY = 0.01,
      double zoomSpeed = 0.01}) async {
    if (mode != null) {
      _cameraMode = mode;
    }
    if (_cameraMode != ManipulatorMode.ORBIT) {
      throw Exception("Manipulator mode $mode not yet implemented");
    }
    set_camera_manipulator_options(
        _viewer!, _cameraMode.index, orbitSpeedX, orbitSpeedX, zoomSpeed);
  }

  ///
  ///
  ///
  @override
  Future<Frustum> getCameraFrustum() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }
    var mainCamera = get_camera(_viewer!, await getMainCamera());
    var arrayPtr = get_camera_frustum(mainCamera);
    var doubleList = arrayPtr.asTypedList(24);

    var frustum = Frustum();
    frustum.plane0.setFromComponents(
        doubleList[0], doubleList[1], doubleList[2], doubleList[3]);
    frustum.plane1.setFromComponents(
        doubleList[4], doubleList[5], doubleList[6], doubleList[7]);
    frustum.plane2.setFromComponents(
        doubleList[8], doubleList[9], doubleList[10], doubleList[11]);
    frustum.plane3.setFromComponents(
        doubleList[12], doubleList[13], doubleList[14], doubleList[15]);
    frustum.plane4.setFromComponents(
        doubleList[16], doubleList[17], doubleList[18], doubleList[19]);
    frustum.plane5.setFromComponents(
        doubleList[20], doubleList[21], doubleList[22], doubleList[23]);
    thermion_flutter_free(arrayPtr.cast<Void>());
    return frustum;
  }

  ///
  ///
  ///
  @override
  Future<ThermionEntity> getChildEntity(
      ThermionEntity parent, String childName) async {
    var childNamePtr =
        childName.toNativeUtf8(allocator: allocator).cast<Char>();

    var childEntity =
        find_child_entity_by_name(_sceneManager!, parent, childNamePtr);
    allocator.free(childNamePtr);
    if (childEntity == _FILAMENT_ASSET_ERROR) {
      throw Exception(
          "Could not find child ${childName} under the specified entity");
    }
    return childEntity;
  }

  Future<List<ThermionEntity>> getChildEntities(
      ThermionEntity parent, bool renderableOnly) async {
    var count = get_entity_count(_sceneManager!, parent, renderableOnly);
    var out = allocator<EntityId>(count);
    get_entities(_sceneManager!, parent, renderableOnly, out);
    var outList =
        List.generate(count, (index) => out[index]).cast<ThermionEntity>();
    allocator.free(out);
    return outList;
  }

  ///
  ///
  ///
  @override
  Future<List<String>> getChildEntityNames(ThermionEntity entity,
      {bool renderableOnly = false}) async {
    var count = get_entity_count(_sceneManager!, entity, renderableOnly);
    var names = <String>[];
    for (int i = 0; i < count; i++) {
      var name = get_entity_name_at(_sceneManager!, entity, i, renderableOnly);
      if (name == nullptr) {
        throw Exception("Failed to find mesh at index $i");
      }
      names.add(name.cast<Utf8>().toDartString());
    }
    return names;
  }

  ///
  ///
  ///
  @override
  Future setRecording(bool recording) async {
    set_recording(_viewer!, recording);
  }

  ///
  ///
  ///
  @override
  Future setRecordingOutputDirectory(String outputDir) async {
    var pathPtr = outputDir.toNativeUtf8(allocator: allocator);
    set_recording_output_directory(_viewer!, pathPtr.cast<Char>());
    allocator.free(pathPtr);
  }

  final _collisions = <ThermionEntity, NativeCallable>{};

  ///
  ///
  ///
  @override
  Future addCollisionComponent(ThermionEntity entity,
      {void Function(int entityId1, int entityId2)? callback,
      bool affectsTransform = false}) async {
    if (_sceneManager == null) {
      throw Exception("SceneManager must be non-null");
    }
    // ignore: sdk_version_since

    if (callback != null) {
      var ptr = NativeCallable<
          Void Function(
              EntityId entityId1, EntityId entityId2)>.listener(callback);
      add_collision_component(
          _sceneManager!, entity, ptr.nativeFunction, affectsTransform);
      _collisions[entity] = ptr;
    } else {
      add_collision_component(
          _sceneManager!, entity, nullptr, affectsTransform);
    }
  }

  ///
  ///
  ///
  @override
  Future removeCollisionComponent(ThermionEntity entity) async {
    remove_collision_component(_sceneManager!, entity);
  }

  ///
  ///
  ///
  @override
  Future addAnimationComponent(ThermionEntity entity) async {
    if (!add_animation_component(_sceneManager!, entity)) {
      throw Exception("Failed to add animation component");
    }
  }

  ///
  ///
  ///
  Future removeAnimationComponent(ThermionEntity entity) async {
    remove_animation_component(_sceneManager!, entity);
  }

  ///
  ///
  ///
  @override
  Future<ThermionEntity> createGeometry(
      List<double> vertices, List<int> indices,
      {String? materialPath,
      List<double>? normals,
      bool keepData = false,
      PrimitiveType primitiveType = PrimitiveType.TRIANGLES}) async {
    if (_viewer == null) {
      throw Exception("Viewer must not be null");
    }

    final materialPathPtr =
        materialPath?.toNativeUtf8(allocator: allocator) ?? nullptr;
    final vertexPtr = allocator<Float>(vertices.length);
    final indicesPtr = allocator<Uint16>(indices.length);
    for (int i = 0; i < vertices.length; i++) {
      vertexPtr[i] = vertices[i];
    }

    for (int i = 0; i < indices.length; i++) {
      (indicesPtr + i).value = indices[i];
    }

    var normalsPtr = nullptr.cast<Float>();
    if (normals != null) {
      normalsPtr = allocator<Float>(normals.length);
      for (int i = 0; i < normals.length; i++) {
        normalsPtr[i] = normals[i];
      }
    }

    print("ALLOCATION DONE");

    var entity = await withIntCallback((callback) =>
        create_geometry_with_normals_ffi(
            _sceneManager!,
            vertexPtr,
            vertices.length,
            normalsPtr,
            normals?.length ?? 0,
            indicesPtr,
            indices.length,
            primitiveType.index,
            materialPathPtr.cast<Char>(),
            keepData,
            callback));
    if (entity == _FILAMENT_ASSET_ERROR) {
      throw Exception("Failed to create geometry");
    }

    _scene!.registerEntity(entity);

    allocator.free(materialPathPtr);
    allocator.free(vertexPtr);
    allocator.free(indicesPtr);

    if (normals != null) {
      allocator.free(normalsPtr);
    }

    return entity;
  }

  ///
  ///
  ///
  @override
  Future setParent(ThermionEntity child, ThermionEntity parent,
      {bool preserveScaling = false}) async {
    if (_sceneManager == null) {
      throw Exception("Asset manager must be non-null");
    }
    set_parent(_sceneManager!, child, parent, preserveScaling);
  }

  ///
  ///
  ///
  @override
  Future<ThermionEntity?> getParent(ThermionEntity child) async {
    if (_sceneManager == null) {
      throw Exception("Asset manager must be non-null");
    }
    var parent = get_parent(_sceneManager!, child);
    if (parent == _FILAMENT_ASSET_ERROR) {
      return null;
    }
    return parent;
  }

  ///
  ///
  ///
  @override
  Future<ThermionEntity?> getAncestor(ThermionEntity child) async {
    if (_sceneManager == null) {
      throw Exception("Asset manager must be non-null");
    }
    var parent = get_ancestor(_sceneManager!, child);
    if (parent == _FILAMENT_ASSET_ERROR) {
      return null;
    }
    return parent;
  }

  ///
  ///
  ///
  @override
  Future testCollisions(ThermionEntity entity) async {
    test_collisions(_sceneManager!, entity);
  }

  ///
  ///
  ///
  @override
  Future setPriority(ThermionEntity entityId, int priority) async {
    set_priority(_sceneManager!, entityId, priority);
  }

  ///
  ///
  ///
  @override
  Future<v64.Aabb2> getViewportBoundingBox(ThermionEntity entityId) async {
    final result = get_bounding_box(_sceneManager!, entityId);
    return v64.Aabb2.minMax(v64.Vector2(result.minX, result.minY),
        v64.Vector2(result.maxX, result.maxY));
  }

  ///
  ///
  ///
  Future setLayerEnabled(int layer, bool enabled) async {
    set_layer_enabled(_sceneManager!, layer, enabled);
  }

  ///
  ///
  ///
  Future setGizmoVisibility(bool visible) async {
    set_gizmo_visibility(_sceneManager!, visible);
  }

  ///
  ///
  ///
  Future setStencilHighlight(ThermionEntity entity,
      {double r = 1.0, double g = 0.0, double b = 0.0}) async {
    set_stencil_highlight(_sceneManager!, entity, r, g, b);
  }

  ///
  ///
  ///
  Future removeStencilHighlight(ThermionEntity entity) async {
    remove_stencil_highlight(_sceneManager!, entity);
  }


}

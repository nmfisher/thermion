import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:dart_filament/dart_filament/compatibility/native/compatibility.dart';
import 'package:dart_filament/dart_filament/entities/filament_entity.dart';
import 'package:dart_filament/dart_filament/entities/gizmo.dart';

import 'package:vector_math/vector_math_64.dart';
import 'abstract_filament_viewer.dart';
import 'scene.dart';
import 'compatibility/compatibility.dart';

// ignore: constant_identifier_names
const FilamentEntity _FILAMENT_ASSET_ERROR = 0;

typedef RenderCallback = Pointer<NativeFunction<Void Function(Pointer<Void>)>>;

class FilamentViewer extends AbstractFilamentViewer {
  final _compat = Compatibility();

  late SceneImpl _scene;
  Scene get scene => _scene;

  double _pixelRatio = 1.0;

  late (double, double) viewportDimensions;

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

  final Pointer<Void> resourceLoader;

  var _driver = nullptr.cast<Void>();

  late final RenderCallback _renderCallback;
  var _renderCallbackOwner = nullptr.cast<Void>();

  var _sharedContext = nullptr.cast<Void>();

  ///
  /// This controller uses platform channels to bridge Dart with the C/C++ code for the Filament API.
  /// Setting up the context/texture (since this is platform-specific) and the render ticker are platform-specific; all other methods are passed through by the platform channel to the methods specified in FlutterFilamentApi.h.
  ///
  FilamentViewer(
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
    try {
      _onPickResultCallable =
          NativeCallable<Void Function(Int32 entityId, Int x, Int y)>.listener(
              _onPickResult);
    } catch (err) {
      print(
          "Failed to set pick result callback. This is expected if running on web/wasm");
    }
    _initialize();
  }

  Future createRenderTarget(
      double width, double height, int textureHandle) async {
    await withVoidCallback((callback) => create_render_target_ffi(
        _viewer!, textureHandle, width.toInt(), height.toInt(), callback));
  }

  Future updateViewportAndCameraProjection(double width, double height) async {
    await withVoidCallback((callback) {
      update_viewport_and_camera_projection_ffi(
          _viewer!, width.toInt(), height.toInt(), 1.0, callback);
    });
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

    await setCameraManipulatorOptions(zoomSpeed: 10.0);

    final out = allocator<Int32>(3);
    get_gizmo(_sceneManager!, out);
    _gizmo = Gizmo(out[0], out[1], out[2], this);
    allocator.free(out);

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
  Future setFrameRate(int framerate) async {
    final interval = 1000.0 / framerate;
    set_frame_interval_ffi(_viewer!, interval);
  }

  ///
  ///
  ///
  @override
  Future dispose() async {
    destroy_filament_viewer_ffi(_viewer!);
    _sceneManager = null;
    _viewer = null;
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
  Future<FilamentEntity> addLight(
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

    _scene.registerLight(entity);
    return entity;
  }

  ///
  ///
  ///
  @override
  Future removeLight(FilamentEntity entity) async {
    _scene.unregisterLight(entity);
    remove_light_ffi(_viewer!, entity);
  }

  ///
  ///
  ///
  @override
  Future clearLights() async {
    clear_lights_ffi(_viewer!);

    _scene.clearLights();
  }

  ///
  ///
  ///
  @override
  Future<FilamentEntity> createInstance(FilamentEntity entity) async {
    var created = await withIntCallback(
        (callback) => create_instance(_sceneManager!, entity));
    if (created == _FILAMENT_ASSET_ERROR) {
      throw Exception("Failed to create instance");
    }
    return created;
  }

  ///
  ///
  ///
  @override
  Future<int> getInstanceCount(FilamentEntity entity) async {
    return get_instance_count(_sceneManager!, entity);
  }

  ///
  ///
  ///
  @override
  Future<List<FilamentEntity>> getInstances(FilamentEntity entity) async {
    var count = await getInstanceCount(entity);
    var out = allocator<Int32>(count);
    get_instances(_sceneManager!, entity, out);
    var instances = <FilamentEntity>[];
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
  Future<FilamentEntity> loadGlb(String path,
      {bool unlit = false, int numInstances = 1}) async {
    if (unlit) {
      throw Exception("Not yet implemented");
    }
    final pathPtr = path.toNativeUtf8(allocator: allocator).cast<Char>();
    var entity = await withIntCallback((callback) =>
        load_glb_ffi(_sceneManager!, pathPtr, numInstances, callback));
    allocator.free(pathPtr);
    if (entity == _FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading the asset at $path");
    }
    _scene.registerEntity(entity);

    return entity;
  }

  ///
  ///
  ///
  @override
  Future<FilamentEntity> loadGltf(String path, String relativeResourcePath,
      {bool force = false}) async {
    // if (Platform.isWindows && !force) {
    //   throw Exception(
    //       "loadGltf has a race condition on Windows which is likely to crash your program. If you really want to try, pass force=true to loadGltf");
    // }

    final pathPtr = path.toNativeUtf8(allocator: allocator).cast<Char>();
    final relativeResourcePathPtr =
        relativeResourcePath.toNativeUtf8(allocator: allocator).cast<Char>();
    var entity = await withIntCallback((callback) => load_gltf_ffi(
        _sceneManager!, pathPtr, relativeResourcePathPtr, callback));
    allocator.free(pathPtr);
    allocator.free(relativeResourcePathPtr);
    if (entity == _FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading the asset at $path");
    }
    _scene.registerEntity(entity);

    return entity;
  }

  ///
  ///
  ///
  @override
  Future panStart(double x, double y) async {
    grab_begin(_viewer!, x * _pixelRatio, y * _pixelRatio, true);
  }

  ///
  ///
  ///
  @override
  Future panUpdate(double x, double y) async {
    grab_update(_viewer!, x * _pixelRatio, y * _pixelRatio);
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
    grab_begin(_viewer!, x * _pixelRatio, y * _pixelRatio, false);
  }

  ///
  ///
  ///
  @override
  Future rotateUpdate(double x, double y) async {
    grab_update(_viewer!, x * _pixelRatio, y * _pixelRatio);
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
      FilamentEntity entity, List<double> weights) async {
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
      FilamentEntity entity, FilamentEntity childEntity) async {
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

  Future<List<String>> getBoneNames(FilamentEntity entity,
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
  Future<List<String>> getAnimationNames(FilamentEntity entity) async {
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
      FilamentEntity entity, int animationIndex) async {
    var duration =
        get_animation_duration(_sceneManager!, entity, animationIndex);

    return duration;
  }

  ///
  ///
  ///
  @override
  Future<double> getAnimationDurationByName(
      FilamentEntity entity, String name) async {
    var animations = await getAnimationNames(entity);
    var index = animations.indexOf(name);
    if (index == -1) {
      throw Exception("Failed to find animation $name");
    }
    return getAnimationDuration(entity, index);
  }

  ///
  ///
  ///
  @override
  Future setMorphAnimationData(
      FilamentEntity entity, MorphAnimationData animation,
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
        print("Skipping $meshName, not contained in target");
        continue;
      }

      var meshMorphTargets = await getMorphTargetNames(entity, meshEntity);

      print("Got mesh morph targets ${meshMorphTargets}");

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
  Future addBoneAnimation(FilamentEntity entity, BoneAnimationData animation,
      {int skinIndex = 0}) async {
    if (animation.space != Space.Bone && animation.space != Space.ParentWorldRotation) {
      throw UnimplementedError("TODO - support ${animation.space}");
    }
    if (skinIndex != 0) {
      throw UnimplementedError("TODO - support skinIndex != 0 ");
    }
    var boneNames = await getBoneNames(entity);
    await resetBones(entity);

    var numFrames = animation.frameData.length;

    var data = allocator<Float>(numFrames * 16);

    var bones = await Future.wait(List<Future<FilamentEntity>>.generate(
        boneNames.length, (i) => getBone(entity, i)));

    for (int i = 0; i < animation.bones.length; i++) {
      var boneName = animation.bones[i];
      var entityBoneIndex = boneNames.indexOf(boneName);
      if (entityBoneIndex == -1) {
        print("Warning : bone $boneName not found, skipping");
        continue;
      }
      var boneEntity = bones[entityBoneIndex];

      var baseTransform = await getLocalTransform(boneEntity);
      var baseTransformInverse = Matrix4.identity()..copyInverse(baseTransform);

      for (int frameNum = 0; frameNum < numFrames; frameNum++) {
        var rotation = animation.frameData[frameNum][i].rotation;
        var translation = animation.frameData[frameNum][i].translation;
        var frameTransform =
            Matrix4.compose(translation, rotation, Vector3.all(1.0));
        var newLocalTransform = frameTransform.clone();
        if (animation.space == Space.Bone) {
          newLocalTransform = baseTransform * frameTransform;
        } else if (animation.space == Space.ParentWorldRotation) {
          var world = await getWorldTransform(boneEntity);
          world = Matrix4.identity()..setRotation(world.getRotation());
          var worldInverse = Matrix4.identity()..copyInverse(world);
          newLocalTransform =
              baseTransform * (worldInverse * frameTransform * world);
        }
        for (int j = 0; j < 16; j++) {
          data.elementAt((frameNum * 16) + j).value =
              newLocalTransform.storage[j];
        }
      }

      add_bone_animation(_sceneManager!, entity, skinIndex, entityBoneIndex,
          data, numFrames, animation.frameLengthInMs);
    }
    allocator.free(data);
  }

  ///
  ///
  ///
  Future<Matrix4> getLocalTransform(FilamentEntity entity) async {
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
  Future<Matrix4> getWorldTransform(FilamentEntity entity) async {
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
  Future setTransform(FilamentEntity entity, Matrix4 transform) async {
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
  Future updateBoneMatrices(FilamentEntity entity) async {
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
  Future<Matrix4> getInverseBindMatrix(FilamentEntity parent, int boneIndex,
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
  Future<FilamentEntity> getBone(FilamentEntity parent, int boneIndex,
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
      FilamentEntity entity, int boneIndex, Matrix4 transform,
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
  Future resetBones(FilamentEntity entity) async {
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
  Future removeEntity(FilamentEntity entity) async {
    _scene.unregisterEntity(entity);

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
    _scene.clearEntities();
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
  Future playAnimation(FilamentEntity entity, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) async {
    play_animation(
        _sceneManager!, entity, index, loop, reverse, replaceActive, crossfade);
  }

  ///
  ///
  ///
  @override
  Future stopAnimation(FilamentEntity entity, int animationIndex) async {
    stop_animation(_sceneManager!, entity, animationIndex);
  }

  ///
  ///
  ///
  @override
  Future stopAnimationByName(FilamentEntity entity, String name) async {
    var animations = await getAnimationNames(entity);
    await stopAnimation(entity, animations.indexOf(name));
  }

  ///
  ///
  ///
  @override
  Future playAnimationByName(FilamentEntity entity, String name,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      bool wait = false}) async {
    var animations = await getAnimationNames(entity);
    var index = animations.indexOf(name);
    var duration = await getAnimationDuration(entity, index);
    print("Duration for $name : $duration");
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
      FilamentEntity entity, int index, int animationFrame) async {
    set_animation_frame(_sceneManager!, entity, index, animationFrame);
  }

  ///
  ///
  ///
  @override
  Future setMainCamera() async {
    set_main_camera(_viewer!);
  }

  Future<FilamentEntity> getMainCamera() async {
    return get_main_camera(_viewer!);
  }

  ///
  ///
  ///
  @override
  Future setCamera(FilamentEntity entity, String? name) async {
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
    set_camera_focal_length(_viewer!, focalLength);
  }

  ///
  ///
  ///
  @override
  Future setCameraFov(double degrees, double width, double height) async {
    set_camera_fov(_viewer!, degrees, width / height);
  }

  ///
  ///
  ///
  @override
  Future setCameraCulling(double near, double far) async {
    set_camera_culling(_viewer!, near, far);
  }

  ///
  ///
  ///
  @override
  Future<double> getCameraCullingNear() async {
    return get_camera_culling_near(_viewer!);
  }

  ///
  ///
  ///
  @override
  Future<double> getCameraCullingFar() async {
    return get_camera_culling_far(_viewer!);
  }

  ///
  ///
  ///
  @override
  Future setCameraFocusDistance(double focusDistance) async {
    set_camera_focus_distance(_viewer!, focusDistance);
  }

  ///
  ///
  ///
  @override
  Future setCameraPosition(double x, double y, double z) async {
    set_camera_position(_viewer!, x, y, z);
  }

  ///
  ///
  ///
  @override
  Future moveCameraToAsset(FilamentEntity entity) async {
    move_camera_to_asset(_viewer!, entity);
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
    set_camera_exposure(_viewer!, aperture, shutterSpeed, sensitivity);
  }

  ///
  ///
  ///
  @override
  Future setCameraRotation(Quaternion quaternion) async {
    set_camera_rotation(
        _viewer!, quaternion.w, quaternion.x, quaternion.y, quaternion.z);
  }

  ///
  ///
  ///
  @override
  Future setCameraModelMatrix(List<double> matrix) async {
    assert(matrix.length == 16);
    var ptr = allocator<Float>(16);
    for (int i = 0; i < 16; i++) {
      ptr.elementAt(i).value = matrix[i];
    }
    set_camera_model_matrix(_viewer!, ptr);
    allocator.free(ptr);
  }

  ///
  ///
  ///
  @override
  Future setMaterialColor(FilamentEntity entity, String meshName,
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
  Future transformToUnitCube(FilamentEntity entity) async {
    transform_to_unit_cube(_sceneManager!, entity);
  }

  ///
  ///
  ///
  @override
  Future setPosition(
      FilamentEntity entity, double x, double y, double z) async {
    set_position(_sceneManager!, entity, x, y, z);
  }

  ///
  ///
  ///
  @override
  Future setRotationQuat(FilamentEntity entity, Quaternion rotation,
      {bool relative = false}) async {
    set_rotation(_sceneManager!, entity, rotation.radians, rotation.x,
        rotation.y, rotation.z, rotation.w);
  }

  ///
  ///
  ///
  @override
  Future setRotation(
      FilamentEntity entity, double rads, double x, double y, double z) async {
    var quat = Quaternion.axisAngle(Vector3(x, y, z), rads);
    await setRotationQuat(entity, quat);
  }

  ///
  ///
  ///
  @override
  Future setScale(FilamentEntity entity, double scale) async {
    set_scale(_sceneManager!, entity, scale);
  }

  Future queueRotationUpdateQuat(FilamentEntity entity, Quaternion rotation,
      {bool relative = false}) async {
    queue_rotation_update(_sceneManager!, entity, rotation.radians, rotation.x,
        rotation.y, rotation.z, rotation.w, relative);
  }

  ///
  ///
  ///
  @override
  Future queueRotationUpdate(
      FilamentEntity entity, double rads, double x, double y, double z,
      {bool relative = false}) async {
    var quat = Quaternion.axisAngle(Vector3(x, y, z), rads);
    await queueRotationUpdateQuat(entity, quat, relative: relative);
  }

  ///
  ///
  ///
  @override
  Future queuePositionUpdate(
      FilamentEntity entity, double x, double y, double z,
      {bool relative = false}) async {
    queue_position_update(_sceneManager!, entity, x, y, z, relative);
  }

  ///
  ///
  ///
  @override
  Future hide(FilamentEntity entity, String? meshName) async {
    final meshNamePtr =
        meshName?.toNativeUtf8(allocator: allocator).cast<Char>() ?? nullptr;
    if (hide_mesh(_sceneManager!, entity, meshNamePtr) != 1) {}
    allocator.free(meshNamePtr);
  }

  ///
  ///
  ///
  @override
  Future reveal(FilamentEntity entity, String? meshName) async {
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
  String? getNameForEntity(FilamentEntity entity) {
    final result = get_name_for_entity(_sceneManager!, entity);
    if (result == nullptr) {
      return null;
    }
    return result.cast<Utf8>().toDartString();
  }

  void _onPickResult(FilamentEntity entityId, int x, int y) {
    _pickResultController.add((
      entity: entityId,
      x: (x / _pixelRatio).toDouble(),
      y: (viewportDimensions.$2 - y) / _pixelRatio
    ));
    _scene.registerSelected(entityId);
  }

  late NativeCallable<Void Function(Int32 entityId, Int x, Int y)>
      _onPickResultCallable;

  ///
  ///
  ///
  @override
  void pick(int x, int y) async {
    _scene.unregisterSelected();

    filament_pick(
        _viewer!,
        (x * _pixelRatio).toInt(),
        (viewportDimensions.$2 - (y * _pixelRatio)).toInt(),
        _onPickResultCallable.nativeFunction);
  }

  ///
  ///
  ///
  @override
  Future<Matrix4> getCameraViewMatrix() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }
    var arrayPtr = get_camera_view_matrix(_viewer!);
    var viewMatrix = Matrix4.fromList(arrayPtr.asTypedList(16));
    allocator.free(arrayPtr);
    return viewMatrix;
  }

  ///
  ///
  ///
  @override
  Future<Matrix4> getCameraModelMatrix() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }
    var arrayPtr = get_camera_model_matrix(_viewer!);
    var modelMatrix = Matrix4.fromList(arrayPtr.asTypedList(16));
    allocator.free(arrayPtr);
    return modelMatrix;
  }

  ///
  ///
  ///
  @override
  Future<Vector3> getCameraPosition() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }
    var arrayPtr = get_camera_model_matrix(_viewer!);
    var doubleList = arrayPtr.asTypedList(16);
    var modelMatrix = Matrix4.fromFloat64List(doubleList);

    var position = modelMatrix.getColumn(3).xyz;

    flutter_filament_free(arrayPtr.cast<Void>());
    return position;
  }

  ///
  ///
  ///
  @override
  Future<Matrix3> getCameraRotation() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }
    var arrayPtr = get_camera_model_matrix(_viewer!);
    var doubleList = arrayPtr.asTypedList(16);
    var modelMatrix = Matrix4.fromFloat64List(doubleList);
    var rotationMatrix = Matrix3.identity();
    modelMatrix.copyRotation(rotationMatrix);
    flutter_filament_free(arrayPtr.cast<Void>());
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
  /// I don't think these two methods are accurate - don't rely on them, use the Frustum values instead.
  /// I think because we use [setLensProjection] and [setScaling] together, this projection matrix doesn't accurately reflect the field of view (because it's using an additional scaling matrix).
  /// Also, the near/far planes never seem to get updated (which is what I would expect to see when calling [getCameraCullingProjectionMatrix])
  ///
  ///
  ///
  ///
  @override
  Future<Matrix4> getCameraProjectionMatrix() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }

    print(
        "WARNING: getCameraProjectionMatrix and getCameraCullingProjectionMatrix are not reliable. Consider these broken");

    var arrayPtr = get_camera_projection_matrix(_viewer!);
    var doubleList = arrayPtr.asTypedList(16);
    var projectionMatrix = Matrix4.fromList(doubleList);
    flutter_filament_free(arrayPtr.cast<Void>());
    return projectionMatrix;
  }

  ///
  ///
  ///
  @override
  Future<Matrix4> getCameraCullingProjectionMatrix() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }
    print(
        "WARNING: getCameraProjectionMatrix and getCameraCullingProjectionMatrix are not reliable. Consider these broken");
    var arrayPtr = get_camera_culling_projection_matrix(_viewer!);
    var doubleList = arrayPtr.asTypedList(16);
    var projectionMatrix = Matrix4.fromList(doubleList);
    flutter_filament_free(arrayPtr.cast<Void>());
    return projectionMatrix;
  }

  ///
  ///
  ///
  @override
  Future<Frustum> getCameraFrustum() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }
    var arrayPtr = get_camera_frustum(_viewer!);
    var doubleList = arrayPtr.asTypedList(24);
    print(doubleList);

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
    flutter_filament_free(arrayPtr.cast<Void>());
    return frustum;
  }

  ///
  ///
  ///
  @override
  Future<FilamentEntity> getChildEntity(
      FilamentEntity parent, String childName) async {
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

  Future<List<FilamentEntity>> getChildEntities(
      FilamentEntity parent, bool renderableOnly) async {
    var count = get_entity_count(_sceneManager!, parent, renderableOnly);
    var out = allocator<Int32>(count);
    get_entities(_sceneManager!, parent, renderableOnly, out);
    var outList =
        List.generate(count, (index) => out[index]).cast<FilamentEntity>();
    allocator.free(out);
    return outList;
  }

  ///
  ///
  ///
  @override
  Future<List<String>> getChildEntityNames(FilamentEntity entity,
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

  final _collisions = <FilamentEntity, NativeCallable>{};

  ///
  ///
  ///
  @override
  Future addCollisionComponent(FilamentEntity entity,
      {void Function(int entityId1, int entityId2)? callback,
      bool affectsTransform = false}) async {
    if (_sceneManager == null) {
      throw Exception("SceneManager must be non-null");
    }
    // ignore: sdk_version_since

    if (callback != null) {
      var ptr = NativeCallable<
          Void Function(Int32 entityId1, Int32 entityId2)>.listener(callback);
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
  Future removeCollisionComponent(FilamentEntity entity) async {
    remove_collision_component(_sceneManager!, entity);
  }

  ///
  ///
  ///
  @override
  Future addAnimationComponent(FilamentEntity entity) async {
    if (!add_animation_component(_sceneManager!, entity)) {
      throw Exception("Failed to add animation component");
    }
  }

  ///
  ///
  ///
  Future removeAnimationComponent(FilamentEntity entity) async {
    remove_animation_component(_sceneManager!, entity);
  }

  ///
  ///
  ///
  @override
  Future<FilamentEntity> createGeometry(
      List<double> vertices, List<int> indices,
      {String? materialPath,
      PrimitiveType primitiveType = PrimitiveType.TRIANGLES}) async {
    if (_viewer == null) {
      throw Exception("Viewer must not be null");
    }

    final materialPathPtr =
        materialPath?.toNativeUtf8(allocator: allocator) ?? nullptr;
    final vertexPtr = allocator<Float>(vertices.length);
    final indicesPtr = allocator<Uint16>(indices.length);
    for (int i = 0; i < vertices.length; i++) {
      vertexPtr.elementAt(i).value = vertices[i];
    }

    for (int i = 0; i < indices.length; i++) {
      indicesPtr.elementAt(i).value = indices[i];
    }

    var entity = await withIntCallback((callback) => create_geometry_ffi(
        _viewer!,
        vertexPtr,
        vertices.length,
        indicesPtr,
        indices.length,
        primitiveType.index,
        materialPathPtr.cast<Char>(),
        callback));
    if (entity == _FILAMENT_ASSET_ERROR) {
      throw Exception("Failed to create geometry");
    }

    _scene.registerEntity(entity);

    allocator.free(materialPathPtr);
    allocator.free(vertexPtr);
    allocator.free(indicesPtr);

    return entity;
  }

  ///
  ///
  ///
  @override
  Future setParent(FilamentEntity child, FilamentEntity parent) async {
    if (_sceneManager == null) {
      throw Exception("Asset manager must be non-null");
    }
    set_parent(_sceneManager!, child, parent);
  }

  ///
  ///
  ///
  @override
  Future<FilamentEntity?> getParent(FilamentEntity child) async {
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
  Future testCollisions(FilamentEntity entity) async {
    test_collisions(_sceneManager!, entity);
  }

  ///
  ///
  ///
  @override
  Future setPriority(FilamentEntity entityId, int priority) async {
    set_priority(_sceneManager!, entityId, priority);
  }
}

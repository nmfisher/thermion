import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_gizmo.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
import '../../../../utils/src/gizmo.dart';
import '../../../../utils/src/matrix.dart';
import '../../events.dart';
import '../../thermion_viewer_base.dart';
import 'package:logging/logging.dart';

import 'callbacks.dart';
import 'ffi_camera.dart';
import 'ffi_view.dart';

// ignore: constant_identifier_names
const ThermionEntity _FILAMENT_ASSET_ERROR = 0;

typedef RenderCallback = Pointer<NativeFunction<Void Function(Pointer<Void>)>>;

class ThermionViewerFFI extends ThermionViewer {
  final _logger = Logger("ThermionViewerFFI");

  Pointer<TSceneManager>? _sceneManager;

  Pointer<TViewer>? _viewer;

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

  ///
  ///
  ///
  @override
  Stream<FilamentPickResult> get gizmoPickResult =>
      _gizmoPickResultController.stream;
  final _gizmoPickResultController =
      StreamController<FilamentPickResult>.broadcast();

  ///
  ///
  ///
  Stream<SceneUpdateEvent> get sceneUpdated =>
      _sceneUpdateEventController.stream;
  final _sceneUpdateEventController =
      StreamController<SceneUpdateEvent>.broadcast();

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

    _onPickResultCallable = NativeCallable<
        Void Function(
            EntityId entityId,
            Int x,
            Int y,
            Pointer<TView> view,
            Float depth,
            Float fragX,
            Float fragY,
            Float fragZ)>.listener(_onPickResult);

    _initialize();
  }

  ///
  ///
  ///
  Future<RenderTarget> createRenderTarget(
      int width, int height, int textureHandle) async {
    final renderTarget =
        Viewer_createRenderTarget(_viewer!, textureHandle, width, height);
    return FFIRenderTarget(renderTarget, _viewer!);
  }

  ///
  ///
  ///
  @override
  Future destroyRenderTarget(FFIRenderTarget renderTarget) async {
    if (_disposing || _viewer == null) {
      _logger.info(
          "Viewer is being (or has been) disposed; this will clean up all render targets.");
    } else {
      Viewer_destroyRenderTarget(_viewer!, renderTarget.renderTarget);
    }
  }

  ///
  ///
  ///
  Future setRenderTarget(FFIRenderTarget? renderTarget) async {
    final view = (await getViewAt(0)) as FFIView;
    if (renderTarget != null) {
      View_setRenderTarget(view.view, renderTarget.renderTarget);
    } else {
      View_setRenderTarget(view.view, nullptr);
    }
  }

  ///
  ///
  ///
  Future<View> createView() async {
    var view = Viewer_createView(_viewer!);
    if (view == nullptr) {
      throw Exception("Failed to create view");
    }
    return FFIView(view, _viewer!);
  }

  ///
  ///
  ///
  Future updateViewportAndCameraProjection(double width, double height) async {
    var mainView = FFIView(Viewer_getViewAt(_viewer!, 0), _viewer!);
    mainView.updateViewport(width.toInt(), height.toInt());

    final cameraCount = await getCameraCount();

    for (int i = 0; i < cameraCount; i++) {
      var camera = await getCameraAt(i);
      var near = await camera.getNear();
      if (near.abs() < 0.000001) {
        near = kNear;
      }
      var far = await camera.getCullingFar();
      if (far.abs() < 0.000001) {
        far = kFar;
      }

      var aspect = width / height;
      var focalLength = await camera.getFocalLength();
      if (focalLength.abs() < 0.1) {
        focalLength = kFocalLength;
      }
      camera.setLensProjection(
          near: near, far: far, aspect: aspect, focalLength: focalLength);
    }
  }

  ///
  ///
  ///
  Future<SwapChain> createHeadlessSwapChain(int width, int height) async {
    var swapChain = await withPointerCallback<TSwapChain>((callback) {
      return Viewer_createHeadlessSwapChainRenderThread(
          _viewer!, width, height, callback);
    });
    return FFISwapChain(swapChain, _viewer!);
  }

  ///
  ///
  ///
  Future<SwapChain> createSwapChain(int surface) async {
    var swapChain = await withPointerCallback<TSwapChain>((callback) {
      return Viewer_createSwapChainRenderThread(
          _viewer!, Pointer<Void>.fromAddress(surface), callback);
    });
    return FFISwapChain(swapChain, _viewer!);
  }

  ///
  ///
  ///
  Future destroySwapChain(FFISwapChain swapChain) async {
    if (_viewer != null) {
      await withVoidCallback((callback) {
        Viewer_destroySwapChainRenderThread(
            _viewer!, swapChain.swapChain, callback);
      });
    }
  }

  Gizmo? _gizmo;
  Gizmo? get gizmo => _gizmo;

  Future _initialize() async {
    final uberarchivePtr =
        uberArchivePath?.toNativeUtf8(allocator: allocator).cast<Char>() ??
            nullptr;
    _viewer = await withPointerCallback(
        (Pointer<NativeFunction<Void Function(Pointer<TViewer>)>> callback) {
      Viewer_createOnRenderThread(_sharedContext, _driver, uberarchivePtr,
          resourceLoader, _renderCallback, _renderCallbackOwner, callback);
    });

    allocator.free(uberarchivePtr);
    if (_viewer!.address == 0) {
      throw Exception("Failed to create viewer. Check logs for details");
    }

    _sceneManager = Viewer_getSceneManager(_viewer!);

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
    // await withVoidCallback((cb) {
    //   set_rendering_render_thread(_viewer!, render, cb);
    // });
  }

  ///
  ///
  ///
  @override
  Future render({FFISwapChain? swapChain}) async {
    final view = (await getViewAt(0)) as FFIView;
    swapChain ??= FFISwapChain(Viewer_getSwapChainAt(_viewer!, 0), _viewer!);
    Viewer_renderRenderThread(_viewer!, view.view, swapChain.swapChain);
  }

  ///
  ///
  ///
  @override
  Future<Uint8List> capture(
      {FFIView? view,
      FFISwapChain? swapChain,
      FFIRenderTarget? renderTarget}) async {
    view ??= (await getViewAt(0)) as FFIView;
    final vp = await view.getViewport();
    final length = vp.width * vp.height * 4;
    final out = Uint8List(length);

    swapChain ??= FFISwapChain(Viewer_getSwapChainAt(_viewer!, 0), _viewer!);

    await withVoidCallback((cb) {
      if (renderTarget != null) {
        Viewer_captureRenderTargetRenderThread(_viewer!, view!.view,
            swapChain!.swapChain, renderTarget.renderTarget, out.address, cb);
      } else {
        Viewer_captureRenderThread(
            _viewer!, view!.view, swapChain!.swapChain, out.address, cb);
      }
    });
    return out;
  }

  ///
  ///
  ///
  @override
  Future setFrameRate(int framerate) async {
    final interval = 1000.0 / framerate;
    set_frame_interval_render_thread(_viewer!, interval);
  }

  final _onDispose = <Future Function()>[];
  bool _disposing = false;

  ///
  ///
  ///
  @override
  Future dispose() async {
    if (_viewer == null) {
      _logger.info("Viewer already disposed, ignoring");
      return;
    }
    _disposing = true;

    await setRendering(false);
    await clearEntities();
    await clearLights();
    await _pickResultController.close();
    await _gizmoPickResultController.close();
    await _sceneUpdateEventController.close();
    Viewer_destroyOnRenderThread(_viewer!);
    _sceneManager = null;
    _viewer = null;

    for (final callback in _onDispose) {
      await callback.call();
    }
    _onDispose.clear();
    _disposing = false;
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
    clear_background_image_render_thread(_viewer!);
  }

  ///
  ///
  ///
  @override
  Future setBackgroundImage(String path, {bool fillHeight = false}) async {
    final pathPtr = path.toNativeUtf8(allocator: allocator).cast<Char>();
    await withVoidCallback((cb) {
      set_background_image_render_thread(_viewer!, pathPtr, fillHeight, cb);
    });

    allocator.free(pathPtr);
  }

  ///
  ///
  ///
  @override
  Future setBackgroundColor(double r, double g, double b, double a) async {
    set_background_color_render_thread(_viewer!, r, g, b, a);
  }

  ///
  ///
  ///
  @override
  Future setBackgroundImagePosition(double x, double y,
      {bool clamp = false}) async {
    set_background_image_position_render_thread(_viewer!, x, y, clamp);
  }

  ///
  ///
  ///
  @override
  Future loadSkybox(String skyboxPath) async {
    final pathPtr = skyboxPath.toNativeUtf8(allocator: allocator).cast<Char>();

    await withVoidCallback((cb) {
      load_skybox_render_thread(_viewer!, pathPtr, cb);
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

    await withVoidCallback((cb) {
      Viewer_loadIblRenderThread(_viewer!, pathPtr, intensity, cb);
    });
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
    remove_skybox_render_thread(_viewer!);
  }

  ///
  ///
  ///
  @override
  Future removeIbl() async {
    remove_ibl(_viewer!);
  }

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
    DirectLight directLight = DirectLight(
        type: type,
        color: colour,
        intensity: intensity,
        position: Vector3(posX, posY, posZ),
        direction: Vector3(dirX, dirY, dirZ)..normalize(),
        falloffRadius: falloffRadius,
        spotLightConeInner: spotLightConeInner,
        spotLightConeOuter: spotLightConeOuter,
        sunAngularRadius: sunAngularRadius,
        sunHaloSize: sunHaloSize,
        sunHaloFallof: sunHaloFallof,
        castShadows: castShadows);

    return addDirectLight(directLight);
  }

  ///
  ///
  ///
  @override
  Future<ThermionEntity> addDirectLight(DirectLight directLight) async {
    var entity = add_light(
      _viewer!,
      directLight.type.index,
      directLight.color,
      directLight.intensity,
      directLight.position.x,
      directLight.position.y,
      directLight.position.z,
      directLight.direction.x,
      directLight.direction.y,
      directLight.direction.z,
      directLight.falloffRadius,
      directLight.spotLightConeInner,
      directLight.spotLightConeOuter,
      directLight.sunAngularRadius,
      directLight.sunHaloSize,
      directLight.sunHaloFallof,
      directLight.castShadows,
    );
    if (entity == _FILAMENT_ASSET_ERROR) {
      throw Exception("Failed to add light to scene");
    }
    _sceneUpdateEventController
        .add(SceneUpdateEvent.addDirectLight(entity, directLight));
    return entity;
  }

  ///
  ///
  ///
  @override
  Future removeLight(ThermionEntity entity) async {
    remove_light(_viewer!, entity);
    _sceneUpdateEventController.add(SceneUpdateEvent.remove(entity));
  }

  ///
  ///
  ///
  @override
  Future clearLights() async {
    clear_lights(_viewer!);
    _sceneUpdateEventController.add(SceneUpdateEvent.clearLights());
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
    var entity = await withIntCallback((callback) => load_glb_render_thread(
        _sceneManager!, pathPtr, numInstances, keepData, callback));

    allocator.free(pathPtr);
    if (entity == _FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading the asset at $path");
    }

    _sceneUpdateEventController
        .add(SceneUpdateEvent.addGltf(entity, GLTF(path, numInstances)));

    return entity;
  }

  ///
  ///
  ///
  @override
  Future<ThermionEntity> loadGlbFromBuffer(Uint8List data,
      {bool unlit = false,
      int numInstances = 1,
      bool keepData = false,
      int priority = 4,
      int layer = 0,
      bool loadResourcesAsync = false}) async {
    if (unlit) {
      throw Exception("Not yet implemented");
    }

    if (layer < 0 || layer > 6) {
      throw Exception("Layer must be between 0 and 6");
    }

    var entity = await withIntCallback((callback) =>
        SceneManager_loadGlbFromBufferRenderThread(
            _sceneManager!,
            data.address,
            data.length,
            numInstances,
            keepData,
            priority,
            layer,
            loadResourcesAsync,
            callback));

    if (entity == _FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading GLB from buffer");
    }
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
    var entity = await withIntCallback((callback) => load_gltf_render_thread(
        _sceneManager!, pathPtr, relativeResourcePathPtr, keepData, callback));
    allocator.free(pathPtr);
    allocator.free(relativeResourcePathPtr);
    if (entity == _FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading the asset at $path");
    }

    return entity;
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
      set_morph_target_weights_render_thread(
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
        get_morph_target_name_count_render_thread(
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
        // _logger.info("Skipping $meshName, not contained in target");
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

      var indices = Uint32List.fromList(
          intersection.map((m) => meshMorphTargets.indexOf(m)).toList());

      // var frameData = animation.data;
      var frameData = animation.subset(intersection);

      assert(
          frameData.data.length == animation.numFrames * intersection.length);

      var result = SceneManager_setMorphAnimation(
          _sceneManager!,
          meshEntity,
          frameData.data.address,
          indices.address,
          indices.length,
          animation.numFrames,
          animation.frameLengthInMs);

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
    SceneManager_setTransform(
        _sceneManager!, entity, transform.storage.address);
  }

  ///
  ///
  ///
  Future queueTransformUpdates(
      List<ThermionEntity> entities, List<Matrix4> transforms) async {
    var tEntities = Int32List.fromList(entities);
    var tTransforms =
        Float64List.fromList(transforms.expand((t) => t.storage).toList());

    SceneManager_queueTransformUpdates(_sceneManager!, tEntities.address,
        tTransforms.address, tEntities.length);
  }

  ///
  ///
  ///
  Future updateBoneMatrices(ThermionEntity entity) async {
    var result = await withBoolCallback((cb) {
      update_bone_matrices_render_thread(_sceneManager!, entity, cb);
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
      set_bone_transform_render_thread(
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
      reset_to_rest_pose_render_thread(_sceneManager!, entity, cb);
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
    await withVoidCallback(
        (callback) => remove_entity_render_thread(_viewer!, entity, callback));
    _sceneUpdateEventController.add(SceneUpdateEvent.remove(entity));
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
      clear_entities_render_thread(_viewer!, callback);
    });
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
    final view = (await getViewAt(0)) as FFIView;
    Viewer_setMainCamera(_viewer!, view.view);
  }

  ///
  ///
  ///
  Future<ThermionEntity> getMainCameraEntity() async {
    return get_main_camera(_viewer!);
  }

  ///
  ///
  ///
  Future<Camera> getMainCamera() async {
    var camera = await getCameraComponent(await getMainCameraEntity());
    return camera!;
  }

  Future<Camera?> getCameraComponent(ThermionEntity cameraEntity) async {
    var engine = Viewer_getEngine(_viewer!);
    var camera = Engine_getCameraComponent(engine, cameraEntity);
    return FFICamera(camera, engine);
  }

  ///
  ///
  ///
  @override
  Future setCamera(ThermionEntity entity, String? name) async {
    var cameraNamePtr =
        name?.toNativeUtf8(allocator: allocator).cast<Char>() ?? nullptr;
    final camera =
        SceneManager_findCameraByName(_sceneManager!, entity, cameraNamePtr);
    if (camera == nullptr) {
      throw Exception("Failed to set camera");
    }
    final view = (await getViewAt(0)) as FFIView;
    View_setCamera(view.view, camera);
    allocator.free(cameraNamePtr);
  }

  ///
  ///
  ///
  @override
  Future setToneMapping(ToneMapper mapper) async {
    final view = await getViewAt(0);
    view.setToneMapper(mapper);
  }

  ///
  ///
  ///
  @override
  Future setPostProcessing(bool enabled) async {
    final view = await getViewAt(0) as FFIView;
    View_setPostProcessing(view.view, enabled);
  }

  ///
  ///
  ///
  @override
  Future setShadowsEnabled(bool enabled) async {
    final view = await getViewAt(0) as FFIView;
    View_setShadowsEnabled(view.view, enabled);
  }

  ///
  ///
  ///
  Future setShadowType(ShadowType shadowType) async {
    final view = await getViewAt(0) as FFIView;
    View_setShadowType(view.view, shadowType.index);
  }

  ///
  ///
  ///
  Future setSoftShadowOptions(
      double penumbraScale, double penumbraRatioScale) async {
    final view = await getViewAt(0) as FFIView;
    View_setSoftShadowOptions(view.view, penumbraScale, penumbraRatioScale);
  }

  ///
  ///
  ///
  @override
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa) async {
    final view = await getViewAt(0) as FFIView;
    View_setAntiAliasing(view.view, msaa, fxaa, taa);
  }

  ///
  ///
  ///
  @override
  Future setBloom(double bloom) async {
    final view = await getViewAt(0) as FFIView;
    View_setBloom(view.view, bloom);
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
    var mainCamera = await getMainCamera() as FFICamera;
    return get_camera_fov(mainCamera.camera, horizontal);
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
    var mainCamera = await getMainCamera() as FFICamera;
    return get_camera_near(mainCamera.camera);
  }

  ///
  ///
  ///
  @override
  Future<double> getCameraCullingFar() async {
    var mainCamera = await getMainCamera() as FFICamera;
    return get_camera_culling_far(mainCamera.camera);
  }

  ///
  ///
  ///
  @override
  Future setCameraFocusDistance(double focusDistance) async {
    var mainCamera = await getMainCamera() as FFICamera;
    set_camera_focus_distance(mainCamera.camera, focusDistance);
  }

  ///
  ///
  ///
  @override
  Future setCameraPosition(double x, double y, double z) async {
    var modelMatrix = await getCameraModelMatrix();
    modelMatrix.setTranslation(Vector3(x, y, z));
    return setCameraModelMatrix4(modelMatrix);
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
    var view = await getViewAt(0);
    view.setFrustumCullingEnabled(enabled);
  }

  ///
  ///
  ///
  @override
  Future setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity) async {
    var mainCamera = await getMainCamera() as FFICamera;
    set_camera_exposure(mainCamera.camera, aperture, shutterSpeed, sensitivity);
  }

  ///
  ///
  ///
  @override
  Future setCameraRotation(Quaternion quaternion) async {
    var modelMatrix = await getCameraModelMatrix();
    var translation = modelMatrix.getTranslation();
    modelMatrix = Matrix4.compose(translation, quaternion, Vector3.all(1.0));
    await setCameraModelMatrix4(modelMatrix);
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
    var mainCamera = await getMainCamera() as FFICamera;
    final out = matrix4ToDouble4x4(modelMatrix);
    set_camera_model_matrix(mainCamera.camera, out);
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
  /// Queues an update to the worldspace position for [entity] to the viewport coordinates {x,y}.
  /// The actual update will occur on the next frame, and will be subject to collision detection.
  ///
  Future queuePositionUpdateFromViewportCoords(
      ThermionEntity entity, double x, double y) async {
    final view = (await getViewAt(0)) as FFIView;
    queue_position_update_from_viewport_coords(
        _sceneManager!, view.view, entity, x, y);
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

  void _onPickResult(
      ThermionEntity entityId,
      int x,
      int y,
      Pointer<TView> viewPtr,
      double depth,
      double fragX,
      double fragY,
      double fragZ) async {
    final view = FFIView(viewPtr, _viewer!);
    final viewport = await view.getViewport();

    _pickResultController.add((
      entity: entityId,
      x: x,
      y: (viewport.height - y),
      depth: depth,
      fragX: fragX,
      fragY: viewport.height - fragY,
      fragZ: fragZ
    ));
  }

  late NativeCallable<
      Void Function(
          EntityId entityId,
          Int x,
          Int y,
          Pointer<TView> view,
          Float depth,
          Float fragX,
          Float fragY,
          Float fragZ)> _onPickResultCallable;

  ///
  ///
  ///
  @override
  Future pick(int x, int y) async {
    final view = (await getViewAt(0)) as FFIView;
    var viewport = await view.getViewport();
    y = viewport.height - y;
    Viewer_pick(
        _viewer!, view.view, x, y, _onPickResultCallable.nativeFunction);
  }

  ///
  ///
  ///
  @override
  Future<Matrix4> getCameraViewMatrix() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }
    var mainCamera = await getMainCamera() as FFICamera;
    var matrixStruct = get_camera_view_matrix(mainCamera.camera);
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
    var mainCamera = await getMainCamera() as FFICamera;
    var matrixStruct = get_camera_model_matrix(mainCamera.camera);
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
    var mainCamera = await getMainCamera() as FFICamera;
    var matrixStruct = get_camera_projection_matrix(mainCamera.camera);
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
    var mainCamera = await getMainCamera() as FFICamera;
    var matrixStruct = get_camera_culling_projection_matrix(mainCamera.camera);
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

  ///
  ///
  ///
  @override
  Future<Frustum> getCameraFrustum() async {
    if (_viewer == null) {
      throw Exception("No viewer available");
    }
    var mainCamera = await getMainCamera() as FFICamera;
    var arrayPtr = get_camera_frustum(mainCamera.camera);
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
  Future<ThermionEntity> createGeometry(Geometry geometry,
      {MaterialInstance? materialInstance, bool keepData = false}) async {
    if (_viewer == null) {
      throw Exception("Viewer must not be null");
    }

    
    var entity = await withIntCallback((callback) =>
        SceneManager_createGeometryRenderThread(
            _sceneManager!,
            geometry.vertices.address,
            geometry.vertices.length,
            geometry.normals.address,
            geometry.normals.length,
            geometry.uvs.address,
            geometry.uvs.length,
            geometry.indices.address,
            geometry.indices.length,
            geometry.primitiveType.index,
            materialInstance == null
                ? nullptr
                : (materialInstance as ThermionFFIMaterialInstance)._pointer,
            keepData,
            callback));
    if (entity == _FILAMENT_ASSET_ERROR) {
      throw Exception("Failed to create geometry");
    }

    _sceneUpdateEventController
        .add(SceneUpdateEvent.addGeometry(entity, geometry));

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
  Future<v64.Aabb3> getRenderableBoundingBox(ThermionEntity entityId) async {
    final result =
        SceneManager_getRenderableBoundingBox(_sceneManager!, entityId);
    return v64.Aabb3.centerAndHalfExtents(
        Vector3(result.centerX, result.centerY, result.centerZ),
        Vector3(result.halfExtentX, result.halfExtentY, result.halfExtentZ));
  }

  ///
  ///
  ///
  @override
  Future<v64.Aabb2> getViewportBoundingBox(ThermionEntity entityId) async {
    final view = (await getViewAt(0)) as FFIView;
    final result = get_bounding_box(_sceneManager!, view.view, entityId);
    return v64.Aabb2.minMax(v64.Vector2(result.minX, result.minY),
        v64.Vector2(result.maxX, result.maxY));
  }

  ///
  ///
  ///
  Future setLayerVisibility(int layer, bool visible) async {
    final view = (await getViewAt(0)) as FFIView;
    View_setLayerEnabled(view.view, layer, visible);
  }

  ///
  ///
  ///
  Future setVisibilityLayer(ThermionEntity entity, int layer) async {
    SceneManager_setVisibilityLayer(_sceneManager!, entity, layer);
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

  ///
  ///
  ///
  Future setMaterialPropertyFloat(ThermionEntity entity, String propertyName,
      int materialIndex, double value) async {
    final ptr = propertyName.toNativeUtf8(allocator: allocator);
    set_material_property_float(
        _sceneManager!, entity, materialIndex, ptr.cast<Char>(), value);
    allocator.free(ptr);
  }

  ///
  ///
  ///
  Future setMaterialPropertyFloat4(ThermionEntity entity, String propertyName,
      int materialIndex, double f1, double f2, double f3, double f4) async {
    final ptr = propertyName.toNativeUtf8(allocator: allocator);
    var struct = Struct.create<double4>();
    struct.x = f1;
    struct.y = f2;
    struct.z = f3;
    struct.w = f4;
    set_material_property_float4(
        _sceneManager!, entity, materialIndex, ptr.cast<Char>(), struct);
    allocator.free(ptr);
  }

  Future<Uint8List> unproject(ThermionEntity entity, Uint8List input,
      int inputWidth, int inputHeight, int outWidth, int outHeight) async {
    final outPtr = Uint8List(outWidth * outHeight * 4);
    await withVoidCallback((callback) {
      unproject_texture_render_thread(
          _viewer!,
          entity,
          input.address,
          inputWidth,
          inputHeight,
          outPtr.address,
          outWidth,
          outHeight,
          callback);
    });

    return outPtr.buffer.asUint8List();
  }

  Future<ThermionTexture> createTexture(Uint8List data) async {
    var ptr = create_texture(_sceneManager!, data.address, data.length);
    return ThermionFFITexture(ptr);
  }

  Future applyTexture(ThermionFFITexture texture, ThermionEntity entity,
      {int materialIndex = 0, String parameterName = "baseColorMap"}) async {
    using(parameterName.toNativeUtf8(), (namePtr) async {
      apply_texture_to_material(_sceneManager!, entity, texture._pointer,
          namePtr.cast<Char>(), materialIndex);
    });
  }

  ///
  ///
  ///
  Future destroyTexture(ThermionFFITexture texture) async {
    destroy_texture(_sceneManager!, texture._pointer);
  }

  Future<MaterialInstance> createUbershaderMaterialInstance(
      {bool doubleSided = false,
      bool unlit = false,
      bool hasVertexColors = false,
      bool hasBaseColorTexture = false,
      bool hasNormalTexture = false,
      bool hasOcclusionTexture = false,
      bool hasEmissiveTexture = false,
      bool useSpecularGlossiness = false,
      AlphaMode alphaMode = AlphaMode.OPAQUE,
      bool enableDiagnostics = false,
      bool hasMetallicRoughnessTexture = false,
      int metallicRoughnessUV = 0,
      int baseColorUV = 0,
      bool hasClearCoatTexture = false,
      int clearCoatUV = 0,
      bool hasClearCoatRoughnessTexture = false,
      int clearCoatRoughnessUV = 0,
      bool hasClearCoatNormalTexture = false,
      int clearCoatNormalUV = 0,
      bool hasClearCoat = false,
      bool hasTransmission = false,
      bool hasTextureTransforms = false,
      int emissiveUV = 0,
      int aoUV = 0,
      int normalUV = 0,
      bool hasTransmissionTexture = false,
      int transmissionUV = 0,
      bool hasSheenColorTexture = false,
      int sheenColorUV = 0,
      bool hasSheenRoughnessTexture = false,
      int sheenRoughnessUV = 0,
      bool hasVolumeThicknessTexture = false,
      int volumeThicknessUV = 0,
      bool hasSheen = false,
      bool hasIOR = false,
      bool hasVolume = false}) async {
    final key = Struct.create<TMaterialKey>();

    key.doubleSided = doubleSided;
    key.unlit = unlit;
    key.hasVertexColors = hasVertexColors;
    key.hasBaseColorTexture = hasBaseColorTexture;
    key.hasNormalTexture = hasNormalTexture;
    key.hasOcclusionTexture = hasOcclusionTexture;
    key.hasEmissiveTexture = hasEmissiveTexture;
    key.useSpecularGlossiness = useSpecularGlossiness;
    key.alphaMode = alphaMode.index;
    key.enableDiagnostics = enableDiagnostics;
    key.unnamed.unnamed.hasMetallicRoughnessTexture =
        hasMetallicRoughnessTexture;
    key.unnamed.unnamed.metallicRoughnessUV = 0;
    key.baseColorUV = baseColorUV;
    key.hasClearCoatTexture = hasClearCoatTexture;
    key.clearCoatUV = clearCoatUV;
    key.hasClearCoatRoughnessTexture = hasClearCoatRoughnessTexture;
    key.clearCoatRoughnessUV = clearCoatRoughnessUV;
    key.hasClearCoatNormalTexture = hasClearCoatNormalTexture;
    key.clearCoatNormalUV = clearCoatNormalUV;
    key.hasClearCoat = hasClearCoat;
    key.hasTransmission = hasTransmission;
    key.hasTextureTransforms = hasTextureTransforms;
    key.emissiveUV = emissiveUV;
    key.aoUV = aoUV;
    key.normalUV = normalUV;
    key.hasTransmissionTexture = hasTransmissionTexture;
    key.transmissionUV = transmissionUV;
    key.hasSheenColorTexture = hasSheenColorTexture;
    key.sheenColorUV = sheenColorUV;
    key.hasSheenRoughnessTexture = hasSheenRoughnessTexture;
    key.sheenRoughnessUV = sheenRoughnessUV;
    key.hasVolumeThicknessTexture = hasVolumeThicknessTexture;
    key.volumeThicknessUV = volumeThicknessUV;
    key.hasSheen = hasSheen;
    key.hasIOR = hasIOR;
    key.hasVolume = hasVolume;

    final materialInstance = create_material_instance(_sceneManager!, key);
    if (materialInstance == nullptr) {
      throw Exception("Failed to create material instance");
    }

    return ThermionFFIMaterialInstance(materialInstance);
  }

  ///
  ///
  ///
  Future destroyMaterialInstance(
      ThermionFFIMaterialInstance materialInstance) async {
    destroy_material_instance(_sceneManager!, materialInstance._pointer);
  }

  ///
  ///
  ///
  Future<ThermionFFIMaterialInstance> createUnlitMaterialInstance() async {
    var instance = await withPointerCallback<TMaterialInstance>((cb) {
      SceneManager_createUnlitMaterialInstanceRenderThread(_sceneManager!, cb);
    });
    if (instance == nullptr) {
      throw Exception("Failed to create material instance");
    }
    return ThermionFFIMaterialInstance(instance);
  }

  ///
  ///
  ///
  Future<ThermionFFIMaterialInstance>
      createUnlitFixedSizeMaterialInstance() async {
    var instance = await withPointerCallback<TMaterialInstance>((cb) {
      SceneManager_createUnlitFixedSizeMaterialInstanceRenderThread(
          _sceneManager!, cb);
    });
    if (instance == nullptr) {
      throw Exception("Failed to create material instance");
    }
    return ThermionFFIMaterialInstance(instance);
  }

  @override
  Future setMaterialPropertyInt(ThermionEntity entity, String propertyName,
      int materialIndex, int value) {
    final ptr = propertyName.toNativeUtf8(allocator: allocator);
    set_material_property_int(
        _sceneManager!, entity, materialIndex, ptr.cast<Char>(), value);
    allocator.free(ptr);
    return Future.value();
  }

  ///
  ///
  ///
  Future<MaterialInstance?> getMaterialInstanceAt(
      ThermionEntity entity, int index) async {
    final instance = get_material_instance_at(_sceneManager!, entity, index);
    if (instance == nullptr) {
      return null;
    }
    return ThermionFFIMaterialInstance(instance);
  }

  @override
  Future requestFrame() async {
    for (final hook in _hooks) {
      await hook.call();
    }
    final completer = Completer();

    final callback = NativeCallable<Void Function()>.listener(() {
      completer.complete(true);
    });

    Viewer_requestFrameRenderThread(_viewer!, callback.nativeFunction);

    try {
      await completer.future.timeout(Duration(seconds: 1));
    } catch (err) {
      print("WARNING - render call timed out");
    }
  }

  Future<Camera> createCamera() async {
    var cameraPtr = SceneManager_createCamera(_sceneManager!);
    var engine = Viewer_getEngine(_viewer!);
    var camera = FFICamera(cameraPtr, engine);
    return camera;
  }

  Future destroyCamera(FFICamera camera) async {
    SceneManager_destroyCamera(_sceneManager!, camera.camera);
  }

  ///
  ///
  ///
  Future setActiveCamera(FFICamera camera) async {
    final view = (await getViewAt(0)) as FFIView;
    View_setCamera(view.view, camera.camera);
  }

  ///
  ///
  ///
  Future<Camera> getActiveCamera() async {
    final view = (await getViewAt(0)) as FFIView;
    var camera = view.getCamera();
    return camera;
  }

  final _hooks = <Future Function()>[];

  @override
  Future registerRequestFrameHook(Future Function() hook) async {
    if (!_hooks.contains(hook)) {
      _hooks.add(hook);
    }
  }

  @override
  Future unregisterRequestFrameHook(Future Function() hook) async {
    if (_hooks.contains(hook)) {
      _hooks.remove(hook);
    }
  }

  ///
  ///
  ///
  int getCameraCount() {
    return SceneManager_getCameraCount(_sceneManager!);
  }

  ///
  /// Returns the camera specified by the given index. Note that the camera at
  /// index 0 is always the main camera; this cannot be destroyed.
  ///
  Camera getCameraAt(int index) {
    final camera = SceneManager_getCameraAt(_sceneManager!, index);
    if (camera == nullptr) {
      throw Exception("No camera at index $index");
    }
    return FFICamera(camera, Viewer_getEngine(_viewer!));
  }

  @override
  Future<View> getViewAt(int index) async {
    var view = Viewer_getViewAt(_viewer!, index);
    if (view == nullptr) {
      throw Exception("Failed to get view");
    }
    return FFIView(view, _viewer!);
  }

  @override
  Future<Gizmo> createGizmo(FFIView view) async {
    var view = (await getViewAt(0)) as FFIView;
    var scene = View_getScene(view.view);
    final gizmo = SceneManager_createGizmo(_sceneManager!, view.view, scene);
    return FFIGizmo(gizmo, this);
  }
}

class ThermionFFITexture extends ThermionTexture {
  final Pointer<Void> _pointer;

  ThermionFFITexture(this._pointer);
}

class ThermionFFIMaterialInstance extends MaterialInstance {
  final Pointer<TMaterialInstance> _pointer;

  ThermionFFIMaterialInstance(this._pointer);

  @override
  Future setDepthCullingEnabled(bool enabled) async {
    MaterialInstance_setDepthCulling(this._pointer, enabled);
  }

  @override
  Future setDepthWriteEnabled(bool enabled) async {
    MaterialInstance_setDepthWrite(this._pointer, enabled);
  }

  @override
  Future setParameterFloat4(String name, double x, double y, double z, double w) async {
    MaterialInstance_setParameterFloat4(
        _pointer, name.toNativeUtf8().cast<Char>(), x, y, z, w);
  }

  @override
  Future setParameterFloat2(String name, double x, double y) async {
    MaterialInstance_setParameterFloat2(
        _pointer, name.toNativeUtf8().cast<Char>(), x, y);
  }

  @override
  Future setParameterFloat(String name, double value) async {
    MaterialInstance_setParameterFloat(
        _pointer, name.toNativeUtf8().cast<Char>(), value);
  }

  @override
  Future setParameterInt(String name, int value) async {
    MaterialInstance_setParameterInt(
        _pointer, name.toNativeUtf8().cast<Char>(), value);
  }


}

class FFIRenderTarget extends RenderTarget {
  final Pointer<TRenderTarget> renderTarget;
  final Pointer<TViewer> viewer;

  FFIRenderTarget(this.renderTarget, this.viewer);
}

class FFISwapChain extends SwapChain {
  final Pointer<TSwapChain> swapChain;
  final Pointer<TViewer> viewer;

  FFISwapChain(this.swapChain, this.viewer);
}

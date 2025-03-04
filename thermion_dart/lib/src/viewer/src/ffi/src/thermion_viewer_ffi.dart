import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_asset.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_gizmo.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_material.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_render_target.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_texture.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
import '../../../../utils/src/matrix.dart';
import '../../thermion_viewer_base.dart';
import 'package:logging/logging.dart';

import 'callbacks.dart';
import 'ffi_camera.dart';
import 'ffi_view.dart';

// ignore: constant_identifier_names
const ThermionEntity FILAMENT_ASSET_ERROR = 0;

typedef RenderCallback = Pointer<NativeFunction<Void Function(Pointer<Void>)>>;

class ThermionViewerFFI extends ThermionViewer {
  final _logger = Logger("ThermionViewerFFI");

  Pointer<TSceneManager>? _sceneManager;
  Pointer<TEngine>? _engine;
  Pointer<TMaterialProvider>? _unlitMaterialProvider;
  Pointer<TMaterialProvider>? _ubershaderMaterialProvider;
  Pointer<TTransformManager>? _transformManager;
  Pointer<TLightManager>? _lightManager;
  Pointer<TRenderableManager>? _renderableManager;
  Pointer<TViewer>? _viewer;
  Pointer<TAnimationManager>? _animationManager;
  Pointer<TNameComponentManager>? _nameComponentManager;

  final String? uberArchivePath;

  final _initialized = Completer<bool>();
  Future<bool> get initialized => _initialized.future;

  final Pointer<Void> resourceLoader;

  var _driver = nullptr.cast<Void>();

  late final RenderCallback _renderCallback;
  var _renderCallbackOwner = nullptr.cast<Void>();

  var _sharedContext = nullptr.cast<Void>();

  late NativeCallable<PickCallbackFunction> _onPickResultCallable;

  ///
  ///
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
        NativeCallable<PickCallbackFunction>.listener(_onPickResult);

    _initialize();
  }

  ///
  ///
  ///
  Future<RenderTarget> createRenderTarget(
      int width, int height, int textureHandle) async {
    final renderTarget = await withPointerCallback<TRenderTarget>((cb) {
      Viewer_createRenderTargetRenderThread(
          _viewer!, textureHandle, width, height, cb);
    });

    return FFIRenderTarget(renderTarget, _viewer!, _engine!);
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
      await withVoidCallback((cb) {
        Viewer_destroyRenderTargetRenderThread(
            _viewer!, renderTarget.renderTarget, cb);
      });
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
    return FFIView(view, _viewer!,_engine!);
  }

  ///
  ///
  ///
  Future updateViewportAndCameraProjection(double width, double height) async {
    var mainView = FFIView(Viewer_getViewAt(_viewer!, 0), _viewer!, _engine!);
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
  Future destroySwapChain(SwapChain swapChain) async {
    if (_viewer != null) {
      await withVoidCallback((callback) {
        Viewer_destroySwapChainRenderThread(
            _viewer!, (swapChain as FFISwapChain).swapChain, callback);
      });
    }
  }

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
    _unlitMaterialProvider =
        SceneManager_getUnlitMaterialProvider(_sceneManager!);
    _ubershaderMaterialProvider =
        SceneManager_getUbershaderMaterialProvider(_sceneManager!);
    _engine = Viewer_getEngine(_viewer!);
    _transformManager = Engine_getTransformManager(_engine!);
    _lightManager = Engine_getLightManager(_engine!);
    _animationManager = SceneManager_getAnimationManager(_sceneManager!);
    _nameComponentManager =
        SceneManager_getNameComponentManager(_sceneManager!);
    _renderableManager = Engine_getRenderableManager(_engine!);
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

  double _msPerFrame = 1000.0 / 60.0;

  ///
  ///
  ///
  double get msPerFrame {
    return _msPerFrame;
  }

  ///
  ///
  ///
  @override
  Future setFrameRate(int framerate) async {
    _msPerFrame = 1000.0 / framerate;
    set_frame_interval_render_thread(_viewer!, _msPerFrame);
  }

  final _onDispose = <Future Function()>[];
  bool _disposing = false;

  final _materialInstances = <FFIMaterialInstance>[];

  ///
  ///
  ///
  @override
  Future dispose() async {
    if (_viewer == null) {
      throw Exception("Viewer has already been disposed.");
    }
    _disposing = true;
    await setRendering(false);
    await destroyAssets();
    for (final mInstance in _materialInstances) {
      await mInstance.dispose();
    }
    await destroyLights();

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
      Viewer_loadSkyboxRenderThread(_viewer!, pathPtr, cb);
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
    await withVoidCallback((cb) {
      Viewer_removeSkyboxRenderThread(_viewer!, cb);
    });
  }

  ///
  ///
  ///
  @override
  Future removeIbl() async {
    await withVoidCallback((cb) {
      Viewer_removeIblRenderThread(_viewer!, cb);
    });
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
    var entity = await withIntCallback((cb) {
      SceneManager_addLightRenderThread(
          _sceneManager!,
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
          cb);
    });
    if (entity == FILAMENT_ASSET_ERROR) {
      throw Exception("Failed to add light to scene");
    }
    return entity;
  }

  ///
  ///
  ///
  @override
  Future removeLight(ThermionEntity entity) async {
    await withVoidCallback((cb) {
      SceneManager_removeLightRenderThread(_sceneManager!, entity, cb);
    });
  }

  ///
  ///
  ///
  @override
  Future destroyLights() async {
    await withVoidCallback((cb) {
      SceneManager_destroyLightsRenderThread(_sceneManager!, cb);
    });
  }

  ///
  ///
  ///
  @override
  Future<ThermionAsset> loadGlb(String path,
      {bool unlit = false, int numInstances = 1, bool keepData = false}) async {
    if (unlit) {
      throw Exception("Not yet implemented");
    }
    final pathPtr = path.toNativeUtf8(allocator: allocator).cast<Char>();
    var asset = await withPointerCallback<TSceneAsset>((callback) =>
        SceneManager_loadGlbRenderThread(
            _sceneManager!, pathPtr, numInstances, keepData, callback));

    allocator.free(pathPtr);
    if (asset == nullptr) {
      throw Exception("An error occurred loading the asset at $path");
    }

    var thermionAsset = FFIAsset(
        asset, _sceneManager!, _engine!, _unlitMaterialProvider!, this);

    return thermionAsset;
  }

  ///
  ///
  ///
  @override
  Future<ThermionAsset> loadGlbFromBuffer(Uint8List data,
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

    var assetPtr = await withPointerCallback<TSceneAsset>((callback) =>
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

    if (assetPtr == nullptr) {
      throw Exception("An error occurred loading GLB from buffer");
    }
    return FFIAsset(
        assetPtr, _sceneManager!, _engine!, _unlitMaterialProvider!, this);
  }

  ///
  ///
  ///
  @override
  Future<ThermionAsset> loadGltf(String path, String relativeResourcePath,
      {bool keepData = false}) async {
    final pathPtr = path.toNativeUtf8(allocator: allocator).cast<Char>();
    final relativeResourcePathPtr =
        relativeResourcePath.toNativeUtf8(allocator: allocator).cast<Char>();
    var assetPtr = await withPointerCallback<TSceneAsset>((callback) =>
        SceneManager_loadGltfRenderThread(_sceneManager!, pathPtr,
            relativeResourcePathPtr, keepData, callback));
    allocator.free(pathPtr);
    allocator.free(relativeResourcePathPtr);
    if (assetPtr == nullptr) {
      throw Exception("An error occurred loading the asset at $path");
    }

    return FFIAsset(
        assetPtr, _sceneManager!, _engine!, _unlitMaterialProvider!, this);
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
      AnimationManager_setMorphTargetWeightsRenderThread(
          _animationManager!, entity, weightsPtr, weights.length, cb);
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
      covariant FFIAsset asset, ThermionEntity childEntity) async {
    var names = <String>[];

    var count = AnimationManager_getMorphTargetNameCount(
        _animationManager!, asset.pointer, childEntity);
    var outPtr = allocator<Char>(255);
    for (int i = 0; i < count; i++) {
      AnimationManager_getMorphTargetName(
          _animationManager!, asset.pointer, childEntity, outPtr, i);
      names.add(outPtr.cast<Utf8>().toDartString());
    }
    allocator.free(outPtr);
    return names.cast<String>();
  }

  Future<List<String>> getBoneNames(covariant FFIAsset asset,
      {int skinIndex = 0}) async {
    var count = AnimationManager_getBoneCount(
        _animationManager!, asset.pointer, skinIndex);
    var out = allocator<Pointer<Char>>(count);
    for (int i = 0; i < count; i++) {
      out[i] = allocator<Char>(255);
    }

    AnimationManager_getBoneNames(
        _animationManager!, asset.pointer, out, skinIndex);
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
  Future<List<String>> getAnimationNames(covariant FFIAsset asset) async {
    var animationCount =
        AnimationManager_getAnimationCount(_animationManager!, asset.pointer);
    var names = <String>[];
    var outPtr = allocator<Char>(255);
    for (int i = 0; i < animationCount; i++) {
      AnimationManager_getAnimationName(
          _animationManager!, asset.pointer, outPtr, i);
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
      FFIAsset asset, int animationIndex) async {
    return AnimationManager_getAnimationDuration(
        _animationManager!, asset.pointer, animationIndex);
  }

  ///
  ///
  ///
  Future<double> getAnimationDurationByName(FFIAsset asset, String name) async {
    var animations = await getAnimationNames(asset);
    var index = animations.indexOf(name);
    if (index == -1) {
      throw Exception("Failed to find animation $name");
    }
    return getAnimationDuration(asset, index);
  }

  Future clearMorphAnimationData(ThermionEntity entity) async {
    if (!AnimationManager_clearMorphAnimation(_animationManager!, entity)) {
      throw Exception("Failed to clear morph animation");
    }
  }

  ///
  ///
  ///
  @override
  Future setMorphAnimationData(FFIAsset asset, MorphAnimationData animation,
      {List<String>? targetMeshNames}) async {
    var meshEntities = await getChildEntities(asset);

    var meshNames = meshEntities.map((e) => getNameForEntity(e)).toList();
    if (targetMeshNames != null) {
      for (final targetMeshName in targetMeshNames) {
        if (!meshNames.contains(targetMeshName)) {
          throw Exception(
              "Error: mesh ${targetMeshName} does not exist under the specified entity. Available meshes : ${meshNames}");
        }
      }
    }

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

      var meshMorphTargets = await getMorphTargetNames(asset, meshEntity);

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

      var result = AnimationManager_setMorphAnimation(
          _animationManager!,
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
  Future addBoneAnimation(covariant FFIAsset asset, BoneAnimationData animation,
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
    var boneNames = await getBoneNames(asset);
    var restLocalTransformsRaw = allocator<Float>(boneNames.length * 16);
    AnimationManager_getRestLocalTransforms(_animationManager!, asset.pointer,
        skinIndex, restLocalTransformsRaw, boneNames.length);

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
        boneNames.length, (i) => getBone(asset, i)));

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

      AnimationManager_addBoneAnimation(
          _animationManager!,
          asset.pointer,
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
    return double4x4ToMatrix4(
        TransformManager_getLocalTransform(_transformManager!, entity));
  }

  ///
  ///
  ///
  Future<Matrix4> getWorldTransform(ThermionEntity entity) async {
    return double4x4ToMatrix4(
        TransformManager_getWorldTransform(_transformManager!, entity));
  }

  ///
  ///
  ///
  Future setTransform(ThermionEntity entity, Matrix4 transform) async {
    TransformManager_setTransform(
        _transformManager!, entity, matrix4ToDouble4x4(transform));
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
  Future<Matrix4> getInverseBindMatrix(FFIAsset asset, int boneIndex,
      {int skinIndex = 0}) async {
    var matrix = Float32List(16);
    AnimationManager_getInverseBindMatrix(_animationManager!, asset.pointer,
        skinIndex, boneIndex, matrix.address);
    return Matrix4.fromList(matrix);
  }

  ///
  ///
  ///
  Future<ThermionEntity> getBone(FFIAsset asset, int boneIndex,
      {int skinIndex = 0}) async {
    if (skinIndex != 0) {
      throw UnimplementedError("TOOD");
    }
    return AnimationManager_getBone(
        _animationManager!, asset.pointer, skinIndex, boneIndex);
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
  Future resetBones(covariant FFIAsset asset) async {
    AnimationManager_resetToRestPose(_animationManager!, asset.pointer);
  }

  ///
  ///
  ///
  ///
  ///
  ///
  @override
  Future destroyAsset(covariant FFIAsset asset) async {
    if (asset.boundingBoxAsset != null) {
      await asset.setBoundingBoxVisibility(false);
      await withVoidCallback((callback) =>
          SceneManager_destroyAssetRenderThread(
              _sceneManager!, asset.boundingBoxAsset!.pointer, callback));
    }
    await withVoidCallback((callback) => SceneManager_destroyAssetRenderThread(
        _sceneManager!, asset.pointer, callback));
  }

  ///
  ///
  ///
  @override
  Future destroyAssets() async {
    await withVoidCallback((callback) {
      SceneManager_destroyAssetsRenderThread(_sceneManager!, callback);
    });
  }

  ///
  ///
  ///
  @override
  Future playAnimation(covariant FFIAsset asset, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      double startOffset = 0.0}) async {
    AnimationManager_playAnimation(_animationManager!, asset.pointer, index,
        loop, reverse, replaceActive, crossfade, startOffset);
  }

  ///
  ///
  ///
  @override
  Future stopAnimation(FFIAsset asset, int animationIndex) async {
    AnimationManager_stopAnimation(
        _animationManager!, asset.pointer, animationIndex);
  }

  ///
  ///
  ///
  @override
  Future stopAnimationByName(FFIAsset asset, String name) async {
    var animations = await getAnimationNames(asset);
    await stopAnimation(asset, animations.indexOf(name));
  }

  ///
  ///
  ///
  @override
  Future playAnimationByName(FFIAsset asset, String name,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      bool wait = false}) async {
    var animations = await getAnimationNames(asset);
    var index = animations.indexOf(name);
    var duration = await getAnimationDuration(asset, index);
    await playAnimation(asset, index,
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
  Future setGltfAnimationFrame(
      FFIAsset asset, int index, int animationFrame) async {
    AnimationManager_setGltfAnimationFrame(
        _animationManager!, asset.pointer, index, animationFrame);
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
    return Viewer_getMainCamera(_viewer!);
  }

  ///
  ///
  ///
  Future<Camera> getMainCamera() async {
    final mainCameraEntity = await getMainCameraEntity();
    var camera = await getCameraComponent(mainCameraEntity);
    return camera!;
  }

  ///
  ///
  ///
  Future<Camera?> getCameraComponent(ThermionEntity cameraEntity) async {
    var engine = Viewer_getEngine(_viewer!);
    var camera = Engine_getCameraComponent(engine, cameraEntity);
    if (camera == nullptr) {
      throw Exception(
          "Failed to get camera component for entity $cameraEntity");
    }
    return FFICamera(camera, engine, _transformManager!);
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
    if (Platform.isWindows && msaa) {
      throw Exception("MSAA is not currently supported on Windows");
    }
    final view = await getViewAt(0) as FFIView;
    View_setAntiAliasing(view.view, msaa, fxaa, taa);
  }

  ///
  ///
  ///
  @override
  Future setBloom(bool enabled, double strength) async {
    final view = await getViewAt(0) as FFIView;
    View_setBloom(view.view, enabled, strength);
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
  Future transformToUnitCube(ThermionEntity entity) async {
    SceneManager_transformToUnitCube(_sceneManager!, entity);
  }

  ///
  ///
  ///
  @override
  Future setLightPosition(
      ThermionEntity lightEntity, double x, double y, double z) async {
    LightManager_setPosition(_lightManager!, lightEntity, x, y, z);
  }

  ///
  ///
  ///
  @override
  Future setLightDirection(
      ThermionEntity lightEntity, Vector3 direction) async {
    direction.normalize();
    LightManager_setPosition(
        _lightManager!, lightEntity, direction.x, direction.y, direction.z);
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
  Future removeAssetFromScene(ThermionEntity entity) async {
    if (SceneManager_removeFromScene(_sceneManager!, entity) != 1) {
      throw Exception("Failed to remove entity from scene");
    }
  }

  ///
  ///
  ///
  @override
  Future addEntityToScene(ThermionEntity entity) async {
    if (SceneManager_addToScene(_sceneManager!, entity) != 1) {
      throw Exception("Failed to add entity to scene");
    }
  }

  ///
  ///
  ///
  @override
  String? getNameForEntity(ThermionEntity entity) {
    final result = NameComponentManager_getName(_nameComponentManager!, entity);
    if (result == nullptr) {
      return null;
    }
    return result.cast<Utf8>().toDartString();
  }

  void _onPickResult(int requestId, ThermionEntity entityId, double depth,
      double fragX, double fragY, double fragZ) async {
    if (!_pickRequests.containsKey(requestId)) {
      _logger.severe(
          "Warning : pick result received with no matching request ID. This indicates you're clearing the pick cache too quickly");
      return;
    }
    final (:handler, :x, :y, :view) = _pickRequests[requestId]!;
    _pickRequests.remove(requestId);

    final viewport = await view.getViewport();

    handler.call((
      entity: entityId,
      x: x,
      y: y,
      depth: depth,
      fragX: fragX,
      fragY: viewport.height - fragY,
      fragZ: fragZ,
    ));
  }

  int _pickRequestId = -1;
  final _pickRequests = <int,
      ({void Function(PickResult) handler, int x, int y, FFIView view})>{};

  ///
  ///
  ///
  @override
  Future pick(int x, int y, void Function(PickResult) resultHandler) async {
    _pickRequestId++;
    var pickRequestId = _pickRequestId;
    final view = (await getViewAt(0)) as FFIView;
    _pickRequests[pickRequestId] =
        (handler: resultHandler, x: x, y: y, view: view);

    var viewport = await view.getViewport();
    y = viewport.height - y;

    View_pick(
        view.view, pickRequestId, x, y, _onPickResultCallable.nativeFunction);

    Future.delayed(Duration(seconds: 1)).then((_) {
      _pickRequests.remove(pickRequestId);
    });
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
  Future<ThermionEntity?> getChildEntity(
      FFIAsset asset, String childName) async {
    final childEntities = await getChildEntities(asset);
    for (final entity in childEntities) {
      var name = await getNameForEntity(entity);
      if (name == childName) {
        return entity;
      }
    }
    return null;
  }

  Future<List<ThermionEntity>> getChildEntities(FFIAsset asset) async {
    var count = SceneAsset_getChildEntityCount(asset.pointer);
    var out = Int32List(count);
    SceneAsset_getChildEntities(asset.pointer, out.address);
    return out;
  }

  final _collisions = <ThermionEntity, NativeCallable>{};

  ///
  ///
  ///
  @override
  Future addCollisionComponent(ThermionEntity entity,
      {void Function(int entityId1, int entityId2)? callback,
      bool affectsTransform = false}) async {
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
    AnimationManager_addAnimationComponent(_animationManager!, entity);
  }

  ///
  ///
  ///
  Future removeAnimationComponent(ThermionEntity entity) async {
    AnimationManager_removeAnimationComponent(_animationManager!, entity);
  }

  ///
  ///
  ///
  @override
  Future<ThermionAsset> createGeometry(Geometry geometry,
      {List<MaterialInstance>? materialInstances,
      bool keepData = false}) async {
    if (_viewer == null) {
      throw Exception("Viewer must not be null");
    }

    var assetPtr = await withPointerCallback<TSceneAsset>((callback) {
      var ptrList = Int64List(materialInstances?.length ?? 0);
      if (materialInstances != null && materialInstances.isNotEmpty) {
        ptrList.setRange(
            0,
            materialInstances.length,
            materialInstances
                .cast<FFIMaterialInstance>()
                .map((mi) => mi.pointer.address)
                .toList());
      }

      return SceneManager_createGeometryRenderThread(
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
          ptrList.address.cast<Pointer<TMaterialInstance>>(),
          ptrList.length,
          keepData,
          callback);
    });
    if (assetPtr == nullptr) {
      throw Exception("Failed to create geometry");
    }

    print(
        " is shadow caster : ${RenderableManager_isShadowCaster(_renderableManager!, SceneAsset_getEntity(assetPtr))}  is shadow recevier : ${RenderableManager_isShadowReceiver(_renderableManager!, SceneAsset_getEntity(assetPtr))} ");

    var asset = FFIAsset(
        assetPtr, _sceneManager!, _engine!, _unlitMaterialProvider!, this);

    return asset;
  }

  ///
  ///
  ///
  @override
  Future setParent(ThermionEntity child, ThermionEntity? parent,
      {bool preserveScaling = false}) async {
    if (_sceneManager == null) {
      throw Exception("Asset manager must be non-null");
    }
    TransformManager_setParent(_transformManager!, child,
        parent ?? FILAMENT_ENTITY_NULL, preserveScaling);
  }

  ///
  ///
  ///
  @override
  Future<ThermionEntity?> getParent(ThermionEntity child) async {
    if (_sceneManager == null) {
      throw Exception("Asset manager must be non-null");
    }
    var parent = TransformManager_getParent(_transformManager!, child);
    if (parent == FILAMENT_ASSET_ERROR) {
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
    var parent = TransformManager_getAncestor(_transformManager!, child);
    if (parent == FILAMENT_ASSET_ERROR) {
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
    RenderableManager_setPriority(_renderableManager!, entityId, priority);
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
  Future setLayerVisibility(VisibilityLayers layer, bool visible) async {
    final view = (await getViewAt(0)) as FFIView;
    View_setLayerEnabled(view.view, layer.value, visible);
  }

  ///
  ///
  ///
  Future setVisibilityLayer(
      ThermionEntity entity, VisibilityLayers layer) async {
    SceneManager_setVisibilityLayer(_sceneManager!, entity, layer.value);
  }

  FFIAsset? _grid;

  ///
  ///
  ///
  Future showGridOverlay({FFIMaterial? material}) async {
    if (_grid == null) {
      final ptr = await withPointerCallback<TSceneAsset>((cb) {
        if (material == null) {
          SceneManager_createGridRenderThread(_sceneManager!, nullptr, cb);
        } else {
          SceneManager_createGridRenderThread(
              _sceneManager!, material.pointer, cb);
        }
      });
      _grid = FFIAsset(
          ptr, _sceneManager!, _engine!, _unlitMaterialProvider!, this);
    }
    await _grid!.addToScene();
    await setLayerVisibility(VisibilityLayers.OVERLAY, true);
  }

  ///
  ///
  ///
  Future removeGridOverlay() async {
    if (_grid != null) {
      await _grid!.removeFromScene();
      SceneManager_destroyAsset(_sceneManager!, _grid!.pointer);
      _grid = null;
    }
  }

  ///
  ///
  ///
  Future<Texture> createTexture(int width, int height,
      {int levels = 1,
      TextureSamplerType textureSamplerType = TextureSamplerType.SAMPLER_2D,
      TextureFormat textureFormat = TextureFormat.RGBA16F}) async {
    final texturePtr = await withPointerCallback<TTexture>((cb) {
      Engine_buildTextureRenderThread(
          _engine!,
          width,
          height,
          levels,
          TTextureSamplerType.values[textureSamplerType.index],
          TTextureFormat.values[textureFormat.index],
          cb);
    });
    if (texturePtr == nullptr) {
      throw Exception("Failed to create texture");
    }
    return FFITexture(
      _engine!,
      texturePtr,
    );
  }

  Future<TextureSampler> createTextureSampler(
      {TextureMinFilter minFilter = TextureMinFilter.LINEAR,
      TextureMagFilter magFilter = TextureMagFilter.LINEAR,
      TextureWrapMode wrapS = TextureWrapMode.CLAMP_TO_EDGE,
      TextureWrapMode wrapT = TextureWrapMode.CLAMP_TO_EDGE,
      TextureWrapMode wrapR = TextureWrapMode.CLAMP_TO_EDGE,
      double anisotropy = 0.0,
      TextureCompareMode compareMode = TextureCompareMode.NONE,
      TextureCompareFunc compareFunc = TextureCompareFunc.LESS_EQUAL}) async {
    final samplerPtr = TextureSampler_create();
    TextureSampler_setMinFilter(
        samplerPtr, TSamplerMinFilter.values[minFilter.index]);
    TextureSampler_setMagFilter(
        samplerPtr, TSamplerMagFilter.values[magFilter.index]);
    TextureSampler_setWrapModeS(
        samplerPtr, TSamplerWrapMode.values[wrapS.index]);
    TextureSampler_setWrapModeT(
        samplerPtr, TSamplerWrapMode.values[wrapT.index]);
    TextureSampler_setWrapModeR(
        samplerPtr, TSamplerWrapMode.values[wrapR.index]);
    if (anisotropy > 0) {
      TextureSampler_setAnisotropy(samplerPtr, anisotropy);
    }
    if (compareMode != TextureCompareMode.NONE) {
      TextureSampler_setCompareMode(
          samplerPtr,
          TSamplerCompareMode.values[compareMode.index],
          TSamplerCompareFunc.values[compareFunc.index]);
    }
    return FFITextureSampler(samplerPtr);
  }

  ///
  ///
  ///
  Future<LinearImage> decodeImage(Uint8List data) async {
    final name = "image";
    var ptr = Image_decode(
      data.address,
      data.length,
      name.toNativeUtf8().cast<Char>(),
    );
    if (ptr == nullptr) {
      throw Exception("Failed to decode image");
    }
    return FFILinearImage(ptr);
  }

  ///
  /// Creates an (empty) imge with the given dimensions.
  ///
  Future<LinearImage> createImage(int width, int height, int channels) async {
    final ptr = Image_createEmpty(width, height, channels);
    return FFILinearImage(ptr);
  }

  ///
  ///
  ///
  Future destroyTexture(FFITexture texture) async {
    destroy_texture(_sceneManager!, texture.pointer.cast<Void>());
  }

  ///
  ///
  ///
  Future<Material> createMaterial(Uint8List data) async {
    var ptr = await withPointerCallback<TMaterial>((cb) {
      Engine_buildMaterialRenderThread(_engine!, data.address, data.length, cb);
    });
    return FFIMaterial(ptr, _engine!, _sceneManager!);
  }

  ///
  ///
  ///
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

    final materialInstance = await withPointerCallback<TMaterialInstance>((cb) {
      MaterialProvider_createMaterialInstanceRenderThread(
          _ubershaderMaterialProvider!, key.address, cb);
    });
    if (materialInstance == nullptr) {
      throw Exception("Failed to create material instance");
    }

    var instance = FFIMaterialInstance(materialInstance, _sceneManager!);
    _materialInstances.add(instance);
    return instance;
  }

  ///
  ///
  ///
  Future destroyMaterialInstance(FFIMaterialInstance materialInstance) async {
    await materialInstance.dispose();
    _materialInstances.remove(materialInstance);
  }

  ///
  ///
  ///
  Future<FFIMaterialInstance> createUnlitMaterialInstance() async {
    var instancePtr = await withPointerCallback<TMaterialInstance>((cb) {
      SceneManager_createUnlitMaterialInstanceRenderThread(_sceneManager!, cb);
    });
    final instance = FFIMaterialInstance(instancePtr, _sceneManager!);
    _materialInstances.add(instance);
    return instance;
  }

  ///
  ///
  ///
  Future<FFIMaterialInstance> createUnlitFixedSizeMaterialInstance() async {
    var instancePtr = await withPointerCallback<TMaterialInstance>((cb) {
      SceneManager_createUnlitFixedSizeMaterialInstanceRenderThread(
          _sceneManager!, cb);
    });
    final instance = FFIMaterialInstance(instancePtr, _sceneManager!);
    _materialInstances.add(instance);
    return instance;
  }

  ///
  ///
  ///
  Future<MaterialInstance> getMaterialInstanceAt(
      ThermionEntity entity, int index) async {
    final instancePtr = RenderableManager_getMaterialInstanceAt(
        _renderableManager!, entity, index);

    final instance = FFIMaterialInstance(instancePtr, _sceneManager!);
    return instance;
  }

  ///
  ///
  ///
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
    var cameraPtr = await withPointerCallback<TCamera>((cb) {
      SceneManager_createCameraRenderThread(_sceneManager!, cb);
    });
    var engine = Viewer_getEngine(_viewer!);
    var camera = FFICamera(cameraPtr, engine, _transformManager!);
    await camera.setLensProjection();
    return camera;
  }

  ///
  ///
  ///
  Future destroyCamera(FFICamera camera) async {
    SceneManager_destroyCamera(_sceneManager!, camera.camera);
  }

  ///
  ///
  ///
  Future setActiveCamera(FFICamera camera) async {
    final view = (await getViewAt(0)) as FFIView;
    await withVoidCallback((cb) {
      View_setCameraRenderThread(view.view, camera.camera, cb);
    });
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
    return FFICamera(camera, Viewer_getEngine(_viewer!), _transformManager!);
  }

  @override
  Future<View> getViewAt(int index) async {
    var view = Viewer_getViewAt(_viewer!, index);
    if (view == nullptr) {
      throw Exception("Failed to get view");
    }
    return FFIView(view, _viewer!, _engine!);
  }

  @override
  Future<GizmoAsset> createGizmo(FFIView view, GizmoType gizmoType) async {
    var scene = View_getScene(view.view);
    final gizmo = await withPointerCallback<TGizmo>((cb) {
      SceneManager_createGizmoRenderThread(_sceneManager!, view.view, scene,
          TGizmoType.values[gizmoType.index], cb);
    });
    if (gizmo == nullptr) {
      throw Exception("Failed to create gizmo");
    }

    final gizmoEntityCount =
        SceneAsset_getChildEntityCount(gizmo.cast<TSceneAsset>());
    final gizmoEntities = Int32List(gizmoEntityCount);
    SceneAsset_getChildEntities(
        gizmo.cast<TSceneAsset>(), gizmoEntities.address);

    return FFIGizmo(
        view,
        gizmo.cast<TSceneAsset>(),
        _sceneManager!,
        _engine!,
        nullptr,
        this,
        gizmoEntities.toSet()
          ..add(SceneAsset_getEntity(gizmo.cast<TSceneAsset>())));
  }
}



class FFISwapChain extends SwapChain {
  final Pointer<TSwapChain> swapChain;
  final Pointer<TViewer> viewer;

  FFISwapChain(this.swapChain, this.viewer);
}

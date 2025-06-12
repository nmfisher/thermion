import 'dart:async';
import 'package:thermion_dart/src/filament/src/implementation/background_image.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_indirect_light.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_ktx1_bundle.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_swapchain.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/interface/ktx1_bundle.dart';
import '../../../../filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import '../../../../filament/src/implementation/ffi_scene.dart';
import '../../../../filament/src/implementation/grid_overlay.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
import 'package:logging/logging.dart';

import '../../../../filament/src/implementation/ffi_camera.dart';
import '../../../../filament/src/implementation/ffi_view.dart';

const FILAMENT_ASSET_ERROR = 0;

///
///
///
class ThermionViewerFFI extends ThermionViewer {
  late final _logger = Logger(runtimeType.toString());

  final _initialized = Completer<bool>();
  Future<bool> get initialized => _initialized.future;

  late final FFIFilamentApp app;

  late final FFIView view;
  late final FFIScene scene;
  late final Pointer<TAnimationManager> animationManager;

  ///
  ///
  ///
  ThermionViewerFFI() {
    if (FilamentApp.instance == null) {
      throw Exception("FilamentApp has not been created");
    }
    app = FilamentApp.instance as FFIFilamentApp;

    _initialize();
  }

  ///
  ///
  ///
  Future setViewport(int width, int height) async {
    print("Setting viewport to ${width}x${height}");
    await view.setViewport(width.toInt(), height.toInt());

    for (final camera in _cameras) {
      var near = await camera.getNear();
      if (near.abs() < 0.000001) {
        near = kNear;
      }
      var far = await camera.getCullingFar();
      if (far.abs() < 0.000001) {
        far = kFar;
      }

      var aspect = width.toDouble() / height.toDouble();
      var focalLength = await camera.getFocalLength();
      if (focalLength.abs() < 0.1) {
        focalLength = kFocalLength;
      }
      await camera.setLensProjection(
        near: near,
        far: far,
        aspect: aspect,
        focalLength: focalLength,
      );
    }
  }

  Future _initialize() async {
    view = await FilamentApp.instance!.createView() as FFIView;

    await view.setRenderable(true);

    await FilamentApp.instance!.setClearOptions(0.0, 0.0, 0.0, 0.0);
    scene = await FilamentApp.instance!.createScene() as FFIScene;

    await view.setScene(scene);
    final camera = await FilamentApp.instance!.createCamera() as FFICamera;

    _cameras.add(camera);
    await camera.setLensProjection();

    await view.setCamera(camera);

    animationManager = await withPointerCallback<TAnimationManager>(
      (cb) => AnimationManager_createRenderThread(app.engine, scene.scene, cb),
    );

    RenderTicker_addAnimationManager(app.renderTicker, animationManager);

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
    await view.setRenderable(render);
  }

  ///
  ///
  ///
  @override
  Future render() async {
    await withVoidCallback(
      (requestId, cb) => RenderTicker_renderRenderThread(
        app.renderTicker,
        0.toBigInt,
        requestId,
        cb,
      ),
    );
    await FilamentApp.instance!.flush();
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
  }

  final _onDispose = <Future Function()>[];
  bool _disposed = false;

  ///
  ///
  ///
  @override
  Future dispose() async {
    _disposed = true;
    await setRendering(false);

    await _backgroundImage?.destroy();
    _backgroundImage = null;

    await destroyAssets();
    await destroyLights();

    for (final callback in _onDispose) {
      await callback.call();
    }
    View_setScene(view.view, nullptr);

    await FilamentApp.instance!.destroyScene(scene);
    await FilamentApp.instance!.destroyView(view);

    _onDispose.clear();
  }

  ///
  ///
  ///
  void onDispose(Future Function() callback) {
    _onDispose.add(callback);
  }

  BackgroundImage? _backgroundImage;

  ///
  ///
  ///
  @override
  Future clearBackgroundImage({bool destroy = false}) async {
    if (destroy) {
      await _backgroundImage?.destroy();
      _backgroundImage = null;
    } else {
      _backgroundImage?.hideImage();
    }
  }

  ///
  ///
  ///
  @override
  Future setBackgroundImage(String path, {bool fillHeight = false}) async {
    final imageData = await FilamentApp.instance!.loadResource(path);
    _backgroundImage ??= await BackgroundImage.create(this, scene);
    bool isKtx = path.endsWith(".ktx");
    if (isKtx) {
      final bundle = await FFIKtx1Bundle.create(imageData);
      await _backgroundImage!.setImageFromKtxBundle(bundle);
    } else {
      await _backgroundImage!.setImage(imageData);
    }
    return (_backgroundImage!.width!, _backgroundImage!.height!);
  }

  ///
  ///
  ///
  @override
  Future setBackgroundColor(double r, double g, double b, double a) async {
    // we don't want to use the Renderer clearColor, because this only applies
    // to clearing the swapchain. Even if this Viewer is rendered into the
    // swapchain, we don't necessarily (?) want to set the clear color,
    // because that will affect other views.
    // We therefore use the background image as the color;
    _backgroundImage ??= await BackgroundImage.create(this, scene);
    await _backgroundImage!.setBackgroundColor(r, g, b, a);
  }

  ///
  ///
  ///
  @override
  Future setBackgroundImagePosition(
    double x,
    double y, {
    bool clamp = false,
  }) async {
    throw UnimplementedError();
  }

  Future? _skyboxTextureUploadComplete;
  FFITexture? _skyboxTexture;
  Pointer<TSkybox>? _skybox;

  ///
  ///
  ///
  @override
  Future loadSkybox(String skyboxPath) async {
    await removeSkybox();

    var data = await FilamentApp.instance!.loadResource(skyboxPath);

    final completer = Completer();

    _skyboxTextureUploadComplete =
        withVoidCallback((requestId, onTextureUploadComplete) async {
      var bundle = await FFIKtx1Bundle.create(data);

      _skyboxTexture = await bundle.createTexture() as FFITexture;

      _skybox = await withPointerCallback<TSkybox>((cb) {
        Engine_buildSkyboxRenderThread(app.engine, _skyboxTexture!.pointer, cb);
      });
      Scene_setSkybox(scene.scene, _skybox!);
      completer.complete();
    }).then((_) async {
      _skyboxTextureUploadComplete = null;
    });
    await completer.future;
  }

  Future? _iblTextureUploadComplete;

  ///
  ///
  ///
  @override
  Future loadIbl(String lightingPath, {double intensity = 30000}) async {
    await removeIbl();

    final completer = Completer();
    _iblTextureUploadComplete =
        withVoidCallback((requestId, onTextureUploadComplete) async {
      late Pointer stackPtr;
      if (FILAMENT_WASM) {
        //stackPtr = stackSave();
      }

      var data = await FilamentApp.instance!.loadResource(lightingPath);

      final bundle = await FFIKtx1Bundle.create(data);

      final texture = await bundle.createTexture();
      final harmonics = bundle.getSphericalHarmonics();

      final ibl = await FFIIndirectLight.fromIrradianceHarmonics(harmonics,
          reflectionsTexture: texture, intensity: intensity);

      await scene.setIndirectLight(ibl);

      if (FILAMENT_WASM) {
        //stackRestore(stackPtr);
        data.free();
      }
      data.free();

      completer.complete();
    }).then((_) {
      _iblTextureUploadComplete = null;
    });
    await completer.future;
  }

  ///
  ///
  ///
  @override
  Future rotateIbl(Matrix3 rotationMatrix) async {
    var ibl = await scene.getIndirectLight();
    if (ibl != null) {
      await ibl.rotate(rotationMatrix);
    }
  }

  ///
  ///
  ///
  @override
  Future removeSkybox() async {
    if (_disposed) {
      throw ViewerDisposedException();
    }

    if (_skyboxTextureUploadComplete != null) {
      await _skyboxTextureUploadComplete;
      _skyboxTextureUploadComplete = null;
    }

    if (_skybox != null) {
      await withVoidCallback(
        (requestId, cb) => Engine_destroySkyboxRenderThread(
          app.engine,
          _skybox!,
          requestId,
          cb,
        ),
      );
    }
    _skybox = null;
    _skyboxTexture = null;
  }

  ///
  ///
  ///
  @override
  Future removeIbl({bool destroy = true}) async {
    var ibl = await scene.getIndirectLight();
    await scene.setIndirectLight(null);
    if (ibl != null && destroy) {
      await ibl.destroy();
    }
    if (_iblTextureUploadComplete != null) {
      await _iblTextureUploadComplete!;
      _iblTextureUploadComplete = null;
    }
  }

  final _lights = <ThermionEntity>{};

  ///
  ///
  ///
  @override
  Future<ThermionEntity> addDirectLight(DirectLight directLight) async {
    var light = await FilamentApp.instance!.createDirectLight(directLight);

    await scene.addEntity(light);

    _lights.add(light);

    return light;
  }

  ///
  ///
  ///
  @override
  Future removeLight(ThermionEntity entity) async {
    Scene_removeEntity(scene.scene, entity);
    LightManager_destroyLight(app.lightManager, entity);
    _lights.remove(entity);
  }

  ///
  ///
  ///
  @override
  Future destroyLights() async {
    for (final light in _lights.toList()) {
      await removeLight(light);
    }
  }

  final _assets = <FFIAsset>{};
  final _cameras = <FFICamera>{};

  ///
  ///
  ///
  @override
  Future<ThermionAsset> loadGltf(
    String path, {
    bool addToScene = true,
    int numInstances = 1,
    bool keepData = false,
    String? resourceUri,
    bool loadAsync = false,
  }) async {
    final data = await FilamentApp.instance!.loadResource(path);
    if (resourceUri == null) {
      var split = path.split("/");
      resourceUri ??= split.take(split.length - 1).join("/");
    }

    if (!resourceUri.endsWith("/")) {
      resourceUri = "${resourceUri}/";
    }

    return loadGltfFromBuffer(
      data,
      addToScene: addToScene,
      numInstances: numInstances,
      keepData: keepData,
      resourceUri: resourceUri,
      loadResourcesAsync: loadAsync,
    );
  }

  ///
  ///
  ///
  @override
  Future<ThermionAsset> loadGltfFromBuffer(
    Uint8List data, {
    bool addToScene = true,
    int numInstances = 1,
    bool keepData = false,
    int priority = 4,
    int layer = 0,
    bool loadResourcesAsync = false,
    String? resourceUri,
  }) async {
    var asset =
        await FilamentApp.instance!.loadGltfFromBuffer(
              data,
              animationManager,
              numInstances: numInstances,
              keepData: keepData,
              priority: priority,
              layer: layer,
              loadResourcesAsync: loadResourcesAsync,
              resourceUri: resourceUri,
            )
            as FFIAsset;

    _assets.add(asset);
    if (addToScene) {
      await scene.add(asset);
    }

    return asset;
  }

  ///
  ///
  ///
  @override
  Future destroyAsset(covariant FFIAsset asset) async {
    _assets.remove(asset);
    await scene.remove(asset);

    if (asset.boundingBoxAsset != null) {
      await scene.remove(asset.boundingBoxAsset! as FFIAsset);
      await FilamentApp.instance!.destroyAsset(asset.boundingBoxAsset!);
    }
    await FilamentApp.instance!.destroyAsset(asset);
  }

  ///
  ///
  ///
  @override
  Future destroyAssets() async {
    _logger.info("Destroying ${_assets.length} assets");
    for (final asset in _assets) {
      await scene.remove(asset);
      if (asset.boundingBoxAsset != null) {
        await scene.remove(asset.boundingBoxAsset! as FFIAsset);
        await FilamentApp.instance!.destroyAsset(asset.boundingBoxAsset!);
      }
      for (final instance in (await asset.getInstances()).cast<FFIAsset>()) {
        await scene.remove(instance);
      }
      await FilamentApp.instance!.destroyAsset(asset);
      _logger.info("Destroyed asset");
    }
    _assets.clear();
  }

  ///
  ///
  ///
  @override
  Future setToneMapping(ToneMapper mapper) async {
    await view.setToneMapper(mapper);
  }

  ///
  ///
  ///
  @override
  Future setPostProcessing(bool enabled) async {
    View_setPostProcessing(view.view, enabled);
  }

  ///
  ///
  ///
  @override
  Future setShadowsEnabled(bool enabled) async {
    View_setShadowsEnabled(view.view, enabled);
  }

  ///
  ///
  ///
  Future setShadowType(ShadowType shadowType) async {
    View_setShadowType(view.view, shadowType.index);
  }

  ///
  ///
  ///
  Future setSoftShadowOptions(
    double penumbraScale,
    double penumbraRatioScale,
  ) async {
    View_setSoftShadowOptions(view.view, penumbraScale, penumbraRatioScale);
  }

  ///
  ///
  ///
  @override
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa) async {
    if (!FILAMENT_SINGLE_THREADED && IS_WINDOWS && msaa) {
      throw Exception("MSAA is not currently supported on Windows");
    }
    View_setAntiAliasing(view.view, msaa, fxaa, taa);
  }

  ///
  ///
  ///
  @override
  Future setBloom(bool enabled, double strength) async {
    View_setBloom(view.view, enabled, strength);
  }

  ///
  ///
  ///
  @override
  Future setViewFrustumCulling(bool enabled) async {
    await view.setFrustumCullingEnabled(enabled);
  }

  ///
  ///
  ///
  @override
  Future setLightPosition(
    ThermionEntity lightEntity,
    double x,
    double y,
    double z,
  ) async {
    LightManager_setPosition(app.lightManager, lightEntity, x, y, z);
  }

  ///
  ///
  ///
  @override
  Future setLightDirection(
    ThermionEntity lightEntity,
    Vector3 direction,
  ) async {
    direction.normalize();
    LightManager_setPosition(
      app.lightManager,
      lightEntity,
      direction.x,
      direction.y,
      direction.z,
    );
  }

  ///
  ///
  ///
  @override
  Future setPriority(ThermionEntity entity, int priority) async {
    return FilamentApp.instance!.setPriority(entity, priority);
  }

  ///
  ///
  ///
  @override
  Future<v64.Aabb3> getRenderableBoundingBox(ThermionEntity entityId) async {
    final result = RenderableManager_getAabb(app.renderableManager, entityId);
    return v64.Aabb3.centerAndHalfExtents(
      Vector3(result.centerX, result.centerY, result.centerZ),
      Vector3(result.halfExtentX, result.halfExtentY, result.halfExtentZ),
    );
  }

  ///
  ///
  ///
  @override
  Future<v64.Aabb2> getViewportBoundingBox(ThermionEntity entityId) async {
    throw UnimplementedError();
  }

  GridOverlay? _grid;

  ///
  ///
  ///
  Future setGridOverlayVisibility(bool visible) async {
    _grid ??= _grid = await GridOverlay.create(app, animationManager);
    if (visible) {
      await scene.add(_grid!);
      await view.setLayerVisibility(VisibilityLayers.OVERLAY, true);
    } else {
      await scene.remove(_grid!);
      await view.setLayerVisibility(VisibilityLayers.OVERLAY, true);
    }
  }

  ///
  ///
  ///
  Future setLayerVisibility(VisibilityLayers layer, bool visible) async {
    await view.setLayerVisibility(layer, visible);
  }

  ///
  ///
  ///
  Future removeGridOverlay({bool destroy = false}) async {
    if (_grid != null) {
      await scene.remove(_grid!);
      if (destroy) {
        await destroyAsset(_grid!);
        _grid = null;
      }
    }
  }

  ///
  ///
  ///
  Future<Camera> createCamera() async {
    var cameraPtr = await withPointerCallback<TCamera>((cb) {
      Engine_createCameraRenderThread(app.engine, cb);
    });
    var camera = FFICamera(cameraPtr, app);
    final viewport = await view.getViewport();

    await camera.setLensProjection(aspect: viewport.width / viewport.height);
    _cameras.add(camera);
    return camera;
  }

  ///
  ///
  ///
  Future destroyCamera(FFICamera camera) async {
    await camera.destroy();
    _cameras.remove(camera);
  }

  ///
  ///
  ///
  Future setActiveCamera(FFICamera camera) async {
    await view.setCamera(camera);
  }

  ///
  ///
  ///
  Future<Camera> getActiveCamera() async {
    return view.getCamera();
  }

  ///
  ///
  ///
  int getCameraCount() {
    return _cameras.length;
  }

  ///
  ///
  ///
  Iterable<Camera> getCameras() sync* {
    for (final camera in _cameras) {
      yield camera;
    }
  }

  ///
  ///
  ///
  @override
  Future<ThermionAsset> createGeometry(
    Geometry geometry, {
    List<MaterialInstance>? materialInstances,
    bool keepData = false,
    bool addToScene = true,
  }) async {
    final asset = await FilamentApp.instance!.createGeometry(
        geometry, animationManager,
        materialInstances: materialInstances, keepData: keepData) as FFIAsset;
    _assets.add(asset);
    if (addToScene) {
      await scene.add(asset);
    }

    return asset;
  }

  final _gizmos = <GizmoType, GizmoAsset>{};

  ///
  ///
  ///
  @override
  Future<GizmoAsset> getGizmo(GizmoType gizmoType) async {
    if (_gizmos[gizmoType] == null) {
      _gizmos[gizmoType] = await FilamentApp.instance!.createGizmo(
        view,
        animationManager,
        gizmoType,
      );
    }
    return _gizmos[gizmoType]!;
  }

  ///
  ///
  ///
  Future addToScene(covariant FFIAsset asset) async {
    await scene.add(asset);
  }

  ///
  ///
  ///
  Future removeFromScene(covariant FFIAsset asset) async {
    await scene.remove(asset);
  }
}

class ViewerDisposedException implements Exception {}

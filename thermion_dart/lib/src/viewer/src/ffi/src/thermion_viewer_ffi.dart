import 'dart:async';
import 'dart:math' show pi;
import 'package:thermion_dart/src/filament/src/implementation/ffi_indirect_light.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_ktx1_bundle.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_skybox.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import '../../../../filament/src/implementation/grid_overlay.dart';
import 'package:thermion_dart/thermion_dart.dart';
import '../../../../filament/src/implementation/ffi_asset.dart';
import '../../../../filament/src/implementation/ffi_scene.dart';
import '../../../../filament/src/implementation/ffi_filament_app.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
import 'package:logging/logging.dart';

import '../../../../filament/src/implementation/ffi_camera.dart';
import '../../../../filament/src/interface/defaults.dart';

const FILAMENT_ASSET_ERROR = 0;

//
//
//
class ThermionViewerFFI extends ThermionViewer {
  late final _logger = Logger(runtimeType.toString());

  final _initialized = Completer<bool>();
  Future<bool> get initialized => _initialized.future;

  late final View view;
  late final Scene scene;

  final bool _createOverlay;

  final FFIFilamentApp _app;

  @override
  FilamentApp get app => _app;

  //
  ThermionViewerFFI({bool createOverlay = false, required FFIFilamentApp app})
    : _createOverlay = createOverlay,
      _app = app {
    _initialize();
  }

  //
  Future setViewport(int width, int height) async {
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
      await camera.setLensProjection(near: near, far: far, aspect: aspect, focalLength: focalLength);
    }
  }

  Future _initialize() async {
    view = await _app.createView(createScene: true);

    await view.setName("main_view");
    await _app.setClearOptions(0.0, 0.0, 0.0, 0.0);
    scene = await view.getScene();

    await view.setScene(scene);
    final camera = await _app.createCamera();

    _cameras.add(camera);
    await camera.setLensProjection();

    await view.setCamera(camera);

    if (_createOverlay) {
      await view.setHighlightOverlayEnabled(true);
    }

    this._initialized.complete(true);
  }

  bool _rendering = false;

  //
  @override
  bool get rendering => _rendering;

  //
  @override
  Future setRendering(bool render) async {
    await _app.renderManager.setRenderable(view, render);
    _rendering = render;
  }

  //
  Future renderSingleFrame() async {
    final swapChains = await _app.getSwapChains();
    if (swapChains.isEmpty) {
      throw Exception("No swapchain available");
    }
    for (final swapChain in swapChains) {
      await withBoolCallback(
        (cb) => Renderer_beginFrameRenderThread(_app.renderer, swapChain.getNativeHandle(), 0.toBigInt, cb),
      );

      await withVoidCallback(
        (requestId, cb) => Renderer_renderRenderThread(_app.renderer, view.getNativeHandle(), requestId, cb),
      );
      await withVoidCallback((requestId, cb) => Renderer_endFrameRenderThread(_app.renderer, requestId, cb));
      await _app.flush();
    }
  }

  @Deprecated('Use _app.setTargetFramerate(framerate)')
  @override
  Future<void> setFrameRate(int framerate) async {
    _app.setTargetFramerate(framerate);
  }

  final _onDispose = <Future Function()>[];
  bool _disposed = false;
  Future<void>? _disposeFuture;
  Future<void> _sceneResourceOperations = Future<void>.value();

  Future<T> _serializeSceneResourceOperation<T>(Future<T> Function() operation) {
    final previous = _sceneResourceOperations;
    final current = () async {
      await previous;
      return operation();
    }();
    _sceneResourceOperations = current.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return current;
  }

  void _throwIfDisposed() {
    if (_disposed) {
      throw ViewerDisposedException();
    }
  }

  //
  @override
  Future<void> dispose() {
    return _disposeFuture ??= _dispose();
  }

  Future<void> _dispose() async {
    _disposed = true;
    await setRendering(false);

    // Finish any load/remove operation that was accepted before dispose, then
    // detach and destroy every scene-level resource while the scene is valid.
    await _sceneResourceOperations;
    await _removeSkybox(destroy: true);
    await _removeIbl(destroy: true);
    await clearBackgroundImage(destroy: true);

    await destroyAssets();
    await destroyLights();

    for (final callback in _onDispose) {
      await callback.call();
    }

    await view.setHighlightOverlayEnabled(false);
    await view.setCamera(null);
    for (final camera in _cameras.toList()) {
      await camera.destroy();
    }
    _cameras.clear();

    await view.setScene(null);

    await _app.destroyScene(scene as FFIScene);
    await _app.destroyView(view);

    _onDispose.clear();
  }

  //
  void onDispose(Future Function() callback) {
    _onDispose.add(callback);
  }

  TexturedQuad? _backgroundImage;

  //
  @override
  Future clearBackgroundImage({bool destroy = false}) async {
    if (_backgroundImage == null) {
      return;
    }
    if (destroy) {
      await scene.remove(_backgroundImage!);
      await _backgroundImage!.destroy();
      _backgroundImage = null;
    } else {
      _backgroundImage!.hideImage();
    }
  }

  //
  Future<TexturedQuad> getBackgroundImage() async {
    if (_backgroundImage == null) {
      _backgroundImage ??= await _app.createTexturedQuad();
      await scene.add(_backgroundImage!);
    }
    return _backgroundImage!;
  }

  //
  Future setBackgroundImageFromTexture(Texture texture) async {
    var backgroundImage = await getBackgroundImage();
    await backgroundImage.setImageFromTexture(texture);
  }

  //
  @override
  Future setBackgroundImage(String path, {bool fillHeight = false}) async {
    final imageData = await _app.loadResource(path);
    await getBackgroundImage();

    bool isKtx = path.endsWith(".ktx");
    if (isKtx) {
      final bundle = await FFIKtx1Bundle.create(_app, imageData);
      try {
        await _backgroundImage!.setImageFromKtxBundle(bundle);
        // Ktx1Reader borrows the bundle's blobs until the upload completes.
        await _app.flush();
      } finally {
        await bundle.destroy();
      }
    } else {
      await _backgroundImage!.setImage(imageData);
    }
    return (_backgroundImage!.width!, _backgroundImage!.height!);
  }

  ///
  /// Returns the skybox currently attached to this viewer's scene, or null.
  /// The viewer does not cache the skybox; this always reflects the scene.
  ///
  @override
  Future<Skybox?> getSkybox() {
    return scene.getSkybox();
  }

  @override
  Future<Skybox> setBackgroundColor(double r, double g, double b, double alpha) {
    _throwIfDisposed();
    return _serializeSceneResourceOperation(() async {
      await _removeSkybox(destroy: true);
      final skybox = await _app.createColoredSkybox(r: r, g: g, b: b, a: alpha);
      await scene.setSkybox(skybox);
      return skybox;
    });
  }

  Future<Skybox> _loadSkybox(String skyboxPath) async {
    await _removeSkybox(destroy: true);

    var data = await _app.loadResource(skyboxPath);

    final completer = Completer<void>();
    FFIKtx1Bundle? bundle;
    late FFISkybox skybox;

    final uploadFuture = withVoidCallback((requestId, onTextureUploadComplete) async {
      bundle = await FFIKtx1Bundle.create(_app, data) as FFIKtx1Bundle;

      _skyboxTexture =
          await bundle!.createTexture(
                onTextureUploadComplete: onTextureUploadComplete,
                textureUploadCompleteRequestId: requestId,
              )
              as FFITexture;

      skybox = await _app.buildSkybox(texture: _skyboxTexture) as FFISkybox;

      await scene.setSkybox(skybox);

      completer.complete();
    });

    late final Future<void> trackedUploadFuture;
    trackedUploadFuture = uploadFuture.whenComplete(() async {
      await bundle?.destroy();
      if (identical(_skyboxTextureUploadComplete, trackedUploadFuture)) {
        _skyboxTextureUploadComplete = null;
      }
    });
    _skyboxTextureUploadComplete = trackedUploadFuture;
    await completer.future;
    return skybox;
  }

  //
  @override
  Future<Skybox> loadSkybox(String skyboxPath) {
    _throwIfDisposed();
    return _serializeSceneResourceOperation(() => _loadSkybox(skyboxPath));
  }

  Future<void> _loadIbl(String lightingPath, {double intensity = 30000, bool destroyExisting = true}) async {
    await _removeIbl(destroy: destroyExisting);

    final completer = Completer<void>();
    FFIKtx1Bundle? bundle;
    final uploadFuture = withVoidCallback((requestId, onTextureUploadComplete) async {
      var data = await _app.loadResource(lightingPath);

      bundle = await FFIKtx1Bundle.create(_app, data) as FFIKtx1Bundle;

      final texture = await bundle!.createTexture(
        onTextureUploadComplete: onTextureUploadComplete,
        textureUploadCompleteRequestId: requestId,
      );
      final harmonics = bundle!.getSphericalHarmonics();

      final ibl = await FFIIndirectLight.fromIrradianceHarmonics(
        _app,
        harmonics,
        reflectionsTexture: texture,
        intensity: intensity,
      );

      await scene.setIndirectLight(ibl);

      if (FILAMENT_WASM) {
        data.free();
      }

      completer.complete();
      _logger.info("IBL texture ready");
    });

    late final Future<void> trackedUploadFuture;
    trackedUploadFuture = uploadFuture.whenComplete(() async {
      await bundle?.destroy();
      if (identical(_iblTextureUploadComplete, trackedUploadFuture)) {
        _iblTextureUploadComplete = null;
      }
      _logger.info("IBL texture upload complete");
    });
    _iblTextureUploadComplete = trackedUploadFuture;
    await completer.future;
  }

  Future<void> _loadIblFromTexture(
    Texture texture, {
    Texture? reflectionsTexture,
    double intensity = 30000,
    bool destroyExisting = true,
  }) async {
    await _removeIbl(destroy: destroyExisting);

    final ibl = await FFIIndirectLight.fromIrradianceTexture(
      _app,
      texture,
      reflectionsTexture: reflectionsTexture,
      intensity: intensity,
    );

    await scene.setIndirectLight(ibl);
  }

  Future<Skybox?> _removeSkybox({bool destroy = false}) async {
    final upload = _skyboxTextureUploadComplete;
    if (upload != null) {
      await _app.flush();
      await upload;
    }

    final skybox = await scene.getSkybox();
    await scene.setSkybox(null);

    final texture = _skyboxTexture;
    _skyboxTexture = null;

    if (destroy) {
      await skybox?.destroy();
      if (skybox != null && texture != null) {
        // Engine::destroy queues the skybox destruction. Ensure the skybox has
        // released its environment texture before destroying that texture.
        await _app.flush();
      }
      await texture?.destroy();
    }

    return skybox;
  }

  //
  @override
  Future setBackgroundImagePosition(double x, double y, {bool clamp = false}) async {
    throw UnimplementedError();
  }

  Future? _skyboxTextureUploadComplete;
  FFITexture? _skyboxTexture;

  Future? _iblTextureUploadComplete;

  //
  @override
  Future loadIbl(String lightingPath, {double intensity = 30000, bool destroyExisting = true}) {
    _throwIfDisposed();
    return _serializeSceneResourceOperation(
      () => _loadIbl(lightingPath, intensity: intensity, destroyExisting: destroyExisting),
    );
  }

  //
  Future loadIblFromTexture(
    Texture texture, {
    Texture? reflectionsTexture,
    double intensity = 30000,
    bool destroyExisting = true,
  }) {
    _throwIfDisposed();
    return _serializeSceneResourceOperation(
      () => _loadIblFromTexture(
        texture,
        reflectionsTexture: reflectionsTexture,
        intensity: intensity,
        destroyExisting: destroyExisting,
      ),
    );
  }

  //
  @override
  Future rotateIbl(Matrix3 rotationMatrix) async {
    var ibl = await scene.getIndirectLight();
    if (ibl != null) {
      await ibl.rotate(rotationMatrix);
    }
  }

  //
  @override
  Future<Skybox?> removeSkybox() {
    _throwIfDisposed();
    return _serializeSceneResourceOperation(_removeSkybox);
  }

  Future<void> _removeIbl({bool destroy = true}) async {
    final upload = _iblTextureUploadComplete;
    if (upload != null) {
      await _app.flush();
      await upload;
    }

    var ibl = await scene.getIndirectLight();
    await scene.setIndirectLight(null);
    if (ibl != null && destroy) {
      await ibl.destroy();
    }
  }

  //
  @override
  Future removeIbl({bool destroy = true}) {
    _throwIfDisposed();
    return _serializeSceneResourceOperation(() => _removeIbl(destroy: destroy));
  }

  final _lights = <ThermionEntity>{};

  //
  @override
  Future<ThermionEntity> addDirectLight(DirectLight directLight) async {
    var light = await _app.createDirectLight(directLight);

    await scene.addEntity(light);

    _lights.add(light);

    return light;
  }

  //
  @override
  Future removeLight(ThermionEntity entity) async {
    await scene.removeEntity(entity);
    _app.lightManager.destroyLight(entity);
    _lights.remove(entity);
  }

  //
  @override
  Future destroyLights() async {
    for (final light in _lights.toList()) {
      await removeLight(light);
    }
  }

  final _assets = <ThermionAsset>{};
  final _cameras = <Camera>{};

  //
  @override
  Future<ThermionAsset> loadGltf(
    String path, {
    bool addToScene = true,
    int initialInstances = 1,
    bool releaseSourceData = false,
    Set<SceneAssetGeometryCapability> requiredGeometryCapabilities = const {},
    String? resourceUri,
    bool loadAsync = false,
  }) async {
    final data = await _app.loadResource(path);
    if (resourceUri == null) {
      var normalised = path.replaceAll("\\", "/");
      var split = normalised.split("/");
      resourceUri ??= split.take(split.length - 1).join("/");
    }

    if (!resourceUri.endsWith("/")) {
      resourceUri = "${resourceUri}/";
    }

    return loadGltfFromBuffer(
      data,
      addToScene: addToScene,
      initialInstances: initialInstances,
      releaseSourceData: releaseSourceData,
      requiredGeometryCapabilities: requiredGeometryCapabilities,
      resourceUri: resourceUri,
      loadResourcesAsync: loadAsync,
    );
  }

  //
  @override
  Future<ThermionAsset> loadGltfFromBuffer(
    Uint8List data, {
    bool addToScene = true,
    int initialInstances = 1,
    bool releaseSourceData = false,
    Set<SceneAssetGeometryCapability> requiredGeometryCapabilities = const {},
    bool loadResourcesAsync = false,
    String? resourceUri,
  }) async {
    var asset = await _app.loadGltfFromBuffer(
      data,
      initialInstances: initialInstances,
      releaseSourceData: releaseSourceData,
      requiredGeometryCapabilities: requiredGeometryCapabilities,
      loadResourcesAsync: loadResourcesAsync,
      resourceUri: resourceUri,
    );

    _assets.add(asset);
    if (addToScene) {
      await scene.add(asset);
    }

    return asset;
  }

  //
  @override
  Future destroyAsset(ThermionAsset asset) async {
    _assets.remove(asset);
    await scene.remove(asset);
    await view.removeStencilHighlight(asset);

    await hideBoundingBox(asset, destroy: true);

    await _app.destroyAsset(asset as FFIAsset);
  }

  //
  @override
  Future destroyAssets() async {
    _logger.info("Destroying ${_assets.length} assets");
    for (final asset in _assets) {
      _logger.info("Destroying asset ${asset.getNativeHandle()}");
      await scene.remove(asset);
      await hideBoundingBox(asset, destroy: true);

      for (final instance in (await asset.getInstances())) {
        await scene.remove(instance);
        await hideBoundingBox(instance, destroy: true);
      }
      await _app.destroyAsset(asset as FFIAsset);
      _logger.info("Destroyed asset");
    }
    _assets.clear();
  }

  //
  @override
  Future setPostProcessing(bool enabled) async {
    await view.setPostProcessing(enabled);
  }

  //
  @override
  Future setShadowsEnabled(bool enabled) async {
    await view.setShadowsEnabled(enabled);
  }

  //
  Future setShadowType(ShadowType shadowType) async {
    await view.setShadowType(shadowType);
  }

  //
  @override
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa) async {
    if (!FILAMENT_SINGLE_THREADED && IS_WINDOWS && msaa) {
      throw Exception("MSAA is not currently supported on Windows");
    }
    View_setAntiAliasing(view.getNativeHandle(), msaa, fxaa, taa);
  }

  //
  @override
  Future setBloom(bool enabled, double strength) async {
    View_setBloom(view.getNativeHandle(), enabled, strength);
  }

  //
  @override
  Future setViewFrustumCulling(bool enabled) async {
    await view.setFrustumCullingEnabled(enabled);
  }

  //
  @override
  Future setLightPosition(ThermionEntity lightEntity, double x, double y, double z) async {
    _app.lightManager.setPosition(lightEntity, x, y, z);
  }

  //
  @override
  Future setLightDirection(ThermionEntity lightEntity, Vector3 direction) async {
    direction.normalize();
    _app.lightManager.setDirection(lightEntity, direction.x, direction.y, direction.z);
  }

  //
  @override
  Future setPriority(ThermionEntity entity, int priority) async {
    return _app.setPriority(entity, priority);
  }

  //
  @override
  @Deprecated("Call _app.renderableManager.getBoundingBox instead")
  Future<v64.Aabb3> getRenderableBoundingBox(ThermionEntity entityId) async {
    return _app.renderableManager.getBoundingBox(entityId);
  }

  //
  @override
  Future<v64.Aabb2> getViewportBoundingBox(ThermionEntity entityId) async {
    throw UnimplementedError();
  }

  GridOverlay? _grid;

  //
  Future setGridOverlayVisibility(
    bool visible, {
    List<LinearColor> axisColors = kDefaultAxisColors,
    LinearColor gridColor = kDefaultGridColor,
    List<double> spacing = const [1.0, 10.0, 100.0],
    List<double> fadeInStart = const [0.001, 5.0, 50.0],
    List<double> fadeInEnd = const [0.001, 50.0, 500.0],
    List<double> fadeOutStart = const [10.0, 500.0, 5000.0],
    List<double> fadeOutEnd = const [200.0, 2000.0, 20000.0],
  }) async {
    _grid ??= await GridOverlay.create(
      _app,
      axisColors: axisColors,
      gridColor: gridColor,
      spacing: spacing,
      fadeInStart: fadeInStart,
      fadeInEnd: fadeInEnd,
      fadeOutStart: fadeOutStart,
      fadeOutEnd: fadeOutEnd,
    );

    await _grid!.setAxisColor(axisColors);

    if (visible) {
      await _grid!.addToScene(scene);
      await view.setLayerVisibility(VisibilityLayers.OVERLAY, true);
    } else {
      await _grid!.removeFromScene(scene);
      await view.setLayerVisibility(VisibilityLayers.OVERLAY, true);
    }
  }

  //
  Future setLayerVisibility(VisibilityLayers layer, bool visible) async {
    await view.setLayerVisibility(layer, visible);
  }

  //
  Future removeGridOverlay({bool destroy = false}) async {
    if (_grid != null) {
      await _grid!.removeFromScene(scene);
      if (destroy) {
        await _grid!.destroy();
        _grid = null;
      }
    }
  }

  ThermionAsset? _translationAxisAsset;
  MaterialInstance? _translationAxisMaterial;

  @override
  Future setTranslationAxisVisibility(
    bool visible, {
    ThermionEntity? entity,
    v64.Vector3? origin,
    Axis? axis,
    double lineWidth = 5.0,
    double lineLength = 500.0,
  }) async {
    if (visible) {
      if (axis == null) {
        throw ArgumentError('axis is required when visible is true');
      }
      if (entity == null && origin == null) {
        throw ArgumentError('either entity or origin must be provided when visible is true');
      }

      // Get world position from entity if provided
      v64.Vector3 worldPosition;
      if (origin != null) {
        worldPosition = origin;
      } else {
        final worldTransform = await _app.getWorldTransform(entity!);
        worldPosition = worldTransform.getTranslation();
        await _app.setPriority(entity, 0);
      }

      // Remove existing if any
      await _removeTranslationAxis();

      // Create material
      final axisInt = switch (axis) {
        Axis.X => 0,
        Axis.Y => 1,
        Axis.Z => 2,
      };

      // Material origin should be (0,0,0) in object space since we position via
      // transform
      _translationAxisMaterial = await TranslationAxisMaterial.createMaterialInstance(
        app: _app,
        originX: 0.0,
        originY: 0.0,
        originZ: 0.0,
        axis: axisInt,
        lineWidth: lineWidth,
        lineLength: lineLength,
      );

      // Create plane geometry (without material first, then apply)
      _translationAxisAsset = await createGeometry(GeometryUtils.plane(width: lineLength * 2, height: lineLength * 2));
      await _translationAxisAsset!.setMaterialInstanceAt(_translationAxisMaterial!);

      // Position at world position, with rotation for Y axis
      v64.Matrix4 transform;
      if (axis == Axis.Y) {
        // Rotate plane 90° around X axis to make it vertical (XY plane)
        final rotation = v64.Quaternion.axisAngle(v64.Vector3(1, 0, 0), pi / 2);
        transform = v64.Matrix4.compose(worldPosition, rotation, v64.Vector3.all(1.0));
      } else {
        transform = v64.Matrix4.translation(worldPosition);
      }
      await _app.setTransform(_translationAxisAsset!.entity, transform);
    } else {
      await _removeTranslationAxis();
    }
  }

  Future _removeTranslationAxis() async {
    if (_translationAxisAsset != null) {
      _assets.remove(_translationAxisAsset!);
      await scene.remove(_translationAxisAsset!);
      await _app.destroyAsset(_translationAxisAsset! as FFIAsset);
      _translationAxisAsset = null;
    }
    _translationAxisMaterial = null;
  }

  //
  Future<Camera> createCamera() async {
    var camera = await _app.createCamera();

    final viewport = await view.getViewport();
    var aspect = viewport.width / viewport.height;
    if (viewport.width == 0 || viewport.height == 0) {
      aspect = 1.0;
    }
    await camera.setLensProjection(aspect: aspect);
    _cameras.add(camera as FFICamera);
    return camera;
  }

  //
  Future destroyCamera(FFICamera camera) async {
    await camera.destroy();
    _cameras.remove(camera);
  }

  //
  Future setActiveCamera(FFICamera camera) async {
    await view.setCamera(camera);
  }

  //
  Future<Camera> getActiveCamera() async {
    return view.getCamera();
  }

  //
  int getCameraCount() {
    return _cameras.length;
  }

  //
  Iterable<Camera> getCameras() sync* {
    for (final camera in _cameras) {
      yield camera;
    }
  }

  //
  @override
  Future<ThermionAsset> createGeometry(
    Geometry geometry, {
    List<MaterialInstance>? materialInstances,
    bool addToScene = true,
  }) async {
    final asset = await _app.createGeometry(geometry, materialInstances: materialInstances);
    _assets.add(asset);
    if (addToScene) {
      await scene.add(asset);
    }

    return asset;
  }

  final _gizmos = <GizmoType, GizmoAsset>{};

  //
  @override
  Future<GizmoAsset> getGizmo(GizmoType gizmoType) async {
    if (_gizmos[gizmoType] == null) {
      _gizmos[gizmoType] = await _app.createGizmo(view, gizmoType);
    }
    return _gizmos[gizmoType]!;
  }

  //
  Future addToScene(ThermionAsset asset) async {
    await scene.add(asset);
  }

  //
  Future removeFromScene(ThermionAsset asset) async {
    await scene.remove(asset);
    await view.removeStencilHighlight(asset);
  }

  final _boundingBoxAssets = <ThermionAsset, Completer<ThermionAsset>>{};

  //
  Future showBoundingBox(ThermionAsset asset) async {
    if (_boundingBoxAssets.containsKey(asset)) {
      final bbAsset = await _boundingBoxAssets[asset]!.future;
      await scene.add(bbAsset);
      return;
    }

    var completer = Completer<ThermionAsset>();
    _boundingBoxAssets[asset] = completer;

    final boundingBox = await asset.getBoundingBox();

    // Aabb3.min/max are absolute object-space corners, not offsets from
    // center. The wireframe asset is parented to `asset` below, so these
    // values are already in the right frame.
    final min = [boundingBox.min.x, boundingBox.min.y, boundingBox.min.z];
    final max = [boundingBox.max.x, boundingBox.max.y, boundingBox.max.z];

    // Create vertices for the bounding box wireframe
    // 8 vertices for a cube
    final vertices = Float32List(8 * 3);

    // Bottom vertices
    vertices[0] = min[0];
    vertices[1] = min[1];
    vertices[2] = min[2]; // v0
    vertices[3] = max[0];
    vertices[4] = min[1];
    vertices[5] = min[2]; // v1
    vertices[6] = max[0];
    vertices[7] = min[1];
    vertices[8] = max[2]; // v2
    vertices[9] = min[0];
    vertices[10] = min[1];
    vertices[11] = max[2]; // v3

    // Top vertices
    vertices[12] = min[0];
    vertices[13] = max[1];
    vertices[14] = min[2]; // v4
    vertices[15] = max[0];
    vertices[16] = max[1];
    vertices[17] = min[2]; // v5
    vertices[18] = max[0];
    vertices[19] = max[1];
    vertices[20] = max[2]; // v6
    vertices[21] = min[0];
    vertices[22] = max[1];
    vertices[23] = max[2]; // v7

    // Indices for lines (24 indices for 12 lines)
    final indices = Uint16List.fromList([
      // Bottom face
      0, 1, 1, 2, 2, 3, 3, 0,
      // Top face
      4, 5, 5, 6, 6, 7, 7, 4,
      // Vertical edges
      0, 4, 1, 5, 2, 6, 3, 7,
    ]);

    // Create unlit material instance for the wireframe
    final materialInstancePtr = await withPointerCallback<TMaterialInstance>((cb) {
      MaterialProvider_createMaterialInstanceRenderThread(
        _app.ubershaderMaterialProvider,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        0,
        false,
        false,
        0,
        false,
        0,
        0,
        false,
        0,
        false,
        0,
        false,
        0,
        false,
        false,
        false,
        0,
        0,
        0,
        false,
        0,
        false,
        0,
        false,
        0,
        false,
        0,
        false,
        false,
        false,
        cb,
      );
    });

    final material = FFIMaterialInstance(materialInstancePtr, _app);
    await material.setParameterFloat4("baseColorFactor", 1.0, 1.0, 0.0, 1.0); // Yellow wireframe

    // Create geometry for the bounding box
    final geometry = Geometry(vertices, indices, primitiveType: PrimitiveType.LINES);

    final bbAsset = await _app.createGeometry(geometry, materialInstances: [material]);

    await bbAsset.setCastShadows(false);
    await bbAsset.setReceiveShadows(false);

    TransformManager_setParent(Engine_getTransformManager(_app.engine), bbAsset.entity, asset.entity, false);
    geometry.dispose();

    completer.complete(bbAsset);

    await scene.add(bbAsset);

    return bbAsset;
  }

  Future hideBoundingBox(ThermionAsset asset, {bool destroy = false}) async {
    if (_boundingBoxAssets.containsKey(asset)) {
      final completer = _boundingBoxAssets[asset]!;
      final bbAsset = await completer.future;

      await scene.remove(bbAsset);
      if (destroy) {
        _boundingBoxAssets.remove(asset);
        await _app.destroyAsset(bbAsset as FFIAsset);
        _logger.info("Bounding box destroyed");
      } else {
        _logger.info("Bounding box hidden");
      }
    } else {
      _logger.warning("Warning - no bounding box for asset created");
    }
  }
}

class ViewerDisposedException implements Exception {}

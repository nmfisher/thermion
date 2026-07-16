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

  //
  ThermionViewerFFI({bool createOverlay = false})
    : _createOverlay = createOverlay {
    if (FilamentApp.instance == null) {
      throw Exception("FilamentApp has not been created");
    }
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
      await camera.setLensProjection(
        near: near,
        far: far,
        aspect: aspect,
        focalLength: focalLength,
      );
    }
  }

  Future _initialize() async {
    view = await FilamentApp.instance!.createView(createScene: true);

    await view.setName("main_view");
    await FilamentApp.instance!.setClearOptions(0.0, 0.0, 0.0, 0.0);
    scene = await view.getScene();

    await view.setScene(scene);
    final camera = await FilamentApp.instance!.createCamera();

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
    _rendering = render;
    final rm = FilamentApp.instance!.renderManager;

    final swapChains = await FilamentApp.instance!.getSwapChains();

    if (render) {
      await rm.attach(view, swapChains.first);
    } else {
      await rm.detach(view);
    }
  }

  //
  Future renderSingleFrame() async {
    final swapChains = await FilamentApp.instance!.getSwapChains();
    if (swapChains.isEmpty) {
      throw Exception("No swapchain available");
    }
    for (final swapChain in swapChains) {
      await withBoolCallback(
        (cb) => Renderer_beginFrameRenderThread(
          FilamentApp.instance!.renderer,
          swapChain.getNativeHandle(),
          0.toBigInt,
          cb,
        ),
      );

      await withVoidCallback(
        (requestId, cb) => Renderer_renderRenderThread(
          FilamentApp.instance!.renderer,
          view.getNativeHandle(),
          requestId,
          cb,
        ),
      );
      await withVoidCallback(
        (requestId, cb) => Renderer_endFrameRenderThread(
          FilamentApp.instance!.renderer,
          requestId,
          cb,
        ),
      );
      await FilamentApp.instance!.flush();
    }
  }

  @Deprecated('Use FilamentApp.instance!.setTargetFramerate(framerate)')
  @override
  Future<void> setFrameRate(int framerate) async {
    FilamentApp.instance?.setTargetFramerate(framerate);
  }

  final _onDispose = <Future Function()>[];
  bool _disposed = false;

  //
  @override
  Future dispose() async {
    _disposed = true;
    await setRendering(false);

    await clearBackgroundImage(destroy: true);

    await destroyAssets();
    await destroyLights();

    for (final callback in _onDispose) {
      await callback.call();
    }
    View_setScene(view.getNativeHandle(), nullptr);

    await FilamentApp.instance!.destroyScene(scene);
    await FilamentApp.instance!.destroyView(view);

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
      _backgroundImage ??= await FilamentApp.instance!.createTexturedQuad();
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
    final imageData = await FilamentApp.instance!.loadResource(path);
    await getBackgroundImage();

    bool isKtx = path.endsWith(".ktx");
    if (isKtx) {
      final bundle = await FFIKtx1Bundle.create(imageData);
      await _backgroundImage!.setImageFromKtxBundle(bundle);
    } else {
      await _backgroundImage!.setImage(imageData);
    }
    return (_backgroundImage!.width!, _backgroundImage!.height!);
  }

  //
  @override
  Future setBackgroundColor(double r, double g, double b, double a) async {
    await removeSkybox();
    _skybox = await FilamentApp.instance!.buildSkybox() as FFISkybox;
    await scene.setSkybox(_skybox!);
    await _skybox!.setColor(r, g, b, a);
  }

  //
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
  FFISkybox? _skybox;

  //
  @override
  Future loadSkybox(String skyboxPath) async {
    await removeSkybox();

    var data = await FilamentApp.instance!.loadResource(skyboxPath);

    final completer = Completer();

    _skyboxTextureUploadComplete =
        withVoidCallback((requestId, onTextureUploadComplete) async {
          var bundle = await FFIKtx1Bundle.create(data);

          _skyboxTexture =
              await bundle.createTexture(
                    onTextureUploadComplete: onTextureUploadComplete,
                    textureUploadCompleteRequestId: requestId,
                  )
                  as FFITexture;

          _skybox =
              await FilamentApp.instance!.buildSkybox(texture: _skyboxTexture)
                  as FFISkybox;

          await scene.setSkybox(_skybox!);

          completer.complete();
        }).then((_) async {
          _skyboxTextureUploadComplete = null;
        });
    await completer.future;
  }

  Future? _iblTextureUploadComplete;

  //
  @override
  Future loadIbl(
    String lightingPath, {
    double intensity = 30000,
    bool destroyExisting = true,
  }) async {
    await removeIbl(destroy: destroyExisting);

    final completer = Completer();
    _iblTextureUploadComplete =
        withVoidCallback((requestId, onTextureUploadComplete) async {
              late Pointer stackPtr;
              if (FILAMENT_WASM) {
                //stackPtr = stackSave();
              }

              var data = await FilamentApp.instance!.loadResource(lightingPath);

              final bundle = await FFIKtx1Bundle.create(data);

              final texture = await bundle.createTexture(
                onTextureUploadComplete: onTextureUploadComplete,
                textureUploadCompleteRequestId: requestId,
              );
              final harmonics = bundle.getSphericalHarmonics();

              final ibl = await FFIIndirectLight.fromIrradianceHarmonics(
                harmonics,
                reflectionsTexture: texture,
                intensity: intensity,
              );

              await scene.setIndirectLight(ibl);

              if (FILAMENT_WASM) {
                //stackRestore(stackPtr);
                data.free();
              }
              data.free();

              completer.complete();
              _logger.info("IBL texture upload complete");
            })
            .then((_) {
              _logger.info("IBL texture upload complete");
              _iblTextureUploadComplete = null;
            })
            .onError((err, st) {
              _logger.severe(err.toString());
            });
    await completer.future;
  }

  //
  Future loadIblFromTexture(
    Texture texture, {
    Texture? reflectionsTexture = null,
    double intensity = 30000,
    bool destroyExisting = true,
  }) async {
    await removeIbl(destroy: destroyExisting);

    final ibl = await FFIIndirectLight.fromIrradianceTexture(
      texture,
      reflectionsTexture: reflectionsTexture,
      intensity: intensity,
    );

    await scene.setIndirectLight(ibl);
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
  Future removeSkybox() async {
    if (_disposed) {
      throw ViewerDisposedException();
    }

    if (_skyboxTextureUploadComplete != null) {
      await FilamentApp.instance!.flush();
      await _skyboxTextureUploadComplete;
      _skyboxTextureUploadComplete = null;
    }

    await _skybox?.destroy();
    _skybox = null;
    _skyboxTexture = null;
  }

  //
  @override
  Future removeIbl({bool destroy = true}) async {
    var ibl = await scene.getIndirectLight();
    await scene.setIndirectLight(null);
    if (ibl != null && destroy) {
      await ibl.destroy();
    }
    if (_iblTextureUploadComplete != null) {
      await FilamentApp.instance!.flush();
      await _iblTextureUploadComplete!;
      _iblTextureUploadComplete = null;
    }
  }

  final _lights = <ThermionEntity>{};

  //
  @override
  Future<ThermionEntity> addDirectLight(DirectLight directLight) async {
    var light = await FilamentApp.instance!.createDirectLight(directLight);

    await scene.addEntity(light);

    _lights.add(light);

    return light;
  }

  //
  @override
  Future removeLight(ThermionEntity entity) async {
    await scene.removeEntity(entity);
    FilamentApp.instance!.lightManager.destroyLight(entity);
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
    bool rebuildVertices = false,
    String? resourceUri,
    bool loadAsync = false,
  }) async {
    final data = await FilamentApp.instance!.loadResource(path);
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
      rebuildVertices: rebuildVertices,
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
    bool rebuildVertices = false,
    bool loadResourcesAsync = false,
    String? resourceUri,
  }) async {
    var asset = await FilamentApp.instance!.loadGltfFromBuffer(
      data,
      initialInstances: initialInstances,
      releaseSourceData: releaseSourceData,
      rebuildVertices: rebuildVertices,
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

    await FilamentApp.instance!.destroyAsset(asset);
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
      await FilamentApp.instance!.destroyAsset(asset);
      _logger.info("Destroyed asset");
    }
    _assets.clear();
  }

  //
  @override
  Future setToneMapper(ToneMapper mapper) async {
    await view.setToneMapper(mapper);
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
  Future setLightPosition(
    ThermionEntity lightEntity,
    double x,
    double y,
    double z,
  ) async {
    FilamentApp.instance!.lightManager.setPosition(lightEntity, x, y, z);
  }

  //
  @override
  Future setLightDirection(
    ThermionEntity lightEntity,
    Vector3 direction,
  ) async {
    direction.normalize();
    FilamentApp.instance!.lightManager.setDirection(
      lightEntity,
      direction.x,
      direction.y,
      direction.z,
    );
  }

  //
  @override
  Future setPriority(ThermionEntity entity, int priority) async {
    return FilamentApp.instance!.setPriority(entity, priority);
  }

  //
  @override
  @Deprecated(
    "Call FilamentApp.instance!.renderableManager.getBoundingBox instead",
  )
  Future<v64.Aabb3> getRenderableBoundingBox(ThermionEntity entityId) async {
    return FilamentApp.instance!.renderableManager.getBoundingBox(entityId);
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
        throw ArgumentError(
          'either entity or origin must be provided when visible is true',
        );
      }

      // Get world position from entity if provided
      v64.Vector3 worldPosition;
      if (origin != null) {
        worldPosition = origin;
      } else {
        final worldTransform = await FilamentApp.instance!.getWorldTransform(
          entity!,
        );
        worldPosition = worldTransform.getTranslation();
        await FilamentApp.instance!.setPriority(entity, 0);
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
      _translationAxisMaterial =
          await TranslationAxisMaterial.createMaterialInstance(
            originX: 0.0,
            originY: 0.0,
            originZ: 0.0,
            axis: axisInt,
            lineWidth: lineWidth,
            lineLength: lineLength,
          );

      // Create plane geometry (without material first, then apply)
      _translationAxisAsset = await createGeometry(
        GeometryUtils.plane(width: lineLength * 2, height: lineLength * 2),
      );
      await _translationAxisAsset!.setMaterialInstanceAt(
        _translationAxisMaterial!,
      );

      // Position at world position, with rotation for Y axis
      v64.Matrix4 transform;
      if (axis == Axis.Y) {
        // Rotate plane 90° around X axis to make it vertical (XY plane)
        final rotation = v64.Quaternion.axisAngle(v64.Vector3(1, 0, 0), pi / 2);
        transform = v64.Matrix4.compose(
          worldPosition,
          rotation,
          v64.Vector3.all(1.0),
        );
      } else {
        transform = v64.Matrix4.translation(worldPosition);
      }
      await FilamentApp.instance!.setTransform(
        _translationAxisAsset!.entity,
        transform,
      );
    } else {
      await _removeTranslationAxis();
    }
  }

  Future _removeTranslationAxis() async {
    if (_translationAxisAsset != null) {
      _assets.remove(_translationAxisAsset!);
      await scene.remove(_translationAxisAsset!);
      await FilamentApp.instance!.destroyAsset(_translationAxisAsset!);
      _translationAxisAsset = null;
    }
    _translationAxisMaterial = null;
  }

  //
  Future<Camera> createCamera() async {
    var camera = await FilamentApp.instance!.createCamera();

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
    bool releaseSourceData = false,
    bool addToScene = true,
  }) async {
    final asset = await FilamentApp.instance!.createGeometry(
      geometry,
      materialInstances: materialInstances,
      releaseSourceData: releaseSourceData,
    );
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
      _gizmos[gizmoType] = await FilamentApp.instance!.createGizmo(
        view,
        gizmoType,
      );
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
    final materialInstancePtr = await withPointerCallback<TMaterialInstance>((
      cb,
    ) {
      MaterialProvider_createMaterialInstanceRenderThread(
        FilamentApp.instance!.ubershaderMaterialProvider,
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

    final material = FFIMaterialInstance(materialInstancePtr);
    await material.setParameterFloat4(
      "baseColorFactor",
      1.0,
      1.0,
      0.0,
      1.0,
    ); // Yellow wireframe

    // Create geometry for the bounding box
    final geometry = Geometry(
      vertices,
      indices,
      primitiveType: PrimitiveType.LINES,
    );

    final bbAsset = await FilamentApp.instance!.createGeometry(
      geometry,
      materialInstances: [material],
      releaseSourceData: false,
    );

    await bbAsset.setCastShadows(false);
    await bbAsset.setReceiveShadows(false);

    TransformManager_setParent(
      Engine_getTransformManager(FilamentApp.instance!.engine),
      bbAsset.entity,
      asset.entity,
      false,
    );
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
        await FilamentApp.instance!.destroyAsset(bbAsset);
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

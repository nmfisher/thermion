import 'dart:async';
import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_index_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/highlight_overlay_manager.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_color_grading.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

import 'ffi_camera.dart';

class FFIView extends View<Pointer<TView>> {
  late final _logger = Logger(this.runtimeType.toString());

  final Pointer<TView> view;
  final FFIFilamentApp _app;

  Pointer<TView> getNativeHandle() => view;

  RenderTarget? renderTarget;

  late CallbackHolder<PickCallbackFunction> _onPickResultHolder;

  FFIView(this.view, this._app) {
    final renderTargetPtr = View_getRenderTarget(view);
    if (renderTargetPtr != nullptr) {
      renderTarget = FFIRenderTarget(renderTargetPtr, _app);
    }

    _onPickResultHolder = _onPickResult.asCallback();
  }

  Future destroy() async {
    _onPickResultHolder.dispose();
    await withVoidCallback((requestId, cb) => Engine_destroyViewRenderThread(_app.engine, view, requestId, cb));
  }

  @override
  Future setViewport(int width, int height) async {
    await withVoidCallback((requestId, cb) => View_setViewportRenderThread(view, width, height, requestId, cb));

    await _highlightOverlayManager?.setViewport(width, height);
  }

  Future<RenderTarget?> getRenderTarget() async {
    return renderTarget;
  }

  @override
  Future setRenderTarget(RenderTarget? renderTarget) async {
    // When highlight overlay is enabled, the main view renders to an internal
    // render target. Flutter-provided render targets go to EdgeDetectionView.
    if (_highlightOverlayManager != null && renderTarget != null) {
      final isInternalRT = _highlightOverlayManager!.isInternalRenderTarget(renderTarget);
      if (!isInternalRT) {
        // This is a Flutter RT - redirect to EdgeDetectionView
        await _highlightOverlayManager!.setRenderTarget(this, renderTarget as FFIRenderTarget);
        return;
      }
    }

    if (renderTarget != null) {
      await withVoidCallback(
        (requestId, cb) => View_setRenderTargetRenderThread(view, renderTarget.getNativeHandle(), requestId, cb),
      );
      this.renderTarget = renderTarget;
    } else {
      await withVoidCallback((requestId, cb) => View_setRenderTargetRenderThread(view, nullptr, requestId, cb));
      this.renderTarget = null;
    }
  }

  @override
  Future setCamera(Camera? camera) async {
    if (camera == null) {
      await withVoidCallback((requestId, cb) => View_setCameraRenderThread(view, nullptr, requestId, cb));
    } else {
      await withVoidCallback(
        (requestId, cb) => View_setCameraRenderThread(view, camera.getNativeHandle(), requestId, cb),
      );
    }

    // Sync the silhouette view's camera with the main view
    await _highlightOverlayManager?.setCamera(camera);
  }

  @override
  Future<Viewport> getViewport() async {
    final vp = View_getViewport(view);
    return Viewport(vp.left, vp.bottom, vp.width, vp.height);
  }

  @override
  Future<Camera> getCamera() async {
    final cameraPtr = View_getCamera(view);
    return FFICamera(cameraPtr, _app);
  }

  @override
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa) async {
    await withVoidCallback((requestId, cb) => View_setAntiAliasingRenderThread(view, msaa, fxaa, taa, requestId, cb));
  }

  @override
  Future setPostProcessing(bool enabled) async {
    await withVoidCallback((requestId, cb) => View_setPostProcessingRenderThread(view, enabled, requestId, cb));
  }

  @override
  Future setFrustumCullingEnabled(bool enabled) async {
    await withVoidCallback((requestId, cb) => View_setFrustumCullingEnabledRenderThread(view, enabled, requestId, cb));
  }

  @override
  Future setBloom(bool enabled, double strength) async {
    await withVoidCallback((requestId, cb) {
      View_setBloomRenderThread(view, enabled, strength, requestId, cb);
    });
  }

  @override
  Future<ColorGradingBuilder> createColorGradingBuilder() async {
    final builderPtr = await withPointerCallback<TColorGradingBuilder>(
      (cb) => ColorGradingBuilder_createRenderThread(cb),
    );
    if (builderPtr == nullptr) {
      throw Exception('Failed to create ColorGradingBuilder');
    }
    return FFIColorGradingBuilder(builderPtr, _app);
  }

  @override
  Future setColorGrading(ColorGrading? colorGrading) async {
    // Non-owning, like Filament's View::setColorGrading: the caller remains
    // responsible for destroying the grading (after dissociating it from all
    // views) - see [View.setColorGrading].
    await withVoidCallback(
      (requestId, cb) =>
          View_setColorGradingRenderThread(view, colorGrading?.getNativeHandle() ?? nullptr, requestId, cb),
    );
  }

  @override
  Future<ColorGrading?> getColorGrading() async {
    final colorGradingPtr = View_getColorGrading(view);
    if (colorGradingPtr == nullptr) {
      return null;
    }
    return FFIColorGrading(colorGradingPtr, _app);
  }

  Future setStencilBufferEnabled(bool enabled) async {
    await withVoidCallback((requestId, cb) => View_setStencilBufferEnabledRenderThread(view, enabled, requestId, cb));
  }

  Future<bool> isStencilBufferEnabled() async {
    return View_isStencilBufferEnabled(view);
  }

  Future setDithering(bool enabled) async {
    await withVoidCallback((requestId, cb) => View_setDitheringEnabledRenderThread(view, enabled, requestId, cb));
  }

  Future<bool> isDitheringEnabled() async {
    return View_isDitheringEnabled(view);
  }

  @override
  Future setRenderQuality(QualityLevel quality) async {
    await withVoidCallback((requestId, cb) => View_setRenderQualityRenderThread(view, quality.index, requestId, cb));
  }

  Future setScene(Scene? scene) async {
    await withVoidCallback(
      (requestId, cb) => View_setSceneRenderThread(view, scene?.getNativeHandle() ?? nullptr, requestId, cb),
    );
  }

  @override
  Future setLayerVisibility(VisibilityLayers layer, bool visible) async {
    await withVoidCallback(
      (requestId, cb) => View_setLayerEnabledRenderThread(view, layer.value, visible, requestId, cb),
    );
  }

  Future setBlendMode(BlendMode blendMode) async {
    await withVoidCallback((requestId, cb) => View_setBlendModeRenderThread(view, blendMode.index, requestId, cb));
  }

  FFIScene? _scene;

  @override
  Future<Scene> getScene() async {
    if (_scene == null) {
      _scene = FFIScene(View_getScene(view), _app);
    }
    return _scene!;
  }

  int _pickRequestId = -1;

  static int kMaxPickRequests = 1024;
  final _pickRequests = List<({void Function(PickResult) handler, int x, int y})?>.generate(
    kMaxPickRequests,
    (idx) => null,
  );

  ///
  ///
  ///
  @override
  Future pick(int x, int y, void Function(PickResult) resultHandler) async {
    _pickRequestId++;
    var pickRequestId = _pickRequestId;

    _pickRequests[_pickRequestId % kMaxPickRequests] = (handler: resultHandler, x: x, y: y);

    var viewport = await getViewport();
    y = viewport.height - y;
    if (FILAMENT_WASM) {
      View_pickRenderThread(view, pickRequestId, x, y, _onPickResultHolder.pointer);
    } else {
      View_pick(view, pickRequestId, x, y, _onPickResultHolder.pointer);
    }
  }

  void _onPickResult(
    int requestId,
    ThermionEntity entityId,
    double depth,
    double fragX,
    double fragY,
    double fragZ,
  ) async {
    final modRequestId = requestId % kMaxPickRequests;
    if (_pickRequests[modRequestId] == null) {
      _logger.severe(
        """Warning : pick result received with no matching request ID. """
        """This indicates you're clearing the pick cache too quickly""",
      );
      return;
    }
    final (:handler, :x, :y) = _pickRequests[modRequestId]!;
    _pickRequests[modRequestId] = null;

    final viewport = await getViewport();

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

  @override
  Future setFogOptions(FogOptions options) async {
    final tFogOptions = StructAllocator.create<TFogOptions>();

    tFogOptions.distance = options.distance;
    tFogOptions.cutOffDistance = options.cutOffDistance;
    tFogOptions.maximumOpacity = options.maximumOpacity;
    tFogOptions.height = options.height;
    tFogOptions.heightFalloff = options.heightFalloff;
    tFogOptions.density = options.density;
    tFogOptions.inScatteringStart = options.inScatteringStart;
    tFogOptions.inScatteringSize = options.inScatteringSize;
    tFogOptions.fogColorFromIbl = options.fogColorFromIbl;
    tFogOptions.skyColor = (options.skyColor as FFITexture?)?.pointer ?? nullptr;
    tFogOptions.linearColorR = options.linearColor.r;
    tFogOptions.linearColorG = options.linearColor.g;
    tFogOptions.linearColorB = options.linearColor.b;
    tFogOptions.enabled = options.enabled;
    await withVoidCallback((requestId, cb) => View_setFogOptionsRenderThread(this.view, tFogOptions, requestId, cb));
  }

  @override
  FogOptions getFogOptions() {
    final tOptions = View_getFogOptions(view);

    Texture? skyColor;
    if (tOptions.skyColor != nullptr) {
      skyColor = FFITexture(_app.engine, tOptions.skyColor, _app);
    }

    return FogOptions(
      enabled: tOptions.enabled,
      distance: tOptions.distance,
      cutOffDistance: tOptions.cutOffDistance,
      maximumOpacity: tOptions.maximumOpacity,
      height: tOptions.height,
      heightFalloff: tOptions.heightFalloff,
      linearColor: Vector3(tOptions.linearColorR, tOptions.linearColorG, tOptions.linearColorB),
      density: tOptions.density,
      inScatteringStart: tOptions.inScatteringStart,
      inScatteringSize: tOptions.inScatteringSize,
      fogColorFromIbl: tOptions.fogColorFromIbl,
      skyColor: skyColor,
    );
  }

  @override
  Future setAmbientOcclusionOptions(AmbientOcclusionOptions options) async {
    final tAmbientOcclusionOptions = StructAllocator.create<TAmbientOcclusionOptions>();

    tAmbientOcclusionOptions.aoType = options.aoType.index;
    tAmbientOcclusionOptions.radius = options.radius;
    tAmbientOcclusionOptions.power = options.power;
    tAmbientOcclusionOptions.bias = options.bias;
    tAmbientOcclusionOptions.resolution = options.resolution;
    tAmbientOcclusionOptions.intensity = options.intensity;
    tAmbientOcclusionOptions.bilateralThreshold = options.bilateralThreshold;
    tAmbientOcclusionOptions.quality = options.quality.index;
    tAmbientOcclusionOptions.lowPassFilter = options.lowPassFilter.index;
    tAmbientOcclusionOptions.upsampling = options.upsampling.index;
    tAmbientOcclusionOptions.enabled = options.enabled;
    tAmbientOcclusionOptions.bentNormals = options.bentNormals;
    tAmbientOcclusionOptions.minHorizonAngleRad = options.minHorizonAngleRad;

    // Copy SSCT options
    tAmbientOcclusionOptions.ssct.lightConeRad = options.ssct.lightConeRad;
    tAmbientOcclusionOptions.ssct.shadowDistance = options.ssct.shadowDistance;
    tAmbientOcclusionOptions.ssct.contactDistanceMax = options.ssct.contactDistanceMax;
    tAmbientOcclusionOptions.ssct.intensity = options.ssct.intensity;
    tAmbientOcclusionOptions.ssct.lightDirectionX = options.ssct.lightDirection[0];
    tAmbientOcclusionOptions.ssct.lightDirectionY = options.ssct.lightDirection[1];
    tAmbientOcclusionOptions.ssct.lightDirectionZ = options.ssct.lightDirection[2];
    tAmbientOcclusionOptions.ssct.depthBias = options.ssct.depthBias;
    tAmbientOcclusionOptions.ssct.depthSlopeBias = options.ssct.depthSlopeBias;
    tAmbientOcclusionOptions.ssct.sampleCount = options.ssct.sampleCount;
    tAmbientOcclusionOptions.ssct.rayCount = options.ssct.rayCount;
    tAmbientOcclusionOptions.ssct.enabled = options.ssct.enabled;

    // Copy GTAO options
    tAmbientOcclusionOptions.gtao.sampleSliceCount = options.gtao.sampleSliceCount;
    tAmbientOcclusionOptions.gtao.sampleStepsPerSlice = options.gtao.sampleStepsPerSlice;
    tAmbientOcclusionOptions.gtao.thicknessHeuristic = options.gtao.thicknessHeuristic;
    tAmbientOcclusionOptions.gtao.useVisibilityBitmasks = options.gtao.useVisibilityBitmasks;
    tAmbientOcclusionOptions.gtao.constThickness = options.gtao.constThickness;
    tAmbientOcclusionOptions.gtao.linearThickness = options.gtao.linearThickness;

    await withVoidCallback(
      (requestId, cb) => View_setAmbientOcclusionOptionsRenderThread(view, tAmbientOcclusionOptions, requestId, cb),
    );
  }

  @override
  AmbientOcclusionOptions getAmbientOcclusionOptions() {
    final tOptions = View_getAmbientOcclusionOptions(view);

    return AmbientOcclusionOptions(
      aoType: AmbientOcclusionType.values[tOptions.aoType],
      radius: tOptions.radius,
      power: tOptions.power,
      bias: tOptions.bias,
      resolution: tOptions.resolution,
      intensity: tOptions.intensity,
      bilateralThreshold: tOptions.bilateralThreshold,
      quality: QualityLevel.values[tOptions.quality],
      lowPassFilter: QualityLevel.values[tOptions.lowPassFilter],
      upsampling: QualityLevel.values[tOptions.upsampling],
      enabled: tOptions.enabled,
      bentNormals: tOptions.bentNormals,
      minHorizonAngleRad: tOptions.minHorizonAngleRad,
      ssct: SsctOptions(
        lightConeRad: tOptions.ssct.lightConeRad,
        shadowDistance: tOptions.ssct.shadowDistance,
        contactDistanceMax: tOptions.ssct.contactDistanceMax,
        intensity: tOptions.ssct.intensity,
        lightDirection: [tOptions.ssct.lightDirectionX, tOptions.ssct.lightDirectionY, tOptions.ssct.lightDirectionZ],
        depthBias: tOptions.ssct.depthBias,
        depthSlopeBias: tOptions.ssct.depthSlopeBias,
        sampleCount: tOptions.ssct.sampleCount,
        rayCount: tOptions.ssct.rayCount,
        enabled: tOptions.ssct.enabled,
      ),
      gtao: GtaoOptions(
        sampleSliceCount: tOptions.gtao.sampleSliceCount,
        sampleStepsPerSlice: tOptions.gtao.sampleStepsPerSlice,
        thicknessHeuristic: tOptions.gtao.thicknessHeuristic,
        useVisibilityBitmasks: tOptions.gtao.useVisibilityBitmasks,
        constThickness: tOptions.gtao.constThickness,
        linearThickness: tOptions.gtao.linearThickness,
      ),
    );
  }

  @override
  Future setFrontFaceWindingInverted(bool inverted) async {
    await withVoidCallback(
      (requestId, cb) => View_setFrontFaceWindingInvertedRenderThread(view, inverted, requestId, cb),
    );
  }

  Future setShadowsEnabled(bool enabled) async {
    await withVoidCallback((requestId, cb) => View_setShadowsEnabledRenderThread(this.view, enabled, requestId, cb));
  }

  @override
  Future setShadowType(ShadowType shadowType) async {
    await withVoidCallback((requestId, cb) => View_setShadowTypeRenderThread(view, shadowType.index, requestId, cb));
  }

  @override
  Future<ShadowType> getShadowType() async {
    final shadowTypeIndex = View_getShadowType(view);
    return ShadowType.values[shadowTypeIndex];
  }

  @override
  Future setSoftShadowOptions(SoftShadowOptions options) async {
    final tSoftShadowOptions = StructAllocator.create<TSoftShadowOptions>();
    tSoftShadowOptions.penumbraScale = options.penumbraScale;
    tSoftShadowOptions.penumbraRatioScale = options.penumbraRatioScale;
    tSoftShadowOptions.maxPenumbraRatio = options.maxPenumbraRatio;
    tSoftShadowOptions.maxSearchRadius = options.maxSearchRadius;
    await withVoidCallback(
      (requestId, cb) => View_setSoftShadowOptionsRenderThread(view, tSoftShadowOptions, requestId, cb),
    );
  }

  @override
  SoftShadowOptions getSoftShadowOptions() {
    final tSoftShadowOptions = View_getSoftShadowOptions(view);
    return SoftShadowOptions(
      penumbraScale: tSoftShadowOptions.penumbraScale,
      penumbraRatioScale: tSoftShadowOptions.penumbraRatioScale,
      maxPenumbraRatio: tSoftShadowOptions.maxPenumbraRatio,
      maxSearchRadius: tSoftShadowOptions.maxSearchRadius,
    );
  }

  @override
  int getVisibleRenderableCount() => View_getVisibleRenderableCount(view);

  @override
  Future setVsmShadowOptions(VsmShadowOptions options) async {
    final tVsmShadowOptions = StructAllocator.create<TVsmShadowOptions>();
    tVsmShadowOptions.anisotropy = options.anisotropy;
    tVsmShadowOptions.mipmapping = options.mipmapping;
    tVsmShadowOptions.msaaSamples = options.msaaSamples;
    tVsmShadowOptions.highPrecision = options.highPrecision;
    tVsmShadowOptions.minVarianceScale = options.minVarianceScale;
    tVsmShadowOptions.lightBleedReduction = options.lightBleedReduction;
    await withVoidCallback(
      (requestId, cb) => View_setVsmShadowOptionsRenderThread(view, tVsmShadowOptions, requestId, cb),
    );
  }

  @override
  VsmShadowOptions getVsmShadowOptions() {
    final tVsmShadowOptions = View_getVsmShadowOptions(view);
    return VsmShadowOptions(
      anisotropy: tVsmShadowOptions.anisotropy,
      mipmapping: tVsmShadowOptions.mipmapping,
      msaaSamples: tVsmShadowOptions.msaaSamples,
      highPrecision: tVsmShadowOptions.highPrecision,
      minVarianceScale: tVsmShadowOptions.minVarianceScale,
      lightBleedReduction: tVsmShadowOptions.lightBleedReduction,
    );
  }

  HighlightOverlayManager? _highlightOverlayManager;

  @override
  HighlightOverlayManager? getHighlightOverlay() {
    return _highlightOverlayManager;
  }

  //
  Future _enableHighlightOverlay() async {
    final rm = _app.renderManager;
    final swapChains = rm.getAttachedSwapChains(this).toList();
    if (swapChains.isEmpty) {
      throw Exception("View must be attached to a swapchain first");
    }

    if (_highlightOverlayManager == null) {
      final vp = await getViewport();
      final width = vp.width > 0 ? vp.width : 1;
      final height = vp.height > 0 ? vp.height : 1;

      // Create manager if not exists
      _highlightOverlayManager = await HighlightOverlayManager.create(_app, width, height);

      // Set the camera - silhouette view shares the main camera
      final camera = await getCamera();
      await _highlightOverlayManager!.setCamera(camera);
    }

    // Configure output: render target (macOS/iOS) or swapchain (web/Android)
    await rm.detach(this, swapChain: swapChains.first);
    await rm.attach(_highlightOverlayManager!.silhouetteView, swapChains.first, renderOrder: 0);
    await rm.attach(this, swapChains.first, renderOrder: 1);
    await rm.attach(_highlightOverlayManager!.overlayView, swapChains.first, renderOrder: 2);

    if (renderTarget != null) {
      await _highlightOverlayManager!.setRenderTarget(this, renderTarget!);
      _logger.fine("Highlight overlay enabled (render target mode)");
    } else {
      await _highlightOverlayManager!.setSwapChain(swapChains.first);
      _logger.fine("Highlight overlay enabled (swapchain mode)");
    }
  }

  //
  Future _disableHighlightOverlay() async {
    if (_highlightOverlayManager == null) {
      return;
    }

    final rm = _app.renderManager;

    await rm.detach(_highlightOverlayManager!.silhouetteView);
    await rm.detach(_highlightOverlayManager!.overlayView);

    // Set to null BEFORE calling destroy to prevent the setRenderTarget
    // interceptor from redirecting to the already-destroyed EdgeDetectionView
    final manager = _highlightOverlayManager;
    _highlightOverlayManager = null;
    await manager!.destroy();

    _logger.info("Highlight overlay disabled");
  }

  @override
  Future setHighlightOverlayEnabled(bool enabled) async {
    if (enabled) {
      await _enableHighlightOverlay();
    } else {
      await _disableHighlightOverlay();
    }
  }

  // Highlights an entity with a screen-space outline.
  //
  // The overlay system must be enabled first via [enableHighlightOverlay].
  //
  // The outline width is specified in pixels and remains constant regardless
  // of camera distance (screen-space expansion).
  //
  // Uses a two-pass post-process rendering approach:
  // 1. Silhouette pass: Render highlighted entities to a texture as white
  //    silhouettes
  // 2. Edge detection pass: Fullscreen shader samples silhouette, draws
  //    outline where edges are detected
  //
  @override
  Future setStencilHighlight(
    ThermionAsset asset, {
    double r = 1.0,
    double g = 0.0,
    double b = 0.0,
    int? entity,
    double scale = 1.05,
    double outlineWidth = 3.0,
    int primitiveIndex = 0,
    ThermionAsset? geometrySource,
  }) async {
    // primitiveIndex parameter is deprecated and ignored
    // The offset is now computed automatically from the entity
    entity ??= asset.entity;

    // Use geometrySource for vertex/index buffers when provided (e.g. for
    // instances where the root asset has the preserved geometry data).
    final geoAsset = geometrySource ?? asset;
    final ffiGeoAsset = geoAsset as FFIAsset;

    // Stencil highlighting needs the barycentric coordinates generated only
    // for unwelded geometry. Editable geometry also has preserved buffers but
    // its CUSTOM0 stream does not contain those coordinates.
    if (!ffiGeoAsset.geometryCapabilities.contains(SceneAssetGeometryCapability.barycentrics)) {
      throw StateError(
        "setStencilHighlight requires unwelded geometry. "
        "Load it with loadGltf(..., vertexBufferMode: VertexBufferMode.unwelded).",
      );
    }

    if (_highlightOverlayManager == null) {
      await setHighlightOverlayEnabled(true);
    }

    // Get the starting primitive offset for this entity
    final offset = await ffiGeoAsset.getPrimitiveOffsetForEntity(entity);
    if (offset < 0) {
      // The asset has preserved geometry, but this particular entity has no
      // rebuilt buffers (e.g. its primitives are all lines/points).
      _logger.warning(
        "Stencil highlight: no preserved geometry for entity $entity "
        "(its primitives are all non-triangles and have no rebuilt buffers).",
      );
      return;
    }

    // Get the primitive count for this entity
    final primCount = await _app.getPrimitiveCount(entity);

    // Iterate all primitives for this entity and create silhouettes
    for (int i = 0; i < primCount; i++) {
      final flatPrimIndex = offset + i;

      // Get geometry for this primitive
      final vertexBuffer = geoAsset.getVertexBuffer(primitiveIndex: flatPrimIndex);
      final indexBuffer = SceneAsset_getIndexBuffer(ffiGeoAsset.asset, flatPrimIndex);

      // Skip non-triangle primitives (null buffers)
      if (vertexBuffer == null || indexBuffer == nullptr) {
        continue;
      }

      if (vertexBuffer is! FFIVertexBuffer) {
        _logger.warning(
          "Stencil highlight: unexpected vertex buffer type for entity $entity "
          "primitive $i",
        );
        continue;
      }

      final indexCount = IndexBuffer_getIndexCount(indexBuffer);
      final ffiIndexBuffer = FFIIndexBuffer(indexBuffer, _app.engine);

      // Create silhouette for this primitive
      await _highlightOverlayManager!.addHighlight(
        target: entity,
        vertexBuffer: vertexBuffer,
        indexBuffer: ffiIndexBuffer,
        indexCount: indexCount,
        outlineWidth: outlineWidth,
        r: r,
        g: g,
        b: b,
      );
    }

    _logger.info("Added stencil highlight for entity $entity");
  }

  ///
  /// Removes the stencil highlight from an asset.
  ///
  @override
  Future removeStencilHighlight(ThermionAsset asset) async {
    if (_highlightOverlayManager == null) {
      return;
    }
    final entities = [asset.entity, ...await asset.getChildEntities()];

    for (final entity in entities) {
      await _highlightOverlayManager!.removeHighlight(entity);
    }
  }

  Future setName(String name) async {
    final ptr = name.toNativeUtf8();
    await withVoidCallback((requestId, cb) => View_setNameRenderThread(getNativeHandle(), ptr.cast(), requestId, cb));
    free(ptr);
  }

  Future<String?> getName() async {
    final ptr = await withPointerCallback<Char>((cb) => View_getNameRenderThread(getNativeHandle(), cb));
    if (ptr != nullptr) {
      return ptr.cast<Utf8>().toDartString();
    }
    return null;
  }

  Future setTransparentPickingEnabled(bool enabled) async {
    await withVoidCallback(
      (requestId, cb) => View_setTransparentPickingEnabledRenderThread(getNativeHandle(), enabled, requestId, cb),
    );
  }

  Future<bool> isTransparentPickingEnabled() async {
    return View_isTransparentPickingEnabled(getNativeHandle());
  }

  static Future<View> create(FFIFilamentApp app) async {
    final ptr = await withPointerCallback<TView>((cb) => Engine_createViewRenderThread(app.engine, cb));
    return FFIView(ptr, app);
  }
}

import 'dart:async';
import 'dart:ffi' as ffi;
import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_index_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/highlight_overlay_manager.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_color_grading.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'ffi_camera.dart';

class FFIView extends View<Pointer<TView>> {
  late final _logger = Logger(this.runtimeType.toString());
  int _renderOrder = 0;
  int get renderOrder => _renderOrder;

  final Pointer<TView> view;

  Pointer<TView> getNativeHandle() => view;

  final FFIFilamentApp app;

  bool _renderable = false;
  bool get renderable => _renderable;

  RenderTarget? renderTarget;

  late CallbackHolder<PickCallbackFunction> _onPickResultHolder;

  FFIView(this.view, this.app) {
    final renderTargetPtr = View_getRenderTarget(view);
    if (renderTargetPtr != nullptr) {
      renderTarget = FFIRenderTarget(renderTargetPtr, app);
    }

    _onPickResultHolder = _onPickResult.asCallback();
  }

  ///
  Future destroy() async {
    _onPickResultHolder.dispose();

    View_setColorGrading(view, nullptr);
    if (_colorGrading != null && _colorGrading != nullptr) {
      await withVoidCallback((requestId, cb) =>
          Engine_destroyColorGradingRenderThread(
              FilamentApp.instance!.engine, _colorGrading!, requestId, cb));
    }
    await withVoidCallback((requestId, cb) => Engine_destroyViewRenderThread(
        FilamentApp.instance!.engine, view, requestId, cb));
  }

  ///
  ///
  ///
  Future setRenderOrder(int order) async {
    this._renderOrder = order;
    await FilamentApp.instance!.updateRenderOrder();
  }

  ///
  ///
  ///
  Future setRenderable(bool renderable) async {
    this._renderable = renderable;
    await FilamentApp.instance!.updateRenderOrder();
  }

  @override
  Future setViewport(int width, int height) async {
    View_setViewport(view, width, height);

    await _highlightOverlayManager?.setViewport(width, height);
  }

  Future<RenderTarget?> getRenderTarget() async {
    return renderTarget;
  }

  @override
  Future setRenderTarget(RenderTarget? renderTarget) async {
    if (renderTarget != null) {
      View_setRenderTarget(view, renderTarget.getNativeHandle());
      this.renderTarget = renderTarget;
    } else {
      View_setRenderTarget(view, nullptr);
      this.renderTarget = null;
    }
  }

  @override
  Future setCamera(Camera camera) async {
    View_setCamera(view, camera.getNativeHandle());

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
    return FFICamera(cameraPtr, app);
  }

  @override
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa) async {
    View_setAntiAliasing(view, msaa, fxaa, taa);
  }

  @override
  Future setPostProcessing(bool enabled) async {
    View_setPostProcessing(view, enabled);
  }

  @override
  Future setFrustumCullingEnabled(bool enabled) async {
    View_setFrustumCullingEnabled(view, enabled);
  }

  @override
  Future setBloom(bool enabled, double strength) async {
    await withVoidCallback((requestId, cb) {
      View_setBloomRenderThread(view, enabled, strength, requestId, cb);
    });
  }

  Pointer<TColorGrading>? _colorGrading;

  @override
  Future setToneMapper(ToneMapper mapper) async {
    final colorGrading = await withPointerCallback<TColorGrading>((cb) =>
        ColorGrading_createRenderThread(
            app.engine, mapper.getNativeHandle(), cb));
    if (colorGrading == nullptr) {
      throw Exception("Failed to create color grading");
    }

    await withVoidCallback((requestId, cb) =>
        View_setColorGradingRenderThread(view, colorGrading, requestId, cb));

    if (_colorGrading != null) {
      await withVoidCallback((requestId, cb) =>
          Engine_destroyColorGradingRenderThread(
              FilamentApp.instance!.engine, _colorGrading!, requestId, cb));
    }
    _colorGrading = colorGrading;
  }

  @override
  Future<ColorGradingBuilder> createColorGradingBuilder() async {
    final builderPtr = await withPointerCallback<TColorGradingBuilder>(
        (cb) => ColorGradingBuilder_createRenderThread(cb));
    if (builderPtr == nullptr) {
      throw Exception('Failed to create ColorGradingBuilder');
    }
    return FFIColorGradingBuilder(builderPtr, app);
  }

  @override
  Future setColorGrading(ColorGrading? colorGrading) async {
    if (colorGrading == null) {
      // Clear color grading by setting nullptr
      await withVoidCallback((requestId, cb) =>
          View_setColorGradingRenderThread(view, nullptr, requestId, cb));
    } else {
      // Set color grading with provided object
      await withVoidCallback((requestId, cb) =>
          View_setColorGradingRenderThread(
              view, colorGrading.getNativeHandle(), requestId, cb));
    }
  }

  @override
  Future<ColorGrading?> getColorGrading() async {
    final colorGradingPtr = View_getColorGrading(view);
    if (colorGradingPtr == nullptr) {
      return null;
    }
    return FFIColorGrading(colorGradingPtr, app);
  }

  Future setStencilBufferEnabled(bool enabled) async {
    return View_setStencilBufferEnabled(view, enabled);
  }

  Future<bool> isStencilBufferEnabled() async {
    return View_isStencilBufferEnabled(view);
  }

  Future setDithering(bool enabled) async {
    View_setDitheringEnabled(view, enabled);
  }

  Future<bool> isDitheringEnabled() async {
    return View_isDitheringEnabled(view);
  }

  @override
  Future setRenderQuality(QualityLevel quality) async {
    View_setRenderQuality(view, quality.index);
  }

  Future setScene(Scene scene) async {
    View_setScene(view, scene.getNativeHandle());
  }

  @override
  Future setLayerVisibility(VisibilityLayers layer, bool visible) async {
    View_setLayerEnabled(view, layer.value, visible);
  }

  Future setBlendMode(BlendMode blendMode) async {
    View_setBlendMode(view, blendMode.index);
  }

  FFIScene? _scene;

  @override
  Future<Scene> getScene() async {
    if (_scene == null) {
      _scene = FFIScene(View_getScene(view));
    }
    return _scene!;
  }

  int _pickRequestId = -1;

  static int kMaxPickRequests = 1024;
  final _pickRequests =
      List<({void Function(PickResult) handler, int x, int y})?>.generate(
          kMaxPickRequests, (idx) => null);

  ///
  ///
  ///
  @override
  Future pick(int x, int y, void Function(PickResult) resultHandler) async {
    _pickRequestId++;
    var pickRequestId = _pickRequestId;

    _pickRequests[_pickRequestId % kMaxPickRequests] =
        (handler: resultHandler, x: x, y: y);

    var viewport = await getViewport();
    y = viewport.height - y;
    if (FILAMENT_WASM) {
      View_pickRenderThread(
          view, pickRequestId, x, y, _onPickResultHolder.pointer);
    } else {
      View_pick(view, pickRequestId, x, y, _onPickResultHolder.pointer);
    }
  }

  void _onPickResult(int requestId, ThermionEntity entityId, double depth,
      double fragX, double fragY, double fragZ) async {
    final modRequestId = requestId % kMaxPickRequests;
    if (_pickRequests[modRequestId] == null) {
      _logger.severe(
          "Warning : pick result received with no matching request ID. This indicates you're clearing the pick cache too quickly");
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
    tFogOptions.skyColor =
        (options.skyColor as FFITexture?)?.pointer ?? nullptr;
    tFogOptions.linearColorR = options.linearColor.r;
    tFogOptions.linearColorG = options.linearColor.g;
    tFogOptions.linearColorB = options.linearColor.b;
    tFogOptions.enabled = options.enabled;
    View_setFogOptions(this.view, tFogOptions);
  }

  @override
  FogOptions getFogOptions() {
    final tOptions = View_getFogOptions(view);

    Texture? skyColor;
    if (tOptions.skyColor != nullptr) {
      skyColor = FFITexture(app.engine, tOptions.skyColor);
    }

    return FogOptions(
      enabled: tOptions.enabled,
      distance: tOptions.distance,
      cutOffDistance: tOptions.cutOffDistance,
      maximumOpacity: tOptions.maximumOpacity,
      height: tOptions.height,
      heightFalloff: tOptions.heightFalloff,
      linearColor: Vector3(
        tOptions.linearColorR,
        tOptions.linearColorG,
        tOptions.linearColorB,
      ),
      density: tOptions.density,
      inScatteringStart: tOptions.inScatteringStart,
      inScatteringSize: tOptions.inScatteringSize,
      fogColorFromIbl: tOptions.fogColorFromIbl,
      skyColor: skyColor,
    );
  }

  @override
  Future setAmbientOcclusionOptions(AmbientOcclusionOptions options) async {
    final tAmbientOcclusionOptions =
        StructAllocator.create<TAmbientOcclusionOptions>();

    tAmbientOcclusionOptions.radius = options.radius;
    tAmbientOcclusionOptions.power = options.power;
    tAmbientOcclusionOptions.bias = options.bias;
    tAmbientOcclusionOptions.resolution = options.resolution;
    tAmbientOcclusionOptions.intensity = options.intensity;
    tAmbientOcclusionOptions.bilateralThreshold = options.bilateralThreshold;
    // tAmbientOcclusionOptions.quality = options.quality.index;
    // tAmbientOcclusionOptions.lowPassFilter = options.lowPassFilter.index;
    // tAmbientOcclusionOptions.upsampling = options.upsampling.index;
    tAmbientOcclusionOptions.enabled = options.enabled;
    tAmbientOcclusionOptions.bentNormals = options.bentNormals;
    tAmbientOcclusionOptions.minHorizonAngleRad = options.minHorizonAngleRad;

    // Copy SSCT options
    // tAmbientOcclusionOptions.ssct.lightConeRad = options.ssct.lightConeRad;
    // tAmbientOcclusionOptions.ssct.shadowDistance = options.ssct.shadowDistance;
    // tAmbientOcclusionOptions.ssct.contactDistanceMax = options.ssct.contactDistanceMax;
    // tAmbientOcclusionOptions.ssct.intensity = options.ssct.intensity;
    // tAmbientOcclusionOptions.ssct.lightDirectionX = options.ssct.lightDirection[0];
    // tAmbientOcclusionOptions.ssct.lightDirectionY = options.ssct.lightDirection[1];
    // tAmbientOcclusionOptions.ssct.lightDirectionZ = options.ssct.lightDirection[2];
    // tAmbientOcclusionOptions.ssct.depthBias = options.ssct.depthBias;
    // tAmbientOcclusionOptions.ssct.depthSlopeBias = options.ssct.depthSlopeBias;
    // tAmbientOcclusionOptions.ssct.sampleCount = options.ssct.sampleCount;
    // tAmbientOcclusionOptions.ssct.rayCount = options.ssct.rayCount;
    // tAmbientOcclusionOptions.ssct.enabled = options.ssct.enabled;

    View_setAmbientOcclusionOptions(view, tAmbientOcclusionOptions);
  }

  @override
  AmbientOcclusionOptions getAmbientOcclusionOptions() {
    final tOptions = View_getAmbientOcclusionOptions(view);

    return AmbientOcclusionOptions(
      radius: tOptions.radius,
      power: tOptions.power,
      bias: tOptions.bias,
      resolution: tOptions.resolution,
      intensity: tOptions.intensity,
      bilateralThreshold: tOptions.bilateralThreshold,
      // quality: QualityLevel.values[tOptions.quality],
      // lowPassFilter: QualityLevel.values[tOptions.lowPassFilter],
      // upsampling: QualityLevel.values[tOptions.upsampling],
      enabled: tOptions.enabled,
      bentNormals: tOptions.bentNormals,
      minHorizonAngleRad: tOptions.minHorizonAngleRad,
      ssct: SsctOptions(
          // lightConeRad: tOptions.ssct.lightConeRad,
          // shadowDistance: tOptions.ssct.shadowDistance,
          // contactDistanceMax: tOptions.ssct.contactDistanceMax,
          // intensity: tOptions.ssct.intensity,
          // lightDirection: [
          //   tOptions.ssct.lightDirectionX,
          //   tOptions.ssct.lightDirectionY,
          //   tOptions.ssct.lightDirectionZ,
          // ],
          // depthBias: tOptions.ssct.depthBias,
          // depthSlopeBias: tOptions.ssct.depthSlopeBias,
          // sampleCount: tOptions.ssct.sampleCount,
          // rayCount: tOptions.ssct.rayCount,
          // enabled: tOptions.ssct.enabled,
          ),
    );
  }

  @override
  Future setFrontFaceWindingInverted(bool inverted) async {
    View_setFrontFaceWindingInverted(view, inverted);
  }

  Future setShadowsEnabled(bool enabled) async {
    View_setShadowsEnabled(this.view, enabled);
  }

  @override
  Future setShadowType(ShadowType shadowType) async {
    View_setShadowType(view, shadowType.index);
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
    View_setSoftShadowOptions(view, tSoftShadowOptions);
  }

  @override
  SoftShadowOptions getSoftShadowOptions() {
    final tSoftShadowOptions = View_getSoftShadowOptions(view);
    return SoftShadowOptions(
      penumbraScale: tSoftShadowOptions.penumbraScale,
      penumbraRatioScale: tSoftShadowOptions.penumbraRatioScale,
    );
  }

  @override
  Future setVsmShadowOptions(VsmShadowOptions options) async {
    final tVsmShadowOptions = StructAllocator.create<TVsmShadowOptions>();
    tVsmShadowOptions.anisotropy = options.anisotropy;
    tVsmShadowOptions.mipmapping = options.mipmapping;
    tVsmShadowOptions.msaaSamples = options.msaaSamples;
    tVsmShadowOptions.highPrecision = options.highPrecision;
    tVsmShadowOptions.minVarianceScale = options.minVarianceScale;
    tVsmShadowOptions.lightBleedReduction = options.lightBleedReduction;
    View_setVsmShadowOptions(view, tVsmShadowOptions);
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

  ///
  /// Enables the highlight overlay system for this view.
  ///
  @override
  Future<bool> enableHighlightOverlay() async {
    if (_highlightOverlayManager != null) {
      return true;
    }

    final vp = await getViewport();
    final width = vp.width > 0 ? vp.width : 1;
    final height = vp.height > 0 ? vp.height : 1;

    _highlightOverlayManager = await HighlightOverlayManager.create(
      app,
      width: width,
      height: height,
    );

    // Set the camera - silhouette view shares the main camera
    final camera = await getCamera();
    await _highlightOverlayManager!.setCamera(camera);

    _logger.info("Highlight overlay enabled");
    return true;
  }

  ///
  /// Disables the highlight overlay system and cleans up resources.
  ///
  @override
  Future disableHighlightOverlay() async {
    if (_highlightOverlayManager == null) {
      return;
    }

    await _highlightOverlayManager!.destroy();
    _highlightOverlayManager = null;

    // Update render order to remove silhouette/overlay views
    await app.updateRenderOrder();

    _logger.info("Highlight overlay disabled");
  }

  ///
  /// Highlights an entity with a screen-space outline.
  ///
  /// The overlay system must be enabled first via [enableHighlightOverlay].
  ///
  /// The outline width is specified in pixels and remains constant regardless
  /// of camera distance (screen-space expansion).
  ///
  /// Uses a two-pass post-process rendering approach:
  /// 1. Silhouette pass: Render highlighted entities to a texture as white silhouettes
  /// 2. Edge detection pass: Fullscreen shader samples silhouette, draws outline where edges are detected
  ///
  @override
  Future setStencilHighlight(ThermionAsset asset,
      {double r = 1.0,
      double g = 0.0,
      double b = 0.0,
      int? entity,
      double scale = 1.05,
      double outlineWidth = 3.0,
      int primitiveIndex = 0}) async {
    if (_highlightOverlayManager == null) {
      await enableHighlightOverlay();
    }

    entity ??= asset.entity;
    final entities = [entity, ...await asset.getChildEntities()];

    // Get geometry info for creating silhouette entity.
    // Only works for geometry assets or glTF loaded via parseGltf.
    final ffiAsset = asset as FFIAsset;
    final vertexBuffer = asset.getVertexBuffer(primitiveIndex: primitiveIndex);
    final indexBuffer =
        SceneAsset_getIndexBuffer(ffiAsset.asset, primitiveIndex);
    final hasGeometry = vertexBuffer != null && indexBuffer != ffi.nullptr;

    if (!hasGeometry || vertexBuffer is! FFIVertexBuffer) {
      throw UnsupportedError(
          "Stencil highlight requires geometry info (vertexBuffer and indexBuffer). "
          "glTF assets loaded via loadGlb/loadGltf are not supported. "
          "Use geometry assets or parseGltf instead.");
    }

    final indexCount = IndexBuffer_getIndexCount(indexBuffer);
    final ffiIndexBuffer = FFIIndexBuffer(indexBuffer, app.engine);

    for (final entity in entities) {
      if (!await FilamentApp.instance!.isRenderable(entity)) {
        continue;
      }
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

    // Update render order to include silhouette/overlay views
    await app.updateRenderOrder();

    _logger.info("Added stencil highlight for asset (entity ${asset.entity})");
  }

  /// Get the silhouette view for rendering highlighted entities to texture.
  /// Returns null if no highlights are active.
  @override
  View? getSilhouetteView() {
    return _highlightOverlayManager?.silhouetteView;
  }

  /// Get the overlay view for edge detection fullscreen quad.
  /// Returns null if no highlights are active.
  @override
  View? getOverlayView() {
    return _highlightOverlayManager?.overlayView;
  }


  /// Check if there are any active highlights.
  @override
  bool hasHighlights() {
    return _highlightOverlayManager?.hasHighlights ?? false;
  }

  ///
  /// Removes the stencil highlight from an asset.
  ///
  @override
  Future removeStencilHighlight(ThermionAsset asset) async {
    if (_highlightOverlayManager == null) {
      throw Exception("No overlay manager created");
    }
    final entities = [asset.entity, ...await asset.getChildEntities()];

    for (final entity in entities) {
      await _highlightOverlayManager!.removeHighlight(entity);
    }

    // Update render order to remove silhouette/overlay views if no more highlights
    await app.updateRenderOrder();
  }

  void setName(String name) {
    final ptr = name.toNativeUtf8();
    View_setName(getNativeHandle(), ptr.cast());
    free(ptr);
  }

  Future setTransparentPickingEnabled(bool enabled) async {
    View_setTransparentPickingEnabled(getNativeHandle(), enabled);
  }

  Future<bool> isTransparentPickingEnabled() async {
    return View_isTransparentPickingEnabled(getNativeHandle());
  }

  @override
  bool operator ==(Object other) =>
      other is FFIView && view.address == other.view.address;

  @override
  int get hashCode => view.address.hashCode;
}

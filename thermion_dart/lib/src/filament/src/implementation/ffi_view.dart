import 'dart:async';
import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
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
    if (_colorGrading != nullptr) {
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

  Timer? _overlayResize;

  @override
  Future setViewport(int width, int height) async {
    View_setViewport(view, width, height);

    if (overlayManager != null) {
      _overlayResize?.cancel();
      _overlayResize = Timer(Duration(milliseconds: 33), () async {
        var oldRenderTarget = overlayRenderTarget;
        overlayRenderTarget =
            await FilamentApp.instance!.createRenderTarget(width, height);
        OverlayManager_setRenderTarget(
            overlayManager!, overlayRenderTarget!.getNativeHandle());
        await oldRenderTarget!.destroy();
      });
    }
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
    }
    // await overlayView?.setRenderTarget(renderTarget);
  }

  @override
  Future setCamera(Camera camera) async {
    View_setCamera(view, camera.getNativeHandle());
    // await overlayView?.setCamera(camera.getNativeHandle());
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
        ColorGrading_createRenderThread(app.engine, mapper.getNativeHandle(), cb));
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
    final builderPtr = await withPointerCallback<TColorGradingBuilder>((cb) =>
        ColorGradingBuilder_createRenderThread(cb));
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
          View_setColorGradingRenderThread(view, colorGrading.getNativeHandle(), requestId, cb));
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

  Pointer<TOverlayManager>? overlayManager;
  View? overlayView;
  Scene? overlayScene;
  RenderTarget? overlayRenderTarget;
  Material? highlightMaterial;

  final _highlighted = <ThermionEntity, MaterialInstance>{};

  ///
  ///
  ///
  @override
  Future setStencilHighlight(ThermionAsset asset,
      {double r = 1.0,
      double g = 0.0,
      double b = 0.0,
      int? entity,
      double scale = 1.05,
      int primitiveIndex = 0}) async {
    if (overlayScene == null) {
      overlayScene = await FilamentApp.instance!.createScene();
      final vp = await getViewport();
      overlayRenderTarget =
          await FilamentApp.instance!.createRenderTarget(vp.width, vp.height);
      overlayManager = OverlayManager_create(
          app.engine,
          app.renderer,
          getNativeHandle(),
          overlayScene!.getNativeHandle(),
          overlayRenderTarget!.getNativeHandle());
      RenderTicker_setOverlayManager(app.renderTicker, overlayManager!);
      final highlightMaterialPtr = await withPointerCallback<TMaterial>(
          (cb) => Material_createOutlineMaterialRenderThread(app.engine, cb));
      highlightMaterial = FFIMaterial(highlightMaterialPtr, app);
    }

    MaterialInstance? highlightMaterialInstance;

    entity ??= asset.entity;
    final entities = [entity, ...await asset.getChildEntities()];

    for (final entity in entities) {
      if (!await FilamentApp.instance!.isRenderable(entity)) {
        continue;
      }
      if (_highlighted.containsKey(entity)) {
        _highlighted[entity]!.setParameterFloat4("color", r, g, b, 1.0);
      } else {
        if (highlightMaterialInstance == null) {
          highlightMaterialInstance = await highlightMaterial!.createInstance();
          await highlightMaterialInstance.setParameterFloat("scale", scale);
          await highlightMaterialInstance.setParameterFloat4(
              "color", r, g, b, 1.0);

          await highlightMaterialInstance.setDepthCullingEnabled(true);
          await highlightMaterialInstance.setDepthWriteEnabled(true);
        }
        OverlayManager_addComponent(overlayManager!, entity,
            highlightMaterialInstance.getNativeHandle());
        _highlighted[entity] = highlightMaterialInstance;
      }
    }

    _logger.info("Added stencil highlight for asset (entity ${asset.entity})");
  }

  ///
  ///
  ///
  @override
  Future removeStencilHighlight(ThermionAsset asset) async {
    if (overlayManager == null) {
      return;
    }
    final entities = [asset.entity, ...await asset.getChildEntities()];

    for (final entity in entities) {
      OverlayManager_removeComponent(overlayManager!, entity);
    }

    final destroyed = <MaterialInstance>{};
    for (final entity in entities) {
      final materialInstance = _highlighted[entity];
      if (!await FilamentApp.instance!.isRenderable(entity) ||
          materialInstance == null) {
        continue;
      }

      _highlighted.remove(entity);
      if (!destroyed.contains(materialInstance)) {
        await materialInstance.destroy();
        destroyed.add(materialInstance);
      }
    }
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
}

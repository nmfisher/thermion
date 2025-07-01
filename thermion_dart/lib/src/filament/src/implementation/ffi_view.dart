import 'dart:async';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
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
  ///
  ///
  Future dispose() async {
    _onPickResultHolder.dispose();
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
    // await overlayView?.setViewport(width, height);
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

  final colorGrading = <ToneMapper, Pointer<TColorGrading>>{};

  @override
  Future setToneMapper(ToneMapper mapper) async {
    if (colorGrading[mapper] == null) {
      colorGrading[mapper] =
          await FilamentApp.instance!.createColorGrading(mapper);
      if (colorGrading[mapper] == nullptr) {
        throw Exception("Failed to create color grading");
      }
    }

    View_setColorGrading(view, colorGrading[mapper]!);
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
    final tFogOptions = Struct.create<TFogOptions>();

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

  Future setShadowsEnabled(bool enabled) async {
    View_setShadowsEnabled(this.view, enabled);
  }

  Pointer<TOverlayManager>? overlayManager;
  View? overlayView;
  Scene? overlayScene;
  RenderTarget? overlayRenderTarget;
  Material? highlightMaterial;

  final _highlighted = <ThermionAsset, MaterialInstance>{};

  ///
  ///
  ///
  @override
  Future setStencilHighlight(ThermionAsset asset,
      {double r = 1.0,
      double g = 0.0,
      double b = 0.0,
      int? entity,
      int primitiveIndex = 0}) async {
    entity ??= asset.entity;


    if (overlayScene == null) {
      // overlayView = await FilamentApp.instance!.createView();
      overlayScene = await FilamentApp.instance!.createScene();
      // await overlayView!.setScene(overlayScene!);
      // await overlayView!.setRenderTarget(await this.getRenderTarget());

      final vp = await getViewport();
      overlayRenderTarget =
          await FilamentApp.instance!.createRenderTarget(vp.width, vp.height);
      overlayManager = OverlayManager_create(
          app.engine,
          app.renderer,
          getNativeHandle(),
          overlayScene!.getNativeHandle(),
          overlayRenderTarget!.getNativeHandle());
      // await setBlendMode(BlendMode.transparent);
      // await overlayView!.setBlendMode(BlendMode.transparent);
      // await overlayView!.setCamera(await getCamera());
      // await overlayView!.setViewport(vp.width, vp.height);
      // await setStencilBufferEnabled(true);
      // await overlayView!.setStencilBufferEnabled(true);
      RenderTicker_setOverlayManager(app.renderTicker, overlayManager!);
      highlightMaterial ??= await FilamentApp.instance!.createMaterial(
          File("/Users/nickfisher/Documents/thermion/materials/outline.filamat")
              .readAsBytesSync());
    }

    // await sourceMaterialInstance.setStencilWriteEnabled(true);
    // await sourceMaterialInstance
    //     .setStencilOpDepthStencilPass(StencilOperation.REPLACE);
    // await sourceMaterialInstance
    //     .setStencilReferenceValue(View.STENCIL_HIGHLIGHT_REFERENCE_VALUE);
    // await sourceMaterialInstance.setDepthCullingEnabled(false);
    // await sourceMaterialInstance.setDepthFunc(SamplerCompareFunction.A);
    // await sourceMaterialInstance
    //     .setStencilCompareFunction(SamplerCompareFunction.A);

    var highlightMaterialInstance = await highlightMaterial!.createInstance();

    await highlightMaterialInstance.setDepthCullingEnabled(true);
    await highlightMaterialInstance.setDepthWriteEnabled(true);

    OverlayManager_addComponent(
        overlayManager!, entity, highlightMaterialInstance.getNativeHandle());

    _highlighted[asset] = highlightMaterialInstance;

    _logger.info("Added stencil highlight for asset (entity ${asset.entity})");
  }

  ///
  ///
  ///
  @override
  Future removeStencilHighlight(ThermionAsset asset) async {
    if (!_highlighted.containsKey(asset)) {
      _logger
          .warning("No stencil highlight for asset (entity ${asset.entity})");
      return;
    }
    final materialInstance = _highlighted[asset]!;
    _highlighted.remove(asset);
    _logger
        .info("Removing stencil highlight for asset (entity ${asset.entity})");

    OverlayManager_removeComponent(overlayManager!, asset.entity);

    await materialInstance.destroy();

    _logger
        .info("Removed stencil highlight for asset (entity ${asset.entity})");
  }

  void setName(String name) {
    View_setName(getNativeHandle(), name.toNativeUtf8().cast());
  }
}

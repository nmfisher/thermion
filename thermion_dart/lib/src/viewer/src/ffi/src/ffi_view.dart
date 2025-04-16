import 'dart:async';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/scene.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_filament_app.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_render_target.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_scene.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'callbacks.dart';
import 'ffi_camera.dart';

class FFIView extends View {

  late final _logger = Logger(this.runtimeType.toString());
  int _renderOrder = 0;
  int get renderOrder => _renderOrder;

  final Pointer<TView> view;
  final FFIFilamentApp app;

  bool _renderable = false;
  bool get renderable => _renderable;

  FFIRenderTarget? renderTarget;

  FFIView(this.view, this.app) {
    final renderTargetPtr = View_getRenderTarget(view);
    if (renderTargetPtr != nullptr) {
      renderTarget = FFIRenderTarget(renderTargetPtr, app);
    }
    
    _onPickResultCallable =
        NativeCallable<PickCallbackFunction>.listener(_onPickResult);
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
  }

  @override
  Future setViewport(int width, int height) async {
    View_setViewport(view, width, height);
  }

  Future<RenderTarget?> getRenderTarget() async {
    return renderTarget;
  }

  @override
  Future setRenderTarget(covariant FFIRenderTarget? renderTarget) async {
    if (renderTarget != null) {
      View_setRenderTarget(view, renderTarget.renderTarget);
      this.renderTarget = renderTarget;
    } else {
      View_setRenderTarget(view, nullptr);
    }
  }

  @override
  Future setCamera(FFICamera camera) async {
    View_setCamera(view, camera.camera);
  }

  @override
  Future<Viewport> getViewport() async {
    TViewport vp = View_getViewport(view);
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
    await withVoidCallback((cb) {
      View_setBloomRenderThread(view, enabled, strength, cb);
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
    View_setRenderQuality(view, TQualityLevel.values[quality.index]);
  }

  Future setScene(covariant FFIScene scene) async {
    View_setScene(view, scene.scene);
  }

  @override
  Future setLayerVisibility(VisibilityLayers layer, bool visible) async {
    View_setLayerEnabled(view, layer.value, visible);
  }

  Future setBlendMode(BlendMode blendMode) async {
    View_setBlendMode(view, TBlendMode.values[blendMode.index]);
  }

  @override
  Future<Scene> getScene() async {
    final ptr = View_getScene(view);
    return FFIScene(ptr);
  }

  int _pickRequestId = -1;
  
  static int kMaxPickRequests = 1024;
  final _pickRequests = List<({void Function(PickResult) handler, int x, int y})?>.generate(kMaxPickRequests, (idx) => null);
  
  late NativeCallable<PickCallbackFunction> _onPickResultCallable;
  
  ///
  ///
  ///
  @override
  Future pick(int x, int y, void Function(PickResult) resultHandler) async {
    _pickRequestId = max(_pickRequestId + 1, kMaxPickRequests);
    
    _pickRequests[_pickRequestId % kMaxPickRequests] =
        (handler: resultHandler, x: x, y: y);
    var pickRequestId = _pickRequestId;
    var viewport = await getViewport();
    y = viewport.height - y;

    View_pick(
        view, pickRequestId, x, y, _onPickResultCallable.nativeFunction);

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

}

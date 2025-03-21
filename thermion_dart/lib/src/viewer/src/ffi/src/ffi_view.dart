import 'package:thermion_dart/src/filament/src/scene.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_filament_app.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_render_target.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/layers.dart';
import 'package:thermion_dart/src/filament/src/shared_types.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'callbacks.dart';
import 'ffi_camera.dart';

class FFIView extends View {
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
  }

  Future setRenderable(bool renderable) async {
    this._renderable = renderable;
  }

  @override
  Future setViewport(int width, int height) async {
    // var width_logbase2 = log(width) / ln2;
    // var height_logbase2 = log(height) / ln2;
    // var newWidth = pow(2.0, width_logbase2.ceil());
    // var newHeight = pow(2.0, height_logbase2.ceil());
    // print("old: ${width}x${height} new: ${height}x${newHeight}");
    // width = newWidth.toInt();
    // height = newHeight.toInt();
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

  @override
  Future<Scene> getScene() async {
    final ptr = View_getScene(view);
    return FFIScene(ptr);
  }
}

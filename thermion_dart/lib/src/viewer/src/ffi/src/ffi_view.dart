import 'dart:ffi';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_dart.g.dart';
import 'package:thermion_dart/src/viewer/src/shared_types/shared_types.dart';
import 'ffi_camera.dart';
import 'thermion_viewer_ffi.dart';

class FFIView extends View {
  final Pointer<TView> view;
  final Pointer<TViewer> viewer;

  FFIView(this.view, this.viewer);

  @override
  Future updateViewport(int width, int height) async {
    View_updateViewport(view, width, height);
  }

  @override
  Future setRenderTarget(covariant FFIRenderTarget renderTarget) async {
    View_setRenderTarget(view, renderTarget.renderTarget);
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
  Camera getCamera() {
    final engine = Viewer_getEngine(viewer);
    return FFICamera(View_getCamera(view), engine);
  }

  @override
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa) async {
    View_setAntiAliasing(view, msaa, fxaa, taa);
  }

  @override
  Future setPostProcessing(bool enabled) async {
    View_setPostProcessing(view, enabled);
  }

  Future setRenderable(bool renderable, FFISwapChain swapChain) async {
    Viewer_setViewRenderable(viewer, swapChain.swapChain, view, renderable);
  }

  @override
  Future setFrustumCullingEnabled(bool enabled) async {
    View_setFrustumCullingEnabled(view, enabled);
  }

  @override
  Future setBloom(double strength) async {
    View_setBloom(view, strength);
  }

  @override
  Future setToneMapper(ToneMapper mapper) async {
    final engine = await Viewer_getEngine(viewer);
    View_setToneMappingRenderThread(view, engine, mapper.index);
  }
}

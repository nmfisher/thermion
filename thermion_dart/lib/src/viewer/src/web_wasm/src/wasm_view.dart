import 'package:thermion_dart/thermion_dart.dart';

class WasmView extends View {
  final int tView;

  WasmView(this.tView);
  
  @override
  Camera getCamera() {
    // TODO: implement getCamera
    throw UnimplementedError();
  }
  
  @override
  Future<Viewport> getViewport() {
    // TODO: implement getViewport
    throw UnimplementedError();
  }
  
  @override
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa) {
    // TODO: implement setAntiAliasing
    throw UnimplementedError();
  }
  
  @override
  Future setBloom(double strength) {
    // TODO: implement setBloom
    throw UnimplementedError();
  }
  
  @override
  Future setCamera(covariant Camera camera) {
    // TODO: implement setCamera
    throw UnimplementedError();
  }
  
  @override
  Future setFrustumCullingEnabled(bool enabled) {
    // TODO: implement setFrustumCullingEnabled
    throw UnimplementedError();
  }
  
  @override
  Future setPostProcessing(bool enabled) {
    // TODO: implement setPostProcessing
    throw UnimplementedError();
  }
  
  @override
  Future setRenderTarget(covariant RenderTarget? renderTarget) {
    // TODO: implement setRenderTarget
    throw UnimplementedError();
  }
  
  @override
  Future setRenderable(bool renderable, covariant SwapChain swapChain) {
    // TODO: implement setRenderable
    throw UnimplementedError();
  }
  
  @override
  Future setToneMapper(ToneMapper mapper) {
    // TODO: implement setToneMapper
    throw UnimplementedError();
  }
  
  @override
  Future updateViewport(int width, int height) {
    // TODO: implement updateViewport
    throw UnimplementedError();
  }
}

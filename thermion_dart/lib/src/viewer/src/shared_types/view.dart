import 'package:thermion_dart/thermion_dart.dart';
import 'swap_chain.dart';

class Viewport {
  final int left;
  final int bottom;
  final int width;
  final int height;

  Viewport(this.left, this.bottom, this.width, this.height);
}

abstract class View {
  Future<Viewport> getViewport();
  Future updateViewport(int width, int height);
  Future setRenderTarget(covariant RenderTarget? renderTarget);
  Future setCamera(covariant Camera camera);
  Camera getCamera();
  Future setPostProcessing(bool enabled);
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa);
  Future setRenderable(bool renderable, covariant SwapChain swapChain);
}

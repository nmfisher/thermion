import 'package:thermion_dart/thermion_dart.dart';
import 'swap_chain.dart';

///
/// The viewport currently attached to a [View].
///
/// The dimensions here are guaranteed to be in physical pixels.
///
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
  Future<Camera> getCamera();
  Future setPostProcessing(bool enabled);
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa);
  Future setRenderable(bool renderable, covariant SwapChain swapChain);
  Future setFrustumCullingEnabled(bool enabled);
  Future setToneMapper(ToneMapper mapper);
  Future setBloom(double strength);
}

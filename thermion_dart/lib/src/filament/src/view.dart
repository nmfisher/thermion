import 'package:thermion_dart/src/filament/src/layers.dart';
import 'package:thermion_dart/src/filament/src/scene.dart';
import 'package:thermion_dart/thermion_dart.dart';

enum BlendMode { 
  opaque,
  transparent
}
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

enum QualityLevel { LOW, MEDIUM, HIGH, ULTRA }

abstract class View {
  Future<Scene> getScene();
  Future<Viewport> getViewport();
  Future setViewport(int width, int height);
  Future<RenderTarget?> getRenderTarget();
  Future setRenderTarget(covariant RenderTarget? renderTarget);
  int get renderOrder;
  Future setRenderOrder(int order);
  Future setCamera(covariant Camera camera);
  Future<Camera> getCamera();
  Future setPostProcessing(bool enabled);
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa);
  Future setFrustumCullingEnabled(bool enabled);
  Future setToneMapper(ToneMapper mapper);
  Future setStencilBufferEnabled(bool enabled);
  Future<bool> isStencilBufferEnabled();
  Future setDithering(bool enabled);
  Future<bool> isDitheringEnabled();
  Future setBloom(bool enabled, double strength);
  Future setBlendMode(BlendMode blendMode);
  Future setRenderQuality(QualityLevel quality);
  Future setLayerVisibility(VisibilityLayers layer, bool visible);
}

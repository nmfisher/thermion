import 'package:thermion_dart/src/filament/src/interface/layers.dart';
import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FogOptions {
  final double distance;
  final double cutOffDistance;
  final double maximumOpacity;
  final double height;
  final double heightFalloff;
  late final Vector3 linearColor;
  final double density;
  final double inScatteringStart;
  final double inScatteringSize;
  final bool fogColorFromIbl;
  final Texture? skyColor;
  final bool enabled;

  FogOptions(
      {this.enabled = false,
      this.distance = 0.0,
      this.cutOffDistance = double.infinity,
      this.maximumOpacity = 1.0,
      this.height = 0,
      this.heightFalloff = 1,
      Vector3? linearColor = null,
      this.density = 0.1,
      this.inScatteringStart = 0,
      this.inScatteringSize = -1,
      this.fogColorFromIbl = false,
      this.skyColor = null}) {
    this.linearColor = linearColor ?? Vector3(1, 1, 1);
  }
}

enum BlendMode { opaque, transparent }

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

abstract class View<T> extends NativeHandle<T> {
  static int STENCIL_HIGHLIGHT_REFERENCE_VALUE = 1;

  /// Gets the scene currently associated with this View.
  ///
  ///
  Future<Scene> getScene();

  /// Sets the scene currently associated with this View.
  ///
  ///
  Future setScene(Scene scene);

  /// Sets the (debug) name for this View.
  ///
  ///
  void setName(String name);

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
  Future setShadowsEnabled(bool enabled);
  Future setLayerVisibility(VisibilityLayers layer, bool visible);

  Future setTransparentPickingEnabled(bool enabled);
  Future<bool> isTransparentPickingEnabled();

  /// Renders an outline around [entity] with the given color.
  Future setStencilHighlight(ThermionAsset asset,
      {double r = 1.0,
      double g = 0.0,
      double b = 0.0,
      int? entity,
      double scale = 1.05,
      int primitiveIndex = 0});

  /// Removes the outline around [entity]. Noop if there was no highlight.
  Future removeStencilHighlight(ThermionAsset asset);

  /// Sets the fog options for this view.
  /// Fog is disabled by default
  ///
  Future setFogOptions(FogOptions options);

  ///
  /// Call [pick] to hit-test renderable entities at given viewport coordinates
  /// (or use one of the provided [InputHandler] classes which does this for you under the hood)
  ///
  /// Picking is an asynchronous operation that will usually take 2-3 frames to complete (so ensure you are calling render).
  ///
  /// [x] and [y] must be in local logical coordinates (i.e. where 0,0 is at top-left of the viewport).
  ///
  Future pick(int x, int y, void Function(PickResult) resultHandler);

  ///
  ///
  ///
  Future dispose();
}

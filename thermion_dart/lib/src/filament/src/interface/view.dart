import 'package:thermion_dart/src/filament/src/implementation/highlight_overlay_manager.dart';
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

  FogOptions({
    this.enabled = false,
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
    this.skyColor = null,
  }) {
    this.linearColor = linearColor ?? Vector3(1, 1, 1);
  }
}

class SsctOptions {
  final double lightConeRad;
  final double shadowDistance;
  final double contactDistanceMax;
  final double intensity;
  final List<double> lightDirection;
  final double depthBias;
  final double depthSlopeBias;
  final int sampleCount;
  final int rayCount;
  final bool enabled;

  const SsctOptions({
    this.lightConeRad = 1.0,
    this.shadowDistance = 0.3,
    this.contactDistanceMax = 1.0,
    this.intensity = 0.8,
    this.lightDirection = const [0, -1, 0],
    this.depthBias = 0.01,
    this.depthSlopeBias = 0.01,
    this.sampleCount = 4,
    this.rayCount = 1,
    this.enabled = false,
  });
}

/// Ground Truth-based Ambient Occlusion (GTAO) options.
class GtaoOptions {
  final int sampleSliceCount;
  final int sampleStepsPerSlice;
  final double thicknessHeuristic;
  final bool useVisibilityBitmasks;
  final double constThickness;
  final bool linearThickness;

  const GtaoOptions({
    this.sampleSliceCount = 4,
    this.sampleStepsPerSlice = 3,
    this.thicknessHeuristic = 0.004,
    this.useVisibilityBitmasks = false,
    this.constThickness = 0.5,
    this.linearThickness = false,
  });
}

enum AmbientOcclusionType { SAO, GTAO }

class AmbientOcclusionOptions {
  final AmbientOcclusionType aoType;
  final double radius;
  final double power;
  final double bias;
  final double resolution;
  final double intensity;
  final double bilateralThreshold;
  final QualityLevel quality;
  final QualityLevel lowPassFilter;
  final QualityLevel upsampling;
  final bool enabled;
  final bool bentNormals;
  final double minHorizonAngleRad;
  final SsctOptions ssct;
  final GtaoOptions gtao;

  const AmbientOcclusionOptions({
    this.aoType = AmbientOcclusionType.SAO,
    this.radius = 0.3,
    this.power = 1.0,
    this.bias = 0.0005,
    this.resolution = 0.5,
    this.intensity = 1.0,
    this.bilateralThreshold = 0.05,
    this.quality = QualityLevel.LOW,
    this.lowPassFilter = QualityLevel.MEDIUM,
    this.upsampling = QualityLevel.LOW,
    this.enabled = false,
    this.bentNormals = false,
    this.minHorizonAngleRad = 0.0,
    this.ssct = const SsctOptions(),
    this.gtao = const GtaoOptions(),
  });
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

enum LutFormat { INTEGER, FLOAT }

// ColorGrading object that holds color grading configuration.
// ColorGrading is treated as const
// Created via View.createColorGradingBuilder().build() and applied to a view.
// Will be disposed when View.setColorGrading is called.
abstract class ColorGrading extends NativeHandle<dynamic> {}

///
/// Builder for creating ColorGrading objects with the full Filament color pipeline.
///
/// Usage:
/// ```dart
/// final colorGrading = await view.createColorGradingBuilder()
///   .toneMapper(ToneMapper.ACES)
///   .exposure(1.0)
///   .contrast(1.1)
///   .saturation(1.05)
///   .build();
/// await view.setColorGrading(colorGrading);
/// ```
///
/// All methods return this builder for method chaining.
/// The builder is consumed after build() and cannot be reused.
///
abstract class ColorGradingBuilder {
  // ============================================================================
  // Quality and format
  // ============================================================================

  /// Sets the quality level of the color grading LUT.
  ///
  /// - LOW: 16x16x16 10-bit LUT
  /// - MEDIUM: 32x32x32 10-bit LUT (default)
  /// - HIGH: 32x32x32 16-bit LUT
  /// - ULTRA: 64x64x64 16-bit LUT
  ColorGradingBuilder quality(QualityLevel level);

  /// Sets the internal storage format of the color grading LUT.
  ///
  /// Overrides the format implied by [quality]. INTEGER is 10-bit, FLOAT is 16-bit.
  ColorGradingBuilder format(LutFormat format);

  /// Sets the dimensions of the color grading LUT cube (e.g. 16, 32, 64).
  ///
  /// Overrides the dimensions implied by [quality]. Clamped to [8, 64] internally.
  ColorGradingBuilder dimensions(int dim);

  /// Sets the tone mapping operator.
  ///
  /// Default is ACESLegacy. The tone mapper must have a lifecycle that
  /// exceeds this method call.
  ColorGradingBuilder toneMapper(ToneMapper mapper);

  // ============================================================================
  // Basic adjustments
  // ============================================================================

  /// Adjusts the exposure in stops (EV).
  ///
  /// Each stop brightens (positive) or darkens (negative) by a factor of 2.
  /// Applied after all post-processing. Default: 0.0
  ColorGradingBuilder exposure(double exposure);

  /// Controls night adaptation (0.0 = none, 1.0 = full).
  ///
  /// Simulates human vision in low-light: darker tones appear brighter,
  /// contrast reduces, and colors shift blue. Default: 0.0
  ColorGradingBuilder nightAdaptation(double adaptation);

  /// Adjusts white balance.
  ///
  /// - [temperature]: -1.0 (cool/blue, 50000K) to +1.0 (warm/yellow, 2000K)
  /// - [tint]: -1.0 (green) to +1.0 (magenta)
  ///
  /// Default: temperature=0.0, tint=0.0
  ColorGradingBuilder whiteBalance(double temperature, double tint);

  // ============================================================================
  // Color adjustments
  // ============================================================================

  /// Adjusts contrast (0.0 to 2.0, default 1.0).
  ///
  /// Lower values narrow the tonal range, higher values widen it.
  /// Applied in log space.
  ColorGradingBuilder contrast(double contrast);

  /// Adjusts vibrance (0.0 to 2.0, default 1.0).
  ///
  /// Saturation adjustment that affects low-saturation colors more than
  /// high-saturation colors. Applied in linear space.
  ColorGradingBuilder vibrance(double vibrance);

  /// Adjusts saturation (0.0 to 2.0, default 1.0).
  ///
  /// Lower values desaturate, higher values increase color intensity.
  /// Applied in linear space.
  ColorGradingBuilder saturation(double saturation);

  // ============================================================================
  // Advanced controls
  // ============================================================================

  /// Modifies each output color channel using a mix of source channels.
  ///
  /// Default: outRed=(1,0,0), outGreen=(0,1,0), outBlue=(0,0,1)
  /// Each component can be -2.0 to +2.0.
  ///
  /// Example (sepia tone):
  /// ```dart
  /// .channelMixer(
  ///   Vector3(0.393, 0.769, 0.189),  // outRed
  ///   Vector3(0.349, 0.686, 0.168),  // outGreen
  ///   Vector3(0.272, 0.534, 0.131),  // outBlue
  /// )
  /// ```
  ColorGradingBuilder channelMixer(Vector3 outRed, Vector3 outGreen, Vector3 outBlue);

  /// Adjusts colors in shadows, mid-tones, and highlights separately.
  ///
  /// Each zone is a Vector4 with RGB color and weight (.w).
  /// [ranges] defines zone transitions (x,y = shadows->midtones, z,w = midtones->highlights)
  ///
  /// Default: all (1,1,1,0), ranges (0, 0.333, 0.550, 1)
  /// Applied in linear space.
  ColorGradingBuilder shadowsMidtonesHighlights(Vector4 shadows, Vector4 midtones, Vector4 highlights, Vector4 ranges);

  /// Applies ASC CDL slope/offset/power adjustment.
  ///
  /// Similar to lift/gamma/gain controls.
  /// - [slope]: Multiplier (must be > 0, default 1.0)
  /// - [offset]: Added value (can be negative, default 0.0)
  /// - [power]: Exponent (must be > 0, default 1.0)
  ///
  /// Applied in log space.
  ColorGradingBuilder slopeOffsetPower(Vector3 slope, Vector3 offset, Vector3 power);

  /// Applies per-channel curves.
  ///
  /// - [shadowGamma]: Power for shadows (must be > 0, default 1.0)
  /// - [midPoint]: Where shadows end and highlights begin (must be > 0, default 1.0)
  /// - [highlightScale]: Scale for highlights (any value, default 1.0)
  ///
  /// Applied in linear space.
  ColorGradingBuilder curves(Vector3 shadowGamma, Vector3 midPoint, Vector3 highlightScale);

  // ============================================================================
  // Flags
  // ============================================================================

  /// Enables luminance scaling (EVILS/LICH) for more natural high-chroma rendering.
  ///
  /// When enabled, tone mapping is performed on luminance instead of per-channel.
  /// Helps avoid hue skews in out-of-gamut colors. Default: false
  ColorGradingBuilder luminanceScaling(bool enabled);

  /// Enables gamut mapping to prevent hue skews from out-of-gamut colors.
  ///
  /// Preserves perceived chroma and lightness when bringing colors back in gamut.
  /// Default: false
  ColorGradingBuilder gamutMapping(bool enabled);

  // ============================================================================
  // Build
  // ============================================================================

  /// Builds the ColorGrading object.
  ///
  /// The builder is consumed after this call and cannot be reused.
  /// The returned ColorGrading must be disposed when no longer needed.
  Future<ColorGrading> build();
}

abstract class View<T> extends NativeHandle<T> {
  static int STENCIL_HIGHLIGHT_REFERENCE_VALUE = 1;

  /// Gets the scene currently associated with this View.
  Future<Scene> getScene();

  /// Sets the scene currently associated with this View, or detaches the
  /// current scene when [scene] is null.
  Future setScene(Scene? scene);

  // Sets the (debug) name for this View.
  Future setName(String name);

  // Gets the (debug) name for this View.
  Future<String?> getName();

  Future<Viewport> getViewport();
  Future setViewport(int width, int height);
  Future<RenderTarget?> getRenderTarget();
  Future setRenderTarget(covariant RenderTarget? renderTarget);
  Future setCamera(Camera? camera);
  Future<Camera> getCamera();
  Future setPostProcessing(bool enabled);
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa);
  Future setFrustumCullingEnabled(bool enabled);
  Future setStencilBufferEnabled(bool enabled);
  Future<bool> isStencilBufferEnabled();
  Future setDithering(bool enabled);
  Future<bool> isDitheringEnabled();
  Future setBloom(bool enabled, double strength);
  Future setBlendMode(BlendMode blendMode);
  Future setRenderQuality(QualityLevel quality);
  Future setShadowsEnabled(bool enabled);
  Future setShadowType(ShadowType shadowType);
  Future<ShadowType> getShadowType();
  Future setSoftShadowOptions(SoftShadowOptions options);
  SoftShadowOptions getSoftShadowOptions();
  Future setVsmShadowOptions(VsmShadowOptions options);
  VsmShadowOptions getVsmShadowOptions();

  /// Returns the number of renderables visible during the most recent render.
  ///
  /// Returns -1 before the first render or while the visibility cache is
  /// invalid.
  int getVisibleRenderableCount();

  Future setLayerVisibility(VisibilityLayers layer, bool visible);

  /// Creates a builder for configuring color grading.
  ///
  /// Use the returned builder to configure the full Filament color pipeline
  /// (exposure, white balance, tone mapping, curves, etc.), then call build()
  /// to create a ColorGrading object that can be applied to this view.
  ///
  /// Example:
  /// ```dart
  /// final colorGrading = await view.createColorGradingBuilder()
  ///   .toneMapper(ToneMapper.ACES)
  ///   .exposure(1.0)
  ///   .contrast(1.1)
  ///   .build();
  /// await view.setColorGrading(colorGrading);
  /// ```
  Future<ColorGradingBuilder> createColorGradingBuilder();

  /// Sets the color grading for this view.
  ///
  /// The ColorGrading object must be created via createColorGradingBuilder().
  /// The view does not take ownership - you must dispose the ColorGrading
  /// when no longer needed.
  ///
  /// Pass null to clear any existing color grading from this view.
  Future setColorGrading(ColorGrading? colorGrading);

  /// Gets the current color grading from this view.
  ///
  /// Returns null if no color grading is currently set.
  Future<ColorGrading?> getColorGrading();

  /// Sets the tone mapper for this view (deprecated).
  ///
  /// @deprecated Use createColorGradingBuilder().toneMapper(...).build()
  /// followed by setColorGrading() instead. This provides access to the
  /// full color grading pipeline.
  @Deprecated('Use createColorGradingBuilder() instead')
  Future setToneMapper(ToneMapper mapper);

  Future setTransparentPickingEnabled(bool enabled);
  Future<bool> isTransparentPickingEnabled();

  // Enables the highlight overlay system for this view.
  //
  // Must be called before [setStencilHighlight]. This initializes the overlay
  // manager with the current viewport dimensions and creates the necessary
  // render targets for silhouette and edge detection passes.
  //
  // The edge detection view composites the main scene with edge outlines
  // into a single texture output. Requires a render target or swapchain.
  //
  // Returns true if initialization succeeded, false if already enabled.
  Future setHighlightOverlayEnabled(bool enabled);

  // Returns the highlight manager (or null if [setHighlightOverlayEnabled] was
  // called with false).
  HighlightOverlayManager? getHighlightOverlay();

  /// Renders a screen-space outline around [entity] with the given color.
  ///
  /// The overlay system must be enabled first via [enableHighlightOverlay].
  ///
  /// The outline width is specified in pixels via [outlineWidth] and remains
  /// constant regardless of camera distance (screen-space expansion).
  ///
  /// Uses a stencil-based two-pass rendering approach for clean, flicker-free
  /// outlines.
  ///
  /// The [scale] parameter is deprecated and ignored; use [outlineWidth] instead.
  Future setStencilHighlight(
    ThermionAsset asset, {
    double r = 1.0,
    double g = 0.0,
    double b = 0.0,
    int? entity,
    @Deprecated('Use outlineWidth instead') double scale = 1.05,
    double outlineWidth = 3.0,
    int primitiveIndex = 0,
    ThermionAsset? geometrySource,
  });

  /// Removes the outline around [entity]. Noop if there was no highlight.
  Future removeStencilHighlight(ThermionAsset asset);

  /// Sets the fog options for this view.
  /// Fog is disabled by default
  ///
  Future setFogOptions(FogOptions options);

  /// Gets the current fog options from this view.
  ///
  FogOptions getFogOptions();

  /// Sets the ambient occlusion options for this view.
  /// Ambient occlusion is disabled by default.
  ///
  Future setAmbientOcclusionOptions(AmbientOcclusionOptions options);

  /// Gets the current ambient occlusion options from this view.
  ///
  AmbientOcclusionOptions getAmbientOcclusionOptions();

  /// Inverts the winding order of front faces.
  ///
  Future setFrontFaceWindingInverted(bool inverted);

  ///
  /// Call [pick] to hit-test renderable entities at given viewport coordinates
  /// (or use one of the provided [InputHandler] classes which does this for you under the hood)
  ///
  /// Picking is an asynchronous operation that will usually take 2-3 frames to complete (so ensure you are calling render).
  ///
  /// [x] and [y] must be in local logical coordinates (i.e. where 0,0 is at top-left of the viewport).
  ///
  Future pick(int x, int y, void Function(PickResult) resultHandler);
}

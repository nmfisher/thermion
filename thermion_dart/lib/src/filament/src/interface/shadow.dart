import 'package:vector_math/vector_math_64.dart';

enum ShadowType {
  PCF, //!< percentage-closer filtered shadows (default)
  VSM, //!< variance shadows
  DPCF, //!< PCF with contact hardening simulation
  PCSS, //!< PCF with soft shadows and contact hardening
}

/// Shadow options for lights that cast shadows.
class ShadowOptions {
  /// Size of the shadow map in texels. Must be a power-of-two and larger or equal to 8.
  final int mapSize;

  /// Number of shadow cascades (1-4). Values > 1 enable cascaded shadow mapping.
  final int shadowCascades;

  /// Split positions for shadow cascades (for N cascades, N-1 splits are used).
  final List<double> cascadeSplitPositions;

  /// Constant bias in world units (e.g., meters).
  final double constantBias;

  /// Normal bias scaling factor.
  final double normalBias;

  /// Distance from camera after which shadows are clipped (0.0 = use camera far).
  final double shadowFar;

  /// Optimize shadow quality from this distance (0.0 = use camera near).
  final double shadowNearHint;

  /// Optimize shadow quality in front of this distance.
  final double shadowFarHint;

  /// Whether to optimize for stability over resolution.
  final bool stable;

  /// Enable Light-space Perspective Shadow Mapping.
  final bool lispsm;

  /// Constant polygon offset.
  final double polygonOffsetConstant;

  /// Slope-based polygon offset.
  final double polygonOffsetSlope;

  /// Enable screen-space contact shadows.
  final bool screenSpaceContactShadows;

  /// Number of ray-marching steps for screen-space contact shadows.
  final int stepCount;

  /// Maximum shadow-occluder distance for screen-space shadows.
  final double maxShadowDistance;

  /// Enable ELVSM (Exponential Layered VSM) for VSM shadow type.
  final bool vsmElvsm;

  /// VSM blur width (0.0 to disable, max 125).
  final double vsmBlurWidth;

  /// Light bulb radius for soft shadows (used with DPCF/PCSS).
  final double shadowBulbRadius;

  /// Light-specific multiplier applied to the final PCSS penumbra size.
  final double penumbraScale;

  /// Light-specific multiplier applied to the PCSS geometric penumbra ratio.
  final double penumbraRatioScale;

  /// Light-specific maximum PCSS penumbra ratio.
  ///
  /// Values less than or equal to zero use the view-level default.
  final double maxPenumbraRatio;

  /// Light-specific maximum PCSS blocker-search radius in world units.
  ///
  /// Values less than or equal to zero use the view-level default.
  final double maxSearchRadius;

  /// Shadow direction transform (quaternion: w, x, y, z).
  final Quaternion transform;

  ShadowOptions({
    this.mapSize = 1024,
    this.shadowCascades = 1,
    this.cascadeSplitPositions = const [0.125, 0.25, 0.50],
    this.constantBias = 0.001,
    this.normalBias = 1.0,
    this.shadowFar = 0.0,
    this.shadowNearHint = 1.0,
    this.shadowFarHint = 100.0,
    this.stable = false,
    this.lispsm = true,
    this.polygonOffsetConstant = 0.5,
    this.polygonOffsetSlope = 2.0,
    this.screenSpaceContactShadows = false,
    this.stepCount = 8,
    this.maxShadowDistance = 0.3,
    this.vsmElvsm = false,
    this.vsmBlurWidth = 0.0,
    this.shadowBulbRadius = 0.02,
    this.penumbraScale = 1.0,
    this.penumbraRatioScale = 1.0,
    this.maxPenumbraRatio = 0.0,
    this.maxSearchRadius = 0.0,
    Quaternion? transform,
  }) : transform = transform ?? Quaternion.identity();

  /// Creates a copy of this ShadowOptions with the given fields replaced with new values.
  ShadowOptions copyWith({
    int? mapSize,
    int? shadowCascades,
    List<double>? cascadeSplitPositions,
    double? constantBias,
    double? normalBias,
    double? shadowFar,
    double? shadowNearHint,
    double? shadowFarHint,
    bool? stable,
    bool? lispsm,
    double? polygonOffsetConstant,
    double? polygonOffsetSlope,
    bool? screenSpaceContactShadows,
    int? stepCount,
    double? maxShadowDistance,
    bool? vsmElvsm,
    double? vsmBlurWidth,
    double? shadowBulbRadius,
    double? penumbraScale,
    double? penumbraRatioScale,
    double? maxPenumbraRatio,
    double? maxSearchRadius,
    Quaternion? transform,
  }) {
    return ShadowOptions(
      mapSize: mapSize ?? this.mapSize,
      shadowCascades: shadowCascades ?? this.shadowCascades,
      cascadeSplitPositions: cascadeSplitPositions ?? this.cascadeSplitPositions,
      constantBias: constantBias ?? this.constantBias,
      normalBias: normalBias ?? this.normalBias,
      shadowFar: shadowFar ?? this.shadowFar,
      shadowNearHint: shadowNearHint ?? this.shadowNearHint,
      shadowFarHint: shadowFarHint ?? this.shadowFarHint,
      stable: stable ?? this.stable,
      lispsm: lispsm ?? this.lispsm,
      polygonOffsetConstant: polygonOffsetConstant ?? this.polygonOffsetConstant,
      polygonOffsetSlope: polygonOffsetSlope ?? this.polygonOffsetSlope,
      screenSpaceContactShadows: screenSpaceContactShadows ?? this.screenSpaceContactShadows,
      stepCount: stepCount ?? this.stepCount,
      maxShadowDistance: maxShadowDistance ?? this.maxShadowDistance,
      vsmElvsm: vsmElvsm ?? this.vsmElvsm,
      vsmBlurWidth: vsmBlurWidth ?? this.vsmBlurWidth,
      shadowBulbRadius: shadowBulbRadius ?? this.shadowBulbRadius,
      penumbraScale: penumbraScale ?? this.penumbraScale,
      penumbraRatioScale: penumbraRatioScale ?? this.penumbraRatioScale,
      maxPenumbraRatio: maxPenumbraRatio ?? this.maxPenumbraRatio,
      maxSearchRadius: maxSearchRadius ?? this.maxSearchRadius,
      transform: transform ?? this.transform,
    );
  }
}

/// View-level options for VSM Shadowing.
/// This controls how variance shadow maps are rendered and sampled.
class VsmShadowOptions {
  /// Number of anisotropic samples to use when sampling a VSM shadow map.
  /// If greater than 0, mipmaps will automatically be generated each frame.
  /// The number of anisotropic samples = 2 ^ anisotropy.
  final int anisotropy;

  /// Whether to generate mipmaps for all VSM shadow maps.
  final bool mipmapping;

  /// Number of MSAA samples to use when rendering VSM shadow maps.
  /// Must be a power-of-two and greater than or equal to 1.
  /// A value of 1 effectively turns off MSAA.
  final int msaaSamples;

  /// Whether to use a 32-bits or 16-bits texture format for VSM shadow maps.
  /// 32-bits precision reduces light leaks and "fading" shadows but doubles memory usage.
  final bool highPrecision;

  /// VSM minimum variance scale, must be positive.
  final double minVarianceScale;

  /// VSM light bleeding reduction amount, between 0 and 1.
  final double lightBleedReduction;

  const VsmShadowOptions({
    this.anisotropy = 0,
    this.mipmapping = false,
    this.msaaSamples = 1,
    this.highPrecision = false,
    this.minVarianceScale = 0.5,
    this.lightBleedReduction = 0.15,
  });
}

/// View-level options for DPCF and PCSS Shadowing.
/// This controls soft shadow behavior for contact hardening and penumbra effects.
class SoftShadowOptions {
  /// Globally scales the penumbra of all DPCF and PCSS shadows.
  /// Acceptable values are greater than 0.
  final double penumbraScale;

  /// Globally scales the computed penumbra ratio of all DPCF and PCSS shadows.
  /// This effectively controls the strength of contact hardening effect and is useful for
  /// artistic purposes. Higher values make the shadows become softer faster.
  /// Acceptable values are equal to or greater than 1.
  final double penumbraRatioScale;

  /// Maximum geometric ratio used to calculate PCSS penumbra size.
  ///
  /// Lower values suppress oversized ghost shadows from layered occluders.
  final double maxPenumbraRatio;

  /// Maximum PCSS blocker-search radius in world-space units.
  ///
  /// Lower values keep shadows anchored near complex contact geometry.
  final double maxSearchRadius;

  const SoftShadowOptions({
    this.penumbraScale = 1.0,
    this.penumbraRatioScale = 1.0,
    this.maxPenumbraRatio = 10.0,
    this.maxSearchRadius = 1.0,
  });
}

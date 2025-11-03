import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

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

  /// Shadow direction transform (quaternion: w, x, y, z).
  final List<double> transform;

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
    this.transform = const [1.0, 0.0, 0.0, 0.0], // identity quaternion (w, x, y, z)
  });
}

abstract class LightManager<T> extends NativeHandle<T> {
  
  /// Creates a new light entity with the specified type.
  /// The light must be added to a scene before it is visible.
  ThermionEntity createLight(LightType type);

  /// Destroys the specified light entity.
  void destroyLight(ThermionEntity entity);

  /// Returns whether an entity has a light component.
  bool hasComponent(ThermionEntity entity);

  /// Returns the type of the light (SUN, DIRECTIONAL, POINT, FOCUSED_SPOT, SPOT).
  LightType getType(ThermionEntity entity);

  /// Returns true if the light is directional (SUN or DIRECTIONAL).
  bool isDirectional(ThermionEntity entity);

  /// Returns true if the light is a point light.
  bool isPointLight(ThermionEntity entity);

  /// Returns true if the light is a spot light (SPOT or FOCUSED_SPOT).
  bool isSpotLight(ThermionEntity entity);

  // ============================================================================
  // Position and direction
  // ============================================================================

  /// Sets the position of a point or spot light.
  void setPosition(ThermionEntity light, double x, double y, double z);

  /// Gets the position of a light. Returns a list [x, y, z].
  List<double> getPosition(ThermionEntity light);

  /// Sets the direction of a directional or spot light.
  void setDirection(ThermionEntity light, double x, double y, double z);

  /// Gets the direction of a light. Returns a list [x, y, z].
  List<double> getDirection(ThermionEntity light);

  // ============================================================================
  // Color and intensity
  // ============================================================================

  /// Sets the color of a light using color temperature.
  /// Higher values produce cooler (bluer) light, lower values produce warmer (redder) light.
  void setColor(ThermionEntity light, double colorTemperature);

  /// Gets the RGB color of a light. Returns a list [r, g, b].
  List<double> getColor(ThermionEntity light);

  /// Sets the intensity/brightness of a light.
  /// For directional lights: lux (lumen/m²).
  /// For point/spot lights: lumens.
  void setIntensity(ThermionEntity light, double intensity);

  /// Sets the intensity of a spot or point light in candela.
  void setIntensityCandela(ThermionEntity light, double intensity);

  /// Sets the intensity based on watts and efficiency (0.0-1.0).
  void setIntensityWatts(ThermionEntity light, double watts, double efficiency);

  /// Returns the light's luminous intensity in candela.
  double getIntensity(ThermionEntity light);

  // ============================================================================
  // Falloff
  // ============================================================================

  /// Sets the falloff for point and spot lights (how quickly light diminishes with distance).
  void setFalloff(ThermionEntity light, double falloff);

  /// Returns the falloff distance of the light.
  double getFalloff(ThermionEntity light);

  // ============================================================================
  // Spot light cone
  // ============================================================================

  /// Sets the cone angles for spot lights.
  /// [inner] is the inner cone angle in radians, [outer] is the outer cone angle in radians.
  void setSpotLightCone(ThermionEntity light, double inner, double outer);

  /// Returns the outer cone angle in radians.
  double getSpotLightOuterCone(ThermionEntity light);

  /// Returns the inner cone angle in radians.
  double getSpotLightInnerCone(ThermionEntity light);

  // ============================================================================
  // Sun-specific methods
  // ============================================================================

  /// Sets the angular radius of the sun in degrees (0.25° to 20.0°).
  /// Earth's sun: 0.526° to 0.545°.
  void setSunAngularRadius(ThermionEntity light, double angularRadius);

  /// Returns the angular radius of the sun in degrees.
  double getSunAngularRadius(ThermionEntity light);

  /// Sets the halo radius multiplier (multiplies sun angular radius).
  void setSunHaloSize(ThermionEntity light, double haloSize);

  /// Returns the halo size multiplier.
  double getSunHaloSize(ThermionEntity light);

  /// Sets the halo falloff exponent.
  void setSunHaloFalloff(ThermionEntity light, double haloFalloff);

  /// Returns the halo falloff exponent.
  double getSunHaloFalloff(ThermionEntity light);

  // ============================================================================
  // Shadow options
  // ============================================================================

  /// Enables or disables shadow casting for the specified light.
  void setShadowCaster(ThermionEntity light, bool enabled);

  /// Returns whether the light casts shadows.
  bool isShadowCaster(ThermionEntity light);

  /// Sets the shadow options for the light.
  void setShadowOptions(ThermionEntity light, ShadowOptions options);

  /// Returns the shadow options for the light.
  ShadowOptions getShadowOptions(ThermionEntity light);

  // ============================================================================
  // Light channels
  // ============================================================================

  /// Enables or disables a light channel (0-7). Channel 0 is enabled by default.
  void setLightChannel(ThermionEntity light, int channel, bool enable);

  /// Returns whether a light channel is enabled.
  bool getLightChannel(ThermionEntity light, int channel);
}
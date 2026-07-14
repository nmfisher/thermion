import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

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

  /// Sets the color of a light using linear RGB values.
  /// [r], [g], [b] are the linear RGB color components in the range [0.0, 1.0].
  void setColor(ThermionEntity light, double r, double g, double b);

  /// Sets the color of a light using color temperature in Kelvin.
  /// Higher values produce cooler (bluer) light, lower values produce warmer (redder) light.
  /// Typical values: 2000K (warm/orange), 6500K (neutral white), 12000K (cool/blue).
  void setColorTemperature(ThermionEntity light, double colorTemperature);

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

  // ============================================================================
  // Shadow cascades utilities
  // ============================================================================

  /// Computes uniform split positions for shadow cascades.
  /// [cascades] is the number of shadow cascades (at most 4).
  /// Returns a list of cascade split positions (length will be cascades-1).
  List<double> computeUniformSplits(int cascades);

  /// Computes logarithmic split positions for shadow cascades.
  /// [cascades] is the number of shadow cascades (at most 4).
  /// [near] is the camera near plane.
  /// [far] is the camera far plane.
  /// Returns a list of cascade split positions (length will be cascades-1).
  List<double> computeLogSplits(int cascades, double near, double far);

  /// Computes practical split positions for shadow cascades.
  /// [cascades] is the number of shadow cascades (at most 4).
  /// [near] is the camera near plane.
  /// [far] is the camera far plane.
  /// [lambda] is a value in the range [0, 1] that interpolates between log and uniform split schemes.
  /// Start with a lambda value of 0.5f and adjust for your scene.
  /// Returns a list of cascade split positions (length will be cascades-1).
  List<double> computePracticalSplits(
    int cascades,
    double near,
    double far,
    double lambda,
  );

  // ============================================================================
  // Color temperature utilities
  // ============================================================================

  /// Converts linear RGB values to color temperature.
  /// [r], [g], [b] are the linear RGB color components in the range [0.0, 1.0].
  /// Returns the approximate color temperature in Kelvin (typically 1000K to 40000K).
  /// Uses McCamy's approximation for the conversion.
  double rgbToColorTemperature(double r, double g, double b);
}

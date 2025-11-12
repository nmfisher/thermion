import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart' as v;

/// Represents a linear RGB color with values in the range [0.0, 1.0].
/// This is used for physically-based lighting calculations.
class LinearColor {
  final double r;
  final double g;
  final double b;

  /// Creates a linear RGB color.
  /// [r], [g], [b] should be in the range [0.0, 1.0] for standard colors.
  const LinearColor(this.r, this.g, this.b);

  /// Pure white color (1.0, 1.0, 1.0)
  static const LinearColor white = LinearColor(1.0, 1.0, 1.0);

  /// Neutral white (equivalent to ~6500K)
  static const LinearColor neutralWhite = LinearColor(1.0, 1.0, 1.0);

  @override
  String toString() => 'LinearColor($r, $g, $b)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinearColor &&
          runtimeType == other.runtimeType &&
          r == other.r &&
          g == other.g &&
          b == other.b;

  @override
  int get hashCode => r.hashCode ^ g.hashCode ^ b.hashCode;
}

class IBL {
  String? iblPath;
  final double iblIntensity;

  IBL(this.iblIntensity);
}

class DirectLight {
  final LightType type;
  final LinearColor color;
  final double? colorTemperature;
  final double intensity;
  final bool castShadows;
  late final v.Vector3 position;
  late final v.Vector3 direction;
  final double falloffRadius;
  final double spotLightConeInner;
  final double spotLightConeOuter;
  final double sunAngularRadius;
  final double sunHaloSize;
  final double sunHaloFallof;

  DirectLight({
    required this.type,
    this.color = const LinearColor(1.0, 0.996, 0.980),
    this.colorTemperature,
    required this.intensity,
    this.castShadows = false,
    required this.direction,
    required this.position,
    this.falloffRadius = 1.0,
    this.spotLightConeInner = pi / 8,
    this.spotLightConeOuter = pi / 4,
    this.sunAngularRadius = 0.545,
    this.sunHaloSize = 10.0,
    this.sunHaloFallof = 80.0,
  });

  DirectLight.point({
    LinearColor? color,
    double? colorTemperature,
    double intensity = 100000,
    bool castShadows = false,
    Vector3? position,
    double falloffRadius = 1.0,
  }) : this(
    type: LightType.POINT,
    color: color ?? LinearColor.white,
    colorTemperature: colorTemperature,
    intensity: intensity,
    castShadows: castShadows,
    position: position ?? Vector3(0, 1, 0),
    direction: Vector3.zero(),
    falloffRadius: falloffRadius,
  );

  DirectLight.sun({
    LinearColor? color,
    double? colorTemperature,
    double intensity = 100000,
    bool castShadows = true,
    Vector3? direction,
    double sunAngularRadius = 0.545,
    double sunHaloSize = 10.0,
    double sunHaloFalloff = 80.0,
  }) : this(
    type: LightType.DIRECTIONAL,
    color: color ?? LinearColor.white,
    colorTemperature: colorTemperature,
    intensity: intensity,
    castShadows: castShadows,
    position: Vector3(0, 0, 0),
    direction: direction ?? Vector3(0, -1, 0),
    sunAngularRadius: sunAngularRadius,
    sunHaloSize: sunHaloSize,
    sunHaloFallof: sunHaloFalloff,
  );

  DirectLight.spot({
    LinearColor? color,
    double? colorTemperature,
    double intensity = 100000,
    bool castShadows = true,
    Vector3? position,
    Vector3? direction,
    double falloffRadius = 1.0,
    double spotLightConeInner = pi / 8,
    double spotLightConeOuter = pi / 4,
  }) : this(
    type: LightType.SPOT,
    color: color ?? LinearColor.white,
    colorTemperature: colorTemperature,
    intensity: intensity,
    castShadows: castShadows,
    position: position ?? Vector3(0, 1, 0),
    direction: direction ?? Vector3(0, -1, 0),
    falloffRadius: falloffRadius,
    spotLightConeInner: spotLightConeInner,
    spotLightConeOuter: spotLightConeOuter,
  );
}
import 'dart:math';
import 'package:vector_math/vector_math_64.dart' as v;
import 'package:vector_math/vector_math_64.dart';
import 'light.dart';

class IBL {
  String? iblPath;
  final double iblIntensity;

  IBL(this.iblIntensity);
}

class DirectLight {
  final LightType type;
  final double color;
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
    required this.color,
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
  double color = 6500,
  double intensity = 100000,
  bool castShadows = false,
  Vector3? position,
  double falloffRadius = 1.0,
}) : this(
  type: LightType.POINT,
  color: color,
  intensity: intensity,
  castShadows: castShadows,
  position: position ?? Vector3(0, 1, 0),
  direction: Vector3.zero(),
  falloffRadius: falloffRadius,
);

DirectLight.sun({
  double color = 6500,
  double intensity = 100000,
  bool castShadows = true,
  Vector3? direction,
  double sunAngularRadius = 0.545,
  double sunHaloSize = 10.0,
  double sunHaloFalloff = 80.0,
}) : this(
  type: LightType.DIRECTIONAL,
  color: color,
  intensity: intensity,
  castShadows: castShadows,
  position: Vector3(0, 0, 0),  
  direction: direction ?? Vector3(0, -1, 0),
  sunAngularRadius: sunAngularRadius,
  sunHaloSize: sunHaloSize,
  sunHaloFallof: sunHaloFalloff,
);
}

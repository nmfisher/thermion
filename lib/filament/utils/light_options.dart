import 'package:vector_math/vector_math_64.dart' as v;

class LightOptions {
  String? iblPath;
  double iblIntensity;
  int directionalType;
  double directionalColor;
  double directionalIntensity;
  bool directionalCastShadows;
  late v.Vector3 directionalPosition;
  late v.Vector3 directionalDirection;

  LightOptions(
      {required this.iblPath,
      required this.iblIntensity,
      required this.directionalType,
      required this.directionalColor,
      required this.directionalIntensity,
      required this.directionalCastShadows,
      v.Vector3? directionalDirection,
      v.Vector3? directionalPosition}) {
    this.directionalDirection = directionalDirection == null
        ? v.Vector3(0, -1, 0)
        : directionalDirection;
    this.directionalPosition = directionalPosition == null
        ? v.Vector3(0, 100, 0)
        : directionalPosition;
  }
}

import 'package:vector_math/vector_math_64.dart';

enum LightType {
  SUN, //!< Directional light that also draws a sun's disk in the sky.
  DIRECTIONAL, //!< Directional light, emits light in a given direction.
  POINT, //!< Point light, emits light from a position, in all directions.
  FOCUSED_SPOT, //!< Physically correct spot light.
  SPOT,
}

abstract class IndirectLight {
  Future destroy() {
    throw UnimplementedError();
  }

  Future rotate(Matrix3 rotation) {
    throw UnimplementedError();
  }
}

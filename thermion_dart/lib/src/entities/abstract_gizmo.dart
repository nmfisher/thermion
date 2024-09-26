import 'package:vector_math/vector_math_64.dart';

import '../../thermion_dart.dart';

abstract class AbstractGizmo {
  
  bool get isVisible;
  bool get isHovered;

  Future translate(double transX, double transY);

  void reset();

  Future attach(ThermionEntity entity);

  Future detach();

  Stream<Aabb2> get boundingBox;

  void checkHover(double x, double y);
}

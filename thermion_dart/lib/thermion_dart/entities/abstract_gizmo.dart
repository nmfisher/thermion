


import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:vector_math/vector_math_64.dart';

abstract class AbstractGizmo {
  bool get isActive;

  void translate(double transX, double transY);

  void reset();

  void attach(ThermionEntity entity);

  void detach();

  Aabb2 boundingBox = Aabb2();

  void checkHover(double x, double y) { 
    if(boundingBox.containsVector2(Vector2(x, y)));
  }
}

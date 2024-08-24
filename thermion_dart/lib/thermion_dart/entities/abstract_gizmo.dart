import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:vector_math/vector_math_64.dart';

abstract class AbstractGizmo {
  bool get isActive;

  void translate(double transX, double transY);

  void reset();

  void attach(ThermionEntity entity);

  void detach();

  Stream<Aabb2> get boundingBox;

  void checkHover(double x, double y);
}

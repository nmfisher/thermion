import 'package:vector_math/vector_math_64.dart';

abstract class Camera {

  Future setProjectionMatrixWithCulling(Matrix4 projectionMatrix, double near, double far);
  
}


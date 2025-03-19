import 'package:vector_math/vector_math_64.dart';

class CameraOrientation {
  Vector3 position = Vector3.zero();
  Vector3 rotation = Vector3.zero();

  Matrix4 compose() {
    final quat = Quaternion.axisAngle(Vector3(0, 0, 1), rotation.z) *
        Quaternion.axisAngle(Vector3(0, 1, 0), rotation.y) *
        Quaternion.axisAngle(Vector3(1, 0, 0), rotation.x);
    return Matrix4.compose(position, quat, Vector3.all(1));
  }
}

import 'package:vector_math/vector_math_64.dart' as v;

class CameraOrientation {
  v.Vector3 position = v.Vector3(0, 0, 0);

  var rotationX = 0.0;
  var rotationY = 0.0;
  var rotationZ = 0.0;

  v.Quaternion compose() {
    return v.Quaternion.axisAngle(v.Vector3(0, 0, 1), rotationZ) *
        v.Quaternion.axisAngle(v.Vector3(0, 1, 0), rotationY) *
        v.Quaternion.axisAngle(v.Vector3(1, 0, 0), rotationX);
  }
}

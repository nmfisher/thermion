import 'dart:ffi';

import 'package:thermion_dart/thermion_dart/utils/matrix.dart';
import 'package:thermion_dart/thermion_dart/viewer/ffi/src/thermion_dart.g.dart';
import 'package:thermion_dart/thermion_dart/viewer/shared_types/camera.dart';
import 'package:vector_math/vector_math_64.dart';

class ThermionFFICamera extends Camera {
  final Pointer<TCamera> pointer;

  ThermionFFICamera(this.pointer);

  @override
  Future setProjectionMatrixWithCulling(Matrix4 projectionMatrix,
      double near, double far) async {
    Camera_setCustomProjectionWithCulling(
        pointer,
        matrix4ToDouble4x4(projectionMatrix),
        near,
        far);
  }
}

import 'package:thermion_dart/thermion_dart/viewer/shared_types/camera.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../thermion_viewer_base.dart';

class ThermionWasmCamera extends Camera {
  
  final int pointer;

  ThermionWasmCamera(this.pointer);
  
  @override
  Future setProjectionMatrixWithCulling(
      Matrix4 projectionMatrix, double near, double far) {
    // TODO: implement setProjectionMatrixWithCulling
    throw UnimplementedError();
  }
  
  @override
  Future<Matrix4> getModelMatrix() {
    // TODO: implement getModelMatrix
    throw UnimplementedError();
  }
  
  @override
  Future setLensProjection({double near = kNear, double far = kFar, double aspect = 1.0, double focalLength = kFocalLength}) {
    // TODO: implement setLensProjection
    throw UnimplementedError();
  }
  
  @override
  Future setTransform(Matrix4 transform) {
    // TODO: implement setTransform
    throw UnimplementedError();
  }
}

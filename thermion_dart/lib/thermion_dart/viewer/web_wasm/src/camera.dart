import 'package:thermion_dart/thermion_dart/viewer/shared_types/camera.dart';
import 'package:vector_math/vector_math_64.dart';

class ThermionWasmCamera extends Camera {
  
  final int pointer;

  ThermionWasmCamera(this.pointer);
  
  @override
  Future setProjectionMatrixWithCulling(
      Matrix4 projectionMatrix, double near, double far) {
    // TODO: implement setProjectionMatrixWithCulling
    throw UnimplementedError();
  }
}

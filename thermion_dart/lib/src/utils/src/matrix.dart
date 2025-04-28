// Helper function to convert double4x4 to Matrix4
import 'package:thermion_dart/src/bindings/bindings.dart';
import 'package:vector_math/vector_math_64.dart';
import 'dart:ffi';

Matrix4 double4x4ToMatrix4(double4x4 mat) {
  return Matrix4.fromList([
    mat.col1[0],
    mat.col1[1],
    mat.col1[2],
    mat.col1[3],
    mat.col2[0],
    mat.col2[1],
    mat.col2[2],
    mat.col2[3],
    mat.col3[0],
    mat.col3[1],
    mat.col3[2],
    mat.col3[3],
    mat.col4[0],
    mat.col4[1],
    mat.col4[2],
    mat.col4[3],
  ]);
}

double4x4 matrix4ToDouble4x4(Matrix4 mat) {
  final out = Struct.create<double4x4>();

  for (int i = 0; i < 4; i++) {
    out.col1[i] = mat.storage[i];
    out.col2[i] = mat.storage[i + 4];
    out.col3[i] = mat.storage[i + 8];
    out.col4[i] = mat.storage[i + 12];
  }

  return out;
}

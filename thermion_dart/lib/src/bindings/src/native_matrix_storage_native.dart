import 'dart:ffi';
import 'dart:typed_data';
import 'thermion_dart_ffi.g.dart';

(Pointer<TMat4>, Float64List) allocateNativeMatrixStorage() {
  final owner = Mat4_create();
  return (owner, Mat4_getData(owner).asTypedList(16));
}

import 'dart:ffi';
import 'dart:typed_data';
import 'thermion_dart_ffi.g.dart';

(Pointer<TNativeMatrix4>, Float64List) allocateNativeMatrixStorage() {
  final owner = NativeMatrix4_create();
  return (owner, NativeMatrix4_getData(owner).asTypedList(16));
}

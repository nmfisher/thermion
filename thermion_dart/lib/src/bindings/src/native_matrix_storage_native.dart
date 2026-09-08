import 'dart:ffi';
import 'dart:typed_data';
import 'thermion_dart_ffi.g.dart';

Float64List nativeMatrixStorage(Pointer<TMat4> owner) => Mat4_getData(owner).asTypedList(16);

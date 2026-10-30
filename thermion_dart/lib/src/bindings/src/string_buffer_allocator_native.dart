import 'dart:ffi';
import 'package:ffi/ffi.dart';

Pointer<Char> allocate(int lengthInBytes) => calloc.allocate<Char>(lengthInBytes);
void free(Pointer<Char> buffer) => calloc.free(buffer);

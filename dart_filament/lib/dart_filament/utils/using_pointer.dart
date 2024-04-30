import 'dart:ffi';

import 'package:ffi/ffi.dart';

final allocator = calloc;

void using(Pointer ptr, Future Function(Pointer ptr) function) async {
  await function.call(ptr);
  allocator.free(ptr);
}

import 'dart:js_interop';
import 'package:ffigen_js/ffigen_js.dart';

extension type _Allocator(NativeLibrary _) implements JSObject {
  external int _malloc(int lengthInBytes);
  external void _free(int address);
}

// These buffers belong to Dart and use the module's allocator for both calls.
Pointer<Char> allocate(int lengthInBytes) =>
    Pointer<Char>.fromAddress(_Allocator(NativeLibrary.instance)._malloc(lengthInBytes));
void free(Pointer<Char> buffer) => _Allocator(NativeLibrary.instance)._free(buffer.address);

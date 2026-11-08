import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';

T withNativeBuffer<T>(TypedData data, T Function(Pointer<Uint8>) operation, {bool copyBack = false}) =>
    throw UnsupportedError('Native buffers require FFI or JavaScript interop.');

/// Heap storage is unavailable on this platform.
extension TypedDataPass on TypedData {
  Future<T> pass<T>(FutureOr<T> Function(Uint8List data) operation) =>
      throw UnsupportedError('HeapBuffer requires native FFI or JavaScript interop.');

  Future<T> passOutput<T>(FutureOr<T> Function(Uint8List data) operation) =>
      throw UnsupportedError('HeapBuffer requires native FFI or JavaScript interop.');
}

extension TypedDataListPass on List<TypedData> {
  Future<T> pass<T>(FutureOr<T> Function(List<Uint8List> data) operation) =>
      throw UnsupportedError('HeapBuffer requires native FFI or JavaScript interop.');
}

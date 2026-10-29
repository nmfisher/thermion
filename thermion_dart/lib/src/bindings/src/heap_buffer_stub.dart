import 'dart:async';
import 'dart:typed_data';

/// Heap storage is unavailable on this platform.
extension TypedDataPass on TypedData {
  Future<T> pass<T>(FutureOr<T> Function(Uint8List data) operation) =>
      throw UnsupportedError('HeapBuffer requires native FFI or JavaScript interop.');
}

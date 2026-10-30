import 'dart:convert';
import 'bindings.dart';

/// Reads UTF-8 text into a buffer owned by Dart.
///
/// [read] must complete after native code has stopped using the buffer. Its
/// result is the required byte count, including the null terminator, or zero
/// for null. If the buffer is too small, native code must leave it unchanged.
/// If [read] fails, native code must no longer hold the buffer.
/// The read is retried with a larger buffer. Keep the source alive and unchanged
/// across all attempts.
///
/// Each buffer lives in native/Wasm heap memory until [read] completes. It is
/// freed in `finally`, including when reading or UTF-8 decoding throws.
Future<String?> readString(Future<int> Function(Pointer<Char> buffer, int capacity) read) async {
  var capacity = 256;
  while (true) {
    final buffer = allocate<Char>(capacity);
    if (buffer == nullptr) throw StateError('String buffer allocation failed');
    try {
      final requiredBytes = await read(buffer, capacity);
      if (requiredBytes == 0) return null;
      if (requiredBytes <= capacity) {
        return utf8.decode(buffer.cast<Uint8>().asTypedList(requiredBytes - 1));
      }
      capacity = requiredBytes;
    } finally {
      free(buffer);
    }
  }
}

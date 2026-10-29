import 'dart:async';
import 'dart:typed_data';

/// Provides byte views for a callback. Do not retain or return those views.
extension TypedDataPass on TypedData {
  /// Borrows this data without copying it. Take addresses only in leaf FFI calls.
  Future<T> pass<T>(FutureOr<T> Function(Uint8List data) operation) async {
    final bytes = buffer.asUint8List(offsetInBytes, lengthInBytes);
    return await operation(bytes);
  }
}

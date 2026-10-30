import 'dart:async';
import 'dart:typed_data';

/// Provides byte views for a callback. Do not retain or return those views.
extension TypedDataPass on TypedData {
  /// Borrows this data without copying it. Take addresses only in leaf FFI calls.
  Future<T> pass<T>(FutureOr<T> Function(Uint8List data) operation) async {
    final bytes = buffer.asUint8List(offsetInBytes, lengthInBytes);
    return await operation(bytes);
  }

  /// Writes directly into this output storage.
  Future<T> passOutput<T>(FutureOr<T> Function(Uint8List data) operation) => pass(operation);
}

/// Callback byte views are borrowed. Do not retain or return them.
extension TypedDataListPass on List<TypedData> {
  /// Borrows every input without copying it.
  Future<T> pass<T>(FutureOr<T> Function(List<Uint8List> data) operation) async {
    final bytes = [for (final source in this) source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes)];
    return await operation(bytes);
  }
}

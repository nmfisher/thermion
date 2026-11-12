import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

/// Copies a view into stable native storage for one synchronous FFI call.
/// Unlike TypedData.address, this is safe when the native call can block and
/// Dart's GC can run. The operation must not retain or return the pointer.
T withNativeBuffer<T>(
  TypedData data,
  T Function(ffi.Pointer<ffi.Uint8>) operation, {
  bool copyIn = true,
  bool copyBack = false,
}) {
  final pointer = calloc<ffi.Uint8>(data.lengthInBytes == 0 ? 1 : data.lengthInBytes);
  try {
    final source = (copyIn || copyBack) ? data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes) : null;
    final storage = (copyIn || copyBack) ? pointer.asTypedList(data.lengthInBytes) : null;
    if (copyIn) storage!.setAll(0, source!);
    final result = operation(pointer);
    if (copyBack) source!.setAll(0, storage!);
    return result;
  } finally {
    calloc.free(pointer);
  }
}

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

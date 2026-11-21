import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:ffigen_js/ffigen_js.dart';

extension type _Heap(NativeLibrary _) implements JSObject {
  external int _malloc(int bytes);
  external void _free(int address);
  external JSUint8Array get HEAPU8;
}

/// Provides byte views for a callback. Do not retain or return those views.
extension TypedDataPass on TypedData {
  /// Copies this data into a temporary buffer in Filament's Wasm heap.
  ///
  /// Ordinary Dart typed data is outside Filament's Wasm memory. Filament needs
  /// an address in that memory, so we copy the bytes. We use the heap because
  /// large inputs can exhaust the Emscripten stack.
  ///
  /// [operation] receives a byte view of the copy. The allocation stays alive
  /// until the callback and any returned Future finish. It is freed in `finally`,
  /// including when copying or the callback throws.
  ///
  /// Do not retain or return the view or its address.
  Future<T> pass<T>(FutureOr<T> Function(Uint8List data) operation) async {
    final storage = _HeapBuffer(lengthInBytes);
    try {
      storage.data.setAll(0, buffer.asUint8List(offsetInBytes, lengthInBytes));
      return await operation(storage.data);
    } finally {
      storage.dispose();
    }
  }

  /// Copies completed output here before freeing the Wasm storage.
  Future<T> passOutput<T>(FutureOr<T> Function(Uint8List data) operation) async {
    final storage = _HeapBuffer(lengthInBytes);
    try {
      final result = await operation(storage.data);
      buffer.asUint8List(offsetInBytes, lengthInBytes).setAll(0, storage.data);
      return result;
    } finally {
      storage.dispose();
    }
  }
}

/// Callback byte views are borrowed. Do not retain or return them.
extension TypedDataListPass on List<TypedData> {
  /// Allocates all inputs before forming views, then frees them after the callback.
  Future<T> pass<T>(FutureOr<T> Function(List<Uint8List> data) operation) async {
    final storage = <_HeapBuffer>[];
    try {
      for (final source in this) {
        final input = _HeapBuffer(source.lengthInBytes);
        storage.add(input);
        input.data.setAll(0, source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes));
      }
      // A later allocation may grow Wasm memory and replace the backing buffer.
      final bytes = [for (final input in storage) input.data];
      return await operation(bytes);
    } finally {
      for (final input in storage) {
        input.dispose();
      }
    }
  }
}

class _HeapBuffer {
  _HeapBuffer(this.lengthInBytes) : _heap = _Heap(NativeLibrary.instance) {
    _address = _heap._malloc(lengthInBytes == 0 ? 1 : lengthInBytes);
    if (_address == 0) throw StateError('WebAssembly allocation failed');
  }

  final int lengthInBytes;
  final _Heap _heap;
  late final int _address;
  // Refresh the view after allocations that may grow the Wasm memory.
  Uint8List get data => _heap.HEAPU8.toDart.buffer.asUint8List(_address, lengthInBytes);
  void dispose() {
    _heap._free(_address);
  }
}

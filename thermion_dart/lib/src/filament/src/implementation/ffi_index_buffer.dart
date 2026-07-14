import 'dart:typed_data';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import '../../../bindings/bindings.dart' as bindings;
import 'package:thermion_dart/thermion_dart.dart';

/// FFI implementation of IndexBuffer for native platforms.
class FFIIndexBuffer extends IndexBuffer {
  final bindings.Pointer<bindings.TIndexBuffer> _ptr;
  final bindings.Pointer<bindings.TEngine> _engine;

  FFIIndexBuffer(this._ptr, this._engine);

  /// Returns the native handle for FFI calls.
  bindings.Pointer<bindings.TIndexBuffer> getNativeHandle() => _ptr;

  @override
  int getIndexCount() {
    return bindings.IndexBuffer_getIndexCount(_ptr);
  }

  @override
  Future setBuffer(TypedData data, {int byteOffset = 0}) async {
    final byteData = data.asUint8List();
    await withVoidCallback((requestId, cb) {
      bindings.IndexBuffer_setBufferRenderThread(
        _engine,
        _ptr,
        byteData.address.cast(),
        byteData.length,
        byteOffset,
        requestId,
        cb,
      );
    });
  }

  @override
  Future destroy() async {
    await withVoidCallback((requestId, cb) {
      bindings.IndexBuffer_destroyRenderThread(_engine, _ptr, requestId, cb);
    });
  }
}

/// FFI implementation of IndexBufferBuilder for native platforms.
class FFIIndexBufferBuilder implements IndexBufferBuilder {
  bindings.Pointer<bindings.TIndexBufferBuilder>? _builderPtr;
  final bindings.Pointer<bindings.TEngine> _engine;
  bool _isBuilt = false;

  FFIIndexBufferBuilder(this._engine) {
    _builderPtr = bindings.IndexBufferBuilder_create();
  }

  void _checkNotBuilt() {
    if (_isBuilt) {
      throw StateError('Builder has already been built and cannot be reused');
    }
    if (_builderPtr == null || _builderPtr == bindings.nullptr) {
      throw StateError('Builder pointer is null');
    }
  }

  @override
  void indexCount(int count) {
    _checkNotBuilt();
    bindings.IndexBufferBuilder_indexCount(_builderPtr!, count);
  }

  @override
  void bufferType(IndexType type) {
    _checkNotBuilt();
    final typeValue = type == IndexType.USHORT
        ? bindings.TIndexType.TINDEX_TYPE_USHORT
        : bindings.TIndexType.TINDEX_TYPE_UINT;
    bindings.IndexBufferBuilder_bufferType(_builderPtr!, typeValue);
  }

  @override
  Future<IndexBuffer> build() async {
    _checkNotBuilt();

    final indexBufferPtr = await withPointerCallback<bindings.TIndexBuffer>(
      (cb) => bindings.IndexBufferBuilder_buildRenderThread(
        _builderPtr!,
        _engine,
        cb,
      ),
    );

    bindings.IndexBufferBuilder_destroy(_builderPtr!);
    _builderPtr = null;
    _isBuilt = true;

    if (indexBufferPtr == bindings.nullptr) {
      throw Exception('Failed to build IndexBuffer');
    }

    return FFIIndexBuffer(indexBufferPtr, _engine);
  }
}

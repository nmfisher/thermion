import '../../../bindings/bindings.dart' as bindings;
import 'package:thermion_dart/thermion_dart.dart';

class FFIBufferObject extends BufferObject {
  final bindings.Pointer<bindings.TBufferObject> _ptr;
  final bindings.Pointer<bindings.TEngine> _engine;

  FFIBufferObject(this._ptr, this._engine);

  bindings.Pointer<bindings.TBufferObject> getNativeHandle() => _ptr;

  bool isOwnedBy(bindings.Pointer<bindings.TEngine> engine) => _engine == engine;

  @override
  Future<void> setBuffer(TypedData data, {int byteOffset = 0}) async {
    final bytes = data.asUint8List();
    await withVoidCallback((requestId, cb) {
      bindings.BufferObject_setBufferRenderThread(
        _engine,
        _ptr,
        bytes.address.cast(),
        bytes.lengthInBytes,
        byteOffset,
        requestId,
        cb,
      );
    });
  }

  @override
  Future<void> destroy() async {
    await withVoidCallback((requestId, cb) {
      bindings.BufferObject_destroyRenderThread(_engine, _ptr, requestId, cb);
    });
  }
}

class FFIBufferObjectBuilder implements BufferObjectBuilder {
  bindings.Pointer<bindings.TBufferObjectBuilder>? _builder;
  final bindings.Pointer<bindings.TEngine> _engine;
  bool _built = false;

  FFIBufferObjectBuilder(this._engine) {
    _builder = bindings.BufferObjectBuilder_create();
  }

  void _checkNotBuilt() {
    if (_built || _builder == null || _builder == bindings.nullptr) {
      throw StateError('BufferObjectBuilder has already been built');
    }
  }

  @override
  void size(int sizeInBytes) {
    _checkNotBuilt();
    if (sizeInBytes <= 0) {
      throw ArgumentError.value(sizeInBytes, 'sizeInBytes', 'must be positive');
    }
    bindings.BufferObjectBuilder_size(_builder!, sizeInBytes);
  }

  @override
  Future<BufferObject> build() async {
    _checkNotBuilt();
    final pointer = await withPointerCallback<bindings.TBufferObject>(
      (cb) => bindings.BufferObjectBuilder_buildRenderThread(_builder!, _engine, cb),
    );
    bindings.BufferObjectBuilder_destroy(_builder!);
    _builder = null;
    _built = true;
    if (pointer == bindings.nullptr) {
      throw StateError('Failed to build BufferObject');
    }
    return FFIBufferObject(pointer, _engine);
  }
}

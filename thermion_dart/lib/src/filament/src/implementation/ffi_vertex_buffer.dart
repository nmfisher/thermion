import '../../../bindings/bindings.dart' as bindings;
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_buffer_object.dart';

/// FFI implementation of VertexBuffer for native platforms.
class FFIVertexBuffer extends VertexBuffer {
  final bindings.Pointer<bindings.TVertexBuffer> _ptr;
  final bindings.Pointer<bindings.TEngine> _engine;

  @override
  final bool ownsResource;

  FFIVertexBuffer(this._ptr, this._engine, {this.ownsResource = true});

  /// Returns the native handle for FFI calls.
  bindings.Pointer<bindings.TVertexBuffer> getNativeHandle() => _ptr;

  @override
  int getVertexCount() {
    return bindings.VertexBuffer_getVertexCount(_ptr);
  }

  @override
  VertexBufferStorageMode get storageMode => switch (bindings.VertexBuffer_getStorageMode(_ptr)) {
    bindings.TVertexBufferStorageMode.VERTEX_BUFFER_STORAGE_MODE_DIRECT => VertexBufferStorageMode.direct,
    bindings.TVertexBufferStorageMode.VERTEX_BUFFER_STORAGE_MODE_BUFFER_OBJECTS =>
      VertexBufferStorageMode.bufferObjects,
    _ => VertexBufferStorageMode.unknown,
  };

  @override
  Future setBufferAt(int bufferIndex, TypedData data, {int byteOffset = 0}) async {
    if (storageMode != VertexBufferStorageMode.direct) {
      throw StateError(
        'VertexBuffer.setBufferAt requires direct storage. Build the buffer '
        'without enableBufferObjects(), or load glTF assets with '
        'vertexBufferMode: VertexBufferMode.editable.',
      );
    }
    final byteData = data.asUint8List();
    await withVoidCallback((requestId, cb) {
      bindings.VertexBuffer_setBufferAtRenderThread(
        _engine,
        _ptr,
        bufferIndex,
        byteData.address.cast(),
        byteData.lengthInBytes,
        byteOffset,
        requestId,
        cb,
      );
    });
  }

  @override
  Future<void> setBufferObjectAt(int bufferIndex, BufferObject bufferObject) async {
    if (storageMode != VertexBufferStorageMode.bufferObjects) {
      throw StateError(
        'VertexBuffer.setBufferObjectAt requires BufferObject-backed storage. '
        'Call VertexBufferBuilder.enableBufferObjects() before build().',
      );
    }
    if (bufferObject is! FFIBufferObject) {
      throw ArgumentError.value(bufferObject, 'bufferObject', 'must be created by this Filament backend');
    }
    if (!bufferObject.isOwnedBy(_engine)) {
      throw ArgumentError.value(bufferObject, 'bufferObject', 'must belong to the same Filament engine');
    }
    await withVoidCallback((requestId, cb) {
      bindings.VertexBuffer_setBufferObjectAtRenderThread(
        _engine,
        _ptr,
        bufferIndex,
        bufferObject.getNativeHandle(),
        requestId,
        cb,
      );
    });
  }

  @override
  Future destroy() async {
    if (!ownsResource) {
      throw StateError('Cannot destroy a VertexBuffer borrowed from a ThermionAsset');
    }
    await withVoidCallback((requestId, cb) {
      bindings.VertexBuffer_destroyRenderThread(_engine, _ptr, requestId, cb);
    });
  }
}

/// FFI implementation of VertexBufferBuilder for native platforms.
class FFIVertexBufferBuilder implements VertexBufferBuilder {
  bindings.Pointer<bindings.TVertexBufferBuilder>? _builderPtr;
  final bindings.Pointer<bindings.TEngine> _engine;
  bool _isBuilt = false;

  FFIVertexBufferBuilder(this._engine) {
    _builderPtr = bindings.VertexBufferBuilder_create();
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
  void bufferCount(int count) {
    _checkNotBuilt();
    bindings.VertexBufferBuilder_bufferCount(_builderPtr!, count);
  }

  @override
  void vertexCount(int count) {
    _checkNotBuilt();
    bindings.VertexBufferBuilder_vertexCount(_builderPtr!, count);
  }

  @override
  void enableBufferObjects({bool enabled = true}) {
    _checkNotBuilt();
    bindings.VertexBufferBuilder_enableBufferObjects(_builderPtr!, enabled);
  }

  @override
  void attribute(
    VertexAttribute attribute,
    int bufferIndex,
    VertexAttributeType attributeType, {
    int byteOffset = 0,
    int byteStride = 0,
  }) {
    _checkNotBuilt();

    final attributeValue = _vertexAttributeToInt(attribute);
    final typeValue = _vertexAttributeTypeToInt(attributeType);

    bindings.VertexBufferBuilder_attribute(
      _builderPtr!,
      attributeValue,
      bufferIndex,
      typeValue,
      byteOffset,
      byteStride,
    );
  }

  @override
  void normalized(VertexAttribute attribute, {bool normalize = true}) {
    _checkNotBuilt();
    final attributeValue = _vertexAttributeToInt(attribute);
    bindings.VertexBufferBuilder_normalized(_builderPtr!, attributeValue, normalize);
  }

  @override
  Future<VertexBuffer> build() async {
    _checkNotBuilt();

    final vertexBufferPtr = await withPointerCallback<bindings.TVertexBuffer>(
      (cb) => bindings.VertexBufferBuilder_buildRenderThread(_builderPtr!, _engine, cb),
    );

    bindings.VertexBufferBuilder_destroy(_builderPtr!);
    _builderPtr = null;
    _isBuilt = true;

    if (vertexBufferPtr == bindings.nullptr) {
      throw Exception('Failed to build VertexBuffer');
    }

    return FFIVertexBuffer(vertexBufferPtr, _engine);
  }

  int _vertexAttributeToInt(VertexAttribute attribute) {
    return switch (attribute) {
      VertexAttribute.POSITION => 0,
      VertexAttribute.TANGENTS => 1,
      VertexAttribute.COLOR => 2,
      VertexAttribute.UV0 => 3,
      VertexAttribute.UV1 => 4,
      VertexAttribute.BONE_INDICES => 5,
      VertexAttribute.BONE_WEIGHTS => 6,
      VertexAttribute.CUSTOM0 => 8,
      VertexAttribute.CUSTOM1 => 9,
      VertexAttribute.CUSTOM2 => 10,
      VertexAttribute.CUSTOM3 => 11,
      VertexAttribute.CUSTOM4 => 12,
      VertexAttribute.CUSTOM5 => 13,
      VertexAttribute.CUSTOM6 => 14,
      VertexAttribute.CUSTOM7 => 15,
    };
  }

  int _vertexAttributeTypeToInt(VertexAttributeType type) {
    return switch (type) {
      VertexAttributeType.BYTE => 0, // TVERTEXATTRIBUTE_TYPE_BYTE
      VertexAttributeType.BYTE2 => 1, // TVERTEXATTRIBUTE_TYPE_BYTE2
      VertexAttributeType.BYTE3 => 2, // TVERTEXATTRIBUTE_TYPE_BYTE3
      VertexAttributeType.BYTE4 => 3, // TVERTEXATTRIBUTE_TYPE_BYTE4
      VertexAttributeType.UBYTE => 4, // TVERTEXATTRIBUTE_TYPE_UBYTE
      VertexAttributeType.UBYTE2 => 5, // TVERTEXATTRIBUTE_TYPE_UBYTE2
      VertexAttributeType.UBYTE3 => 6, // TVERTEXATTRIBUTE_TYPE_UBYTE3
      VertexAttributeType.UBYTE4 => 7, // TVERTEXATTRIBUTE_TYPE_UBYTE4
      VertexAttributeType.SHORT => 8, // TVERTEXATTRIBUTE_TYPE_SHORT
      VertexAttributeType.SHORT2 => 9, // TVERTEXATTRIBUTE_TYPE_SHORT2
      VertexAttributeType.SHORT3 => 10, // TVERTEXATTRIBUTE_TYPE_SHORT3
      VertexAttributeType.SHORT4 => 11, // TVERTEXATTRIBUTE_TYPE_SHORT4
      VertexAttributeType.USHORT => 12, // TVERTEXATTRIBUTE_TYPE_USHORT
      VertexAttributeType.USHORT2 => 13, // TVERTEXATTRIBUTE_TYPE_USHORT2
      VertexAttributeType.USHORT3 => 14, // TVERTEXATTRIBUTE_TYPE_USHORT3
      VertexAttributeType.USHORT4 => 15, // TVERTEXATTRIBUTE_TYPE_USHORT4
      VertexAttributeType.INT => 16, // TVERTEXATTRIBUTE_TYPE_INT
      VertexAttributeType.UINT => 17, // TVERTEXATTRIBUTE_TYPE_UINT
      VertexAttributeType.FLOAT => 18, // TVERTEXATTRIBUTE_TYPE_FLOAT
      VertexAttributeType.FLOAT2 => 19, // TVERTEXATTRIBUTE_TYPE_FLOAT2
      VertexAttributeType.FLOAT3 => 20, // TVERTEXATTRIBUTE_TYPE_FLOAT3
      VertexAttributeType.FLOAT4 => 21, // TVERTEXATTRIBUTE_TYPE_FLOAT4
      VertexAttributeType.HALF => 22, // TVERTEXATTRIBUTE_TYPE_HALF
      VertexAttributeType.HALF2 => 23, // TVERTEXATTRIBUTE_TYPE_HALF2
      VertexAttributeType.HALF3 => 24, // TVERTEXATTRIBUTE_TYPE_HALF3
      VertexAttributeType.HALF4 => 25, // TVERTEXATTRIBUTE_TYPE_HALF4
    };
  }
}

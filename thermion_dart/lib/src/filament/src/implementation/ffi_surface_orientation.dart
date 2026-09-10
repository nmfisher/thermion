import 'dart:typed_data';
import '../../../bindings/bindings.dart' as bindings;
import '../interface/surface_orientation.dart';

/// FFI implementation of SurfaceOrientation for native platforms.
class FFISurfaceOrientation extends SurfaceOrientation {
  final bindings.Pointer<bindings.TSurfaceOrientation> _ptr;

  FFISurfaceOrientation(this._ptr);

  /// Returns the native handle for FFI calls.
  bindings.Pointer<bindings.TSurfaceOrientation> getNativeHandle() => _ptr;

  @override
  int getVertexCount() {
    return bindings.SurfaceOrientation_getVertexCount(_ptr);
  }

  @override
  Future<TypedData> getQuats(QuaternionFormat format, int quatCount, {int stride = 0}) async {
    // Calculate buffer size based on format
    final elementSize = switch (format) {
      QuaternionFormat.FLOAT4 => 16, // 4 floats * 4 bytes
      QuaternionFormat.SHORT4 => 8, // 4 shorts * 2 bytes
      QuaternionFormat.HALF4 => 8, // 4 halfs * 2 bytes
    };

    final bufferSize = quatCount * elementSize;

    // Allocate buffer for output
    final output = switch (format) {
      QuaternionFormat.FLOAT4 => bindings.makeFloat32List(bufferSize ~/ 4),
      QuaternionFormat.SHORT4 => bindings.makeInt16List(bufferSize ~/ 2),
      QuaternionFormat.HALF4 => bindings.makeUint16List(bufferSize ~/ 2),
    };

    final outputBytes = output.asUint8List();
    switch (format) {
      case QuaternionFormat.FLOAT4:
        bindings.SurfaceOrientation_getQuats_float4(_ptr, outputBytes.address.cast(), quatCount, stride);
        break;
      case QuaternionFormat.SHORT4:
        bindings.SurfaceOrientation_getQuats_short4(_ptr, outputBytes.address.cast(), quatCount, stride);
        break;
      case QuaternionFormat.HALF4:
        bindings.SurfaceOrientation_getQuats_half4(_ptr, outputBytes.address.cast(), quatCount, stride);
        break;
    }

    return output;
  }

  @override
  Future<void> destroy() async {
    bindings.SurfaceOrientation_destroy(_ptr);
  }
}

/// FFI implementation of SurfaceOrientationBuilder for native platforms.
class FFISurfaceOrientationBuilder implements SurfaceOrientationBuilder {
  bool _isBuilt = false;
  int _vertexCount = 0;
  int _triangleCount = 0;
  Float32List? _normals, _tangents, _uvs, _positions;
  Uint32List? _triangles32;
  Uint16List? _triangles16;
  int _normalStride = 0, _tangentStride = 0, _uvStride = 0, _positionStride = 0;
  static final _emptyFloats = Float32List(0);
  static final _emptyIndices32 = Uint32List(0);
  static final _emptyIndices16 = Uint16List(0);

  void _checkNotBuilt() {
    if (_isBuilt) {
      throw StateError('Builder has already been built and cannot be reused');
    }
  }

  @override
  void vertexCount(int count) {
    _checkNotBuilt();
    _vertexCount = count;
  }

  @override
  void normals(Float32List normals, {int stride = 0}) {
    _checkNotBuilt();
    _normals = normals;
    _normalStride = stride;
  }

  @override
  void tangents(Float32List tangents, {int stride = 0}) {
    _checkNotBuilt();
    _tangents = tangents;
    _tangentStride = stride;
  }

  @override
  void uvs(Float32List uvs, {int stride = 0}) {
    _checkNotBuilt();
    _uvs = uvs;
    _uvStride = stride;
  }

  @override
  void positions(Float32List positions, {int stride = 0}) {
    _checkNotBuilt();
    _positions = positions;
    _positionStride = stride;
  }

  @override
  void triangleCount(int count) {
    _checkNotBuilt();
    _triangleCount = count;
  }

  @override
  void trianglesUint32(Uint32List triangles) {
    _checkNotBuilt();
    _triangles32 = triangles;
  }

  @override
  void trianglesUint16(Uint16List triangles) {
    _checkNotBuilt();
    _triangles16 = triangles;
  }

  @override
  Future<SurfaceOrientation> build() async {
    _checkNotBuilt();

    // Optional inputs use empty lists so every .address stays a direct FFI
    // argument. Their zero lengths tell native code to omit those inputs.
    // Web needs temporary WASM views; native Dart borrows the retained lists.
    final stack = bindings.FILAMENT_WASM ? bindings.stackSave() : bindings.nullptr;
    Float32List floatInput(Float32List? input) {
      final data = input ?? _emptyFloats;
      return bindings.FILAMENT_WASM ? (bindings.makeFloat32List(data.length)..setAll(0, data)) : data;
    }

    try {
      final normals = floatInput(_normals);
      final tangents = floatInput(_tangents);
      final uvs = floatInput(_uvs);
      final positions = floatInput(_positions);
      final indices32 = _triangles32 ?? _emptyIndices32;
      final indices16 = _triangles16 ?? _emptyIndices16;
      final triangles32 = bindings.FILAMENT_WASM
          ? (bindings.makeUint32List(indices32.length)..setAll(0, indices32))
          : indices32;
      final triangles16 = bindings.FILAMENT_WASM
          ? (bindings.makeUint16List(indices16.length)..setAll(0, indices16))
          : indices16;
      final orientationPtr = bindings.SurfaceOrientation_build(
        _vertexCount,
        normals.address,
        normals.length,
        _normalStride,
        tangents.address,
        tangents.length,
        _tangentStride,
        uvs.address,
        uvs.length,
        _uvStride,
        positions.address,
        positions.length,
        _positionStride,
        _triangleCount,
        triangles32.address,
        triangles32.length,
        triangles16.address,
        triangles16.length,
      );
      _isBuilt = true;
      _normals = _tangents = _uvs = _positions = null;
      _triangles32 = null;
      _triangles16 = null;
      return FFISurfaceOrientation(orientationPtr);
    } finally {
      // All input reads finish before returning; no stack storage spans an await.
      if (bindings.FILAMENT_WASM) bindings.stackRestore(stack);
    }
  }
}

import 'dart:typed_data';
import 'package:logging/logging.dart';
import '../../../bindings/bindings.dart' as bindings;
import '../interface/surface_orientation.dart';

/// FFI implementation of SurfaceOrientation for native platforms.
class FFISurfaceOrientation extends SurfaceOrientation {
  final bindings.Pointer<bindings.TSurfaceOrientation> _ptr;
  late final _logger = Logger('FFISurfaceOrientation');

  FFISurfaceOrientation(this._ptr);

  /// Returns the native handle for FFI calls.
  bindings.Pointer<bindings.TSurfaceOrientation> getNativeHandle() => _ptr;

  @override
  int getVertexCount() {
    return bindings.SurfaceOrientation_getVertexCount(_ptr);
  }

  @override
  Future<TypedData> getQuats(
    QuaternionFormat format,
    int quatCount, {
    int stride = 0,
  }) async {
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

    // Get pointer to output data
    final outputBytes = output.asUint8List();

    // Call appropriate C function based on format
    switch (format) {
      case QuaternionFormat.FLOAT4:
        bindings.SurfaceOrientation_getQuats_float4(
          _ptr,
          outputBytes.address.cast(),
          quatCount,
          stride,
        );
        break;
      case QuaternionFormat.SHORT4:
        bindings.SurfaceOrientation_getQuats_short4(
          _ptr,
          outputBytes.address.cast(),
          quatCount,
          stride,
        );
        break;
      case QuaternionFormat.HALF4:
        bindings.SurfaceOrientation_getQuats_half4(
          _ptr,
          outputBytes.address.cast(),
          quatCount,
          stride,
        );
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
  bindings.Pointer<bindings.TSurfaceOrientationBuilder>? _builderPtr;
  bool _isBuilt = false;

  FFISurfaceOrientationBuilder() {
    _builderPtr = bindings.SurfaceOrientationBuilder_create();
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
  void vertexCount(int count) {
    _checkNotBuilt();
    bindings.SurfaceOrientationBuilder_vertexCount(_builderPtr!, count);
  }

  @override
  void normals(Float32List normals, {int stride = 0}) {
    _checkNotBuilt();
    final byteData = normals.asUint8List();
    bindings.SurfaceOrientationBuilder_normals(
      _builderPtr!,
      byteData.address.cast<bindings.Float>(),
      stride,
    );
  }

  @override
  void tangents(Float32List tangents, {int stride = 0}) {
    _checkNotBuilt();
    final byteData = tangents.asUint8List();
    bindings.SurfaceOrientationBuilder_tangents(
      _builderPtr!,
      byteData.address.cast<bindings.Float>(),
      stride,
    );
  }

  @override
  void uvs(Float32List uvs, {int stride = 0}) {
    _checkNotBuilt();
    final byteData = uvs.asUint8List();
    bindings.SurfaceOrientationBuilder_uvs(
      _builderPtr!,
      byteData.address.cast<bindings.Float>(),
      stride,
    );
  }

  @override
  void positions(Float32List positions, {int stride = 0}) {
    _checkNotBuilt();
    final byteData = positions.asUint8List();
    bindings.SurfaceOrientationBuilder_positions(
      _builderPtr!,
      byteData.address.cast<bindings.Float>(),
      stride,
    );
  }

  @override
  void triangleCount(int count) {
    _checkNotBuilt();
    bindings.SurfaceOrientationBuilder_triangleCount(_builderPtr!, count);
  }

  @override
  void trianglesUint32(Uint32List triangles) {
    _checkNotBuilt();
    final byteData = triangles.asUint8List();
    bindings.SurfaceOrientationBuilder_triangles_uint(
      _builderPtr!,
      byteData.address.cast<bindings.Uint32>(),
    );
  }

  @override
  void trianglesUint16(Uint16List triangles) {
    _checkNotBuilt();
    final byteData = triangles.asUint8List();
    bindings.SurfaceOrientationBuilder_triangles_ushort(
      _builderPtr!,
      byteData.address.cast<bindings.Uint16>(),
    );
  }

  @override
  Future<SurfaceOrientation> build() async {
    _checkNotBuilt();

    final orientationPtr = bindings.SurfaceOrientationBuilder_build(
      _builderPtr!,
    );

    bindings.SurfaceOrientationBuilder_destroy(_builderPtr!);
    _builderPtr = null;
    _isBuilt = true;

    return FFISurfaceOrientation(orientationPtr);
  }
}

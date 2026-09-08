import 'package:vector_math/vector_math_64.dart';
import '../../../bindings/bindings.dart';
import '../../../bindings/native_matrix_storage.dart';

/// Internal owner of a C++ `mat4` whose storage is shared with Dart (or WASM memory on web).
///
/// Use [matrix] to edit the values, and the internal FFI camera/transform methods
/// to pass the constructed C++ object without a boundary copy. Ordinary matrix
/// methods keep their existing snapshot semantics.
///
/// Call [dispose] when finished. The [matrix] view, its storage and any derived
/// views must not be accessed after disposal. There is deliberately no GC
/// finalizer: an escaped view must never silently become dangling because the
/// owner wrapper was collected. Keep the owner until all views are finished.
class NativeMatrix4 {
  Pointer<TNativeMatrix4>? _handle;
  final Matrix4 _matrix;

  NativeMatrix4._(Pointer<TNativeMatrix4> handle, Float64List storage)
    : _handle = handle,
      _matrix = Matrix4.fromFloat64List(storage);

  /// Allocates and constructs an identity matrix in native memory.
  factory NativeMatrix4.identity() {
    final (owner, storage) = allocateNativeMatrixStorage();
    return NativeMatrix4._(owner, storage);
  }

  factory NativeMatrix4.zero() => NativeMatrix4.identity()..matrix.setZero();

  /// Allocates shared storage and copies [other] once during initialization.
  factory NativeMatrix4.copy(Matrix4 other) => NativeMatrix4.identity()..matrix.setFrom(other);

  bool get isDisposed => _handle == null;

  /// A reusable view of the same values that C++ reads and writes.
  ///
  /// Do not mutate any view while a native queued setter is pending. Cloning
  /// this Matrix4 produces an ordinary independent Dart-owned matrix.
  Matrix4 get matrix {
    getNativeHandle();
    return _matrix;
  }

  Pointer<TNativeMatrix4> getNativeHandle() => _handle ?? (throw StateError('NativeMatrix4 has been disposed'));

  /// Releases this owner. Pending native submissions retain their own owner.
  /// All Dart views become invalid immediately. Repeated disposal is harmless.
  void dispose() {
    final handle = _handle;
    if (handle == null) return;
    _handle = null;
    NativeMatrix4_destroy(handle);
  }
}

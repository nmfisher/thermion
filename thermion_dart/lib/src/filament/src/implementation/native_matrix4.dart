import 'package:vector_math/vector_math_64.dart';
import '../../../bindings/bindings.dart';
import '../../../bindings/native_matrix_storage.dart';
import 'allocate_native_matrix.dart';

/// Internal owner of a C++ `mat4` whose storage is shared with Dart (or WASM memory on web).
///
/// Use [matrix] to edit the values, and the internal FFI camera/transform methods
/// to pass the constructed C++ object without a boundary copy. Ordinary matrix
/// methods keep their existing snapshot semantics.
///
/// Call [dispose] when finished. The [matrix] view, its storage and any derived
/// views must not be accessed after disposal. There is deliberately no GC
/// finalizer: an escaped view must never silently become dangling because the
/// owner wrapper was collected. Keep the owner until all views and queued uses
/// are finished.
class NativeMatrix4 {
  Pointer<TMat4>? _handle;
  final Matrix4 _matrix;
  int _pendingUses = 0;

  NativeMatrix4._(Pointer<TMat4> handle, Float64List storage)
    : _handle = handle,
      _matrix = Matrix4.fromFloat64List(storage);

  /// Allocates and constructs an identity matrix in native memory.
  factory NativeMatrix4.identity() =>
      allocateNativeMatrix((owner) => NativeMatrix4._(owner, nativeMatrixStorage(owner)));

  factory NativeMatrix4.zero() =>
      allocateNativeMatrix((owner) => NativeMatrix4._(owner, nativeMatrixStorage(owner)).._matrix.setZero());

  /// Allocates shared storage and copies [other] once during initialization.
  factory NativeMatrix4.copy(Matrix4 other) =>
      allocateNativeMatrix((owner) => NativeMatrix4._(owner, nativeMatrixStorage(owner)).._matrix.setFrom(other));

  bool get isDisposed => _handle == null;

  /// A reusable view of the same values that C++ reads and writes.
  ///
  /// Do not mutate or dispose while a native queued setter is pending. Cloning
  /// this Matrix4 produces an ordinary independent Dart-owned matrix.
  Matrix4 get matrix {
    getNativeHandle();
    if (_pendingUses != 0) throw StateError('NativeMatrix4 is in use by queued operations');
    return _matrix;
  }

  Pointer<TMat4> getNativeHandle() => _handle ?? (throw StateError('NativeMatrix4 has been disposed'));

  /// Retains this owner and prevents disposal until [submit] completes, including
  /// on dispatch failure. Multiple read-only submissions may share this owner.
  /// Previously obtained views must not be accessed while a use is pending.
  Future<void> withQueuedUse(Future<void> Function(Pointer<TMat4>) submit) async {
    final handle = getNativeHandle();
    _pendingUses++;
    try {
      await submit(handle);
    } finally {
      _pendingUses--;
    }
  }

  /// Deletes the native matrix. All queued uses must have completed first.
  /// All Dart views become invalid immediately. Repeated disposal is harmless.
  void dispose() {
    final handle = _handle;
    if (handle == null) return;
    if (_pendingUses != 0) throw StateError('Cannot dispose NativeMatrix4 with queued operations pending');
    _handle = null;
    Mat4_destroy(handle);
  }
}

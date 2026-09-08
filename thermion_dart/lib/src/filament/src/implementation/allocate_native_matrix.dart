import '../../../bindings/bindings.dart';

// Ownership transfers only after initialization succeeds. Injected allocation
// functions let the failure paths be tested without exhausting native memory.
T allocateNativeMatrix<T>(
  T Function(Pointer<TMat4>) initialize, {
  Pointer<TMat4> Function() create = Mat4_create,
  void Function(Pointer<TMat4>) destroy = Mat4_destroy,
}) {
  final handle = create();
  if (handle == nullptr) throw StateError('Failed to allocate native matrix');
  try {
    return initialize(handle);
  } catch (_) {
    destroy(handle);
    rethrow;
  }
}

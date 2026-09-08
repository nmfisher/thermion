import 'dart:async';
import 'package:thermion_dart/src/bindings/bindings.dart';
import 'package:thermion_dart/src/bindings/native_matrix_storage.dart';
import 'package:thermion_dart/src/filament/src/implementation/allocate_native_matrix.dart';
import 'package:thermion_dart/src/filament/src/implementation/native_matrix4.dart';

void rejectsStateError(void Function() action) {
  try {
    action();
  } on StateError {
    return;
  }
  throw StateError('Expected StateError');
}

Future<void> checkNativeMatrixLifetimes() async {
  var created = 0;
  var destroyed = 0;
  Pointer<TMat4> create() {
    final handle = Mat4_create();
    if (handle == nullptr) throw StateError('Test allocation failed');
    created++;
    return handle;
  }

  void destroy(Pointer<TMat4> handle) {
    Mat4_destroy(handle);
    destroyed++;
  }

  // Count real C allocations and frees through the factory's ownership-transfer
  // helper, including an exception after creating the platform storage view.
  for (var i = 0; i < 5000; i++) {
    if (i.isEven) {
      final handle = allocateNativeMatrix(
        (handle) {
          nativeMatrixStorage(handle)[12] = i.toDouble();
          return handle;
        },
        create: create,
        destroy: destroy,
      );
      destroy(handle);
    } else {
      rejectsStateError(
        () => allocateNativeMatrix<void>(
          (handle) {
            nativeMatrixStorage(handle);
            throw StateError('Injected view initialization failure');
          },
          create: create,
          destroy: destroy,
        ),
      );
    }
    if (created != destroyed) throw StateError('Unbalanced native allocations at iteration $i');
  }
  rejectsStateError(
    () => allocateNativeMatrix<void>(
      (_) => throw ArgumentError('Null allocation reached initializer'),
      create: () => nullptr,
      destroy: (_) => throw ArgumentError('Null allocation was freed'),
    ),
  );

  final matrix = NativeMatrix4.identity();
  final first = Completer<void>();
  final second = Completer<void>();
  final firstUse = matrix.withQueuedUse((_) => first.future);
  final secondUse = matrix.withQueuedUse((_) => second.future);
  try {
    rejectsStateError(matrix.dispose);
    rejectsStateError(() => matrix.matrix);
    first.complete();
    await firstUse;
    // One completion must not release a second outstanding reader.
    rejectsStateError(matrix.dispose);
    second.complete();
    await secondUse;
    matrix.matrix.setIdentity();

    for (final submit in <Future<void> Function(Pointer<TMat4>)>[
      (_) => throw StateError('Dispatch failed before enqueue'),
      (_) => Future<void>.error(StateError('Completion failed')),
    ]) {
      var rejected = false;
      try {
        await matrix.withQueuedUse(submit);
      } on StateError {
        rejected = true;
      }
      if (!rejected) throw StateError('Submission failure was swallowed');
      matrix.matrix.setIdentity(); // No pending use leaked after either failure.
    }
  } finally {
    if (!first.isCompleted) first.complete();
    if (!second.isCompleted) second.complete();
    await Future.wait([firstUse, secondUse]);
    matrix.dispose();
    matrix.dispose();
  }
  rejectsStateError(() => matrix.matrix);
  var disposedRejected = false;
  try {
    await matrix.withQueuedUse((_) => throw ArgumentError('Disposed matrix dispatched'));
  } on StateError {
    disposedRejected = true;
  }
  if (!disposedRejected) throw StateError('Disposed matrix accepted queued use');

  for (var i = 0; i < 1000; i++) {
    final owner = NativeMatrix4.identity();
    try {
      await owner.withQueuedUse((_) async {});
    } finally {
      owner.dispose();
    }
  }
}

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'task_error_registry.dart';
import 'thermion_dart_ffi.g.dart';

final _errorCallback = NativeCallable<Void Function(Uint32, Pointer<Char>)>.listener((
  int requestId,
  Pointer<Char> message,
) {
  try {
    nativeTaskErrors.fail(
      requestId,
      message == nullptr ? 'Native render task failed' : message.cast<Utf8>().toDartString(),
    );
  } finally {
    RenderThread_freeErrorMessage(message);
  }
});

final TaskErrorRegistry nativeTaskErrors = TaskErrorRegistry(
  install: (requestId) => RenderThread_setTaskErrorCallback(requestId, _errorCallback.nativeFunction),
  clear: () => RenderThread_setTaskErrorCallback(0, nullptr),
);

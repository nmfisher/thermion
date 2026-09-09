import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'task_error_registry.dart';
import 'thermion_dart_ffi.g.dart';

// Reuse the trampoline for the isolate's lifetime, including late/duplicate
// errors (the registry ignores retired IDs and the callback still frees their
// messages). Pending requests keep the isolate alive; an idle listener does not
// prevent CLI programs from exiting. Native workers must be stopped before the
// owning isolate is explicitly killed. Closing a live trampoline is unsafe.
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
})..keepIsolateAlive = false;

final TaskErrorRegistry nativeTaskErrors = TaskErrorRegistry(
  install: (requestId) => RenderThread_setTaskErrorCallback(requestId, _errorCallback.nativeFunction),
  clear: () => RenderThread_setTaskErrorCallback(0, nullptr),
  onPendingChanged: (active) => _errorCallback.keepIsolateAlive = active,
);

import 'dart:async';
import 'dart:typed_data';

import 'thermion_dart_js_interop.g.dart';
import 'task_error_registry.dart';
import 'dart:js_interop';

export 'dart:typed_data';

export 'thermion_dart_js_interop.g.dart';
export 'dart:js_interop';
export 'dart:js_interop_unsafe';

const FILAMENT_SINGLE_THREADED = true;
const FILAMENT_WASM = true;
const IS_WINDOWS = false;

extension type _NativeLibrary(NativeLibrary _) implements JSObject {
  static _NativeLibrary get instance => NativeLibrary.instance as _NativeLibrary;

  external void _execute_queue();
}

typedef IntPtrList = Int32List;
typedef Utf8 = Char;
typedef Float = Float32;
typedef Double = Float64;
typedef Bool = bool;

class FinalizableUint8List {
  final Pointer name;
  final Uint8List data;

  FinalizableUint8List(this.name, this.data);
}

class CallbackHolder<T extends Function> {
  final Pointer<NativeFunction<T>> pointer;

  CallbackHolder(this.pointer);

  void dispose() {
    pointer.dispose();
  }
}

extension DPCF on DartPickCallbackFunction {
  CallbackHolder<DartPickCallbackFunction> asCallback() {
    final ptr = addFunction<DartPickCallbackFunction>(this.toJS, "viiffff");
    final cbh = CallbackHolder(ptr);
    return cbh;
  }
}

extension GPFBP on void Function(int, double, double, double) {
  CallbackHolder<GizmoPickCallbackFunction> asCallback() {
    final ptr = addFunction<GizmoPickCallbackFunction>(this.toJS, "viddd");
    return CallbackHolder(ptr);
  }
}

extension VFCB on void Function() {
  CallbackHolder<void Function()> asCallback() {
    final ptr = addFunction<void Function()>(this.toJS, "v");
    return CallbackHolder(ptr);
  }
}

final _taskErrors = TaskErrorRegistry(
  install: (requestId) => RenderThread_setTaskErrorCallback(requestId, _taskErrorCallbackPtr.cast()),
  clear: () => RenderThread_setTaskErrorCallback(0, nullptr),
);

void _taskFailed(int requestId, Pointer<Char> message) {
  try {
    _taskErrors.fail(requestId, message == nullptr ? 'Native render task failed' : message.cast<Utf8>().toDartString());
  } finally {
    RenderThread_freeErrorMessage(message);
  }
}

final _taskErrorCallbackPtr = addFunction<RenderTaskErrorCallbackFunction>(_taskFailed.toJS, 'vip');

int _lastRequestId = 0;
final _completers = <int, Completer<void>>{};
void _completeVoid(int requestId) {
  final completer = _completers.remove(requestId);
  if (completer != null && !completer.isCompleted) completer.complete();
}

final _voidCallbackPtr = _completeVoid.addFunction();

/// Drives the native proxying queue until the pending request settles. The
/// task-error scope observes a failure while this loop is still running, so a
/// failed request rejects instead of waiting for a completion that never comes.
Future<void> _pollUntil(Completer<void> completer) async {
  while (!completer.isCompleted) {
    _NativeLibrary.instance._execute_queue();
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

Future<T> _dispatch<T>(Completer<T> completer, FutureOr<void> Function() call) {
  return _taskErrors.invoke(completer, () {
    final result = call();
    return result is Future<void> ? result : _pollUntil(completer);
  });
}

Future<void> withVoidCallback(Function(int, Pointer<NativeFunction<Void Function(int)>>) func) async {
  while (_completers.containsKey(_lastRequestId)) {
    _lastRequestId = (_lastRequestId + 1) & 0x7fffffff;
  }
  final requestId = _lastRequestId;
  _lastRequestId = (_lastRequestId + 1) & 0x7fffffff;
  final completer = Completer<void>();
  _completers[requestId] = completer;

  try {
    await _dispatch(completer, () => func.call(requestId, _voidCallbackPtr.cast()));
  } finally {
    _completers.remove(requestId);
  }
}

Future<Pointer<T>> withPointerCallback<T extends NativeType>(
  Function(Pointer<NativeFunction<Void Function(Pointer<T>)>>) func,
) async {
  final completer = Completer<Pointer<T>>();
  void callback(Pointer<T> ptr) => completer.complete(ptr.cast<T>());

  final onComplete_interopFnPtr = callback.addFunction();

  try {
    return await _dispatch(completer, () => func.call(onComplete_interopFnPtr.cast()));
  } finally {
    onComplete_interopFnPtr.dispose();
  }
}

Future<bool> withBoolCallback(Function(Pointer<NativeFunction<Void Function(Bool)>>) func) async {
  final completer = Completer<bool>();
  void callback(int result) => completer.complete(result == 1);

  final onComplete_interopFnPtr = callback.addFunction();

  return _dispatch(completer, () => func.call(onComplete_interopFnPtr.cast()));
}

Future<double> withFloatCallback(void Function(Pointer<NativeFunction<void Function(double)>>) func) async {
  final completer = Completer<double>();
  void callback(double result) => completer.complete(result);
  final ptr = callback.addFunction();
  return _dispatch(completer, () => func.call(ptr));
}

Future<int> withIntCallback(Function(Pointer<NativeFunction<void Function(int)>>) func) async {
  final completer = Completer<int>();
  void callback(int result) => completer.complete(result);
  final ptr = callback.addFunction();
  return _dispatch(completer, () => func.call(ptr));
}

Pointer<T> allocate<T extends NativeType>(int byteCount) {
  switch (T) {
    case PointerClass:
    case Char:
      return malloc(byteCount);
    default:
      throw Exception(T.toString());
  }
}

Future<int> withUInt32Callback(Function(Pointer<NativeFunction<Void Function(int)>>) func) async {
  final completer = Completer<int>();
  void callback(int result) => completer.complete(result);
  final ptr = callback.addFunction();
  return _dispatch(completer, () => func.call(ptr.cast()));
}

Future<String> withCharPtrCallback(Function(Pointer<NativeFunction<Void Function(Pointer<Char>)>>) func) async {
  final completer = Completer<String>();
  void callback(Pointer<Char> result) => completer.complete(result.cast<Utf8>().toDartString());
  final ptr = callback.addFunction();
  return _dispatch(completer, () => func.call(ptr.cast()));
}

extension DartBigIntExtension on int {
  BigInt get toBigInt {
    return BigInt.from(this);
  }
}

Pointer stackSave() => NativeLibrary.instance.stackSave();

void stackRestore(Pointer ptr) => NativeLibrary.instance.stackRestore(ptr.cast());

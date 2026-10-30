import 'dart:async';
import 'dart:typed_data';

import 'thermion_dart_js_interop.g.dart';
import 'dart:js_interop';

export 'dart:typed_data';

export 'thermion_dart_js_interop.g.dart';
export 'dart:js_interop';
export 'dart:js_interop_unsafe';

const FILAMENT_SINGLE_THREADED = true;
const FILAMENT_WASM = true;
const IS_WINDOWS = false;

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

int _lastRequestId = 0;
final _completers = <int, Completer>{};
void Function(int) _voidCallback = (int requestId) {
  _completers[requestId]!.complete();
  _completers.remove(requestId);
};

final _voidCallbackPtr = _voidCallback.addFunction();

Future<void> withVoidCallback(Function(int, Pointer<NativeFunction<Void Function(int)>>) func) async {
  final completer = Completer();
  var requestId = _lastRequestId;
  _lastRequestId++;

  _completers[requestId] = completer;

  try {
    func.call(requestId, _voidCallbackPtr.cast());
  } catch (_) {
    _completers.remove(requestId);
    rethrow;
  }
  await completer.future;
}

Future<Pointer<T>> withPointerCallback<T extends NativeType>(
  Function(Pointer<NativeFunction<Void Function(Pointer<T>)>>) func,
) async {
  final completer = Completer<Pointer<T>>();
  // ignore: prefer_function_declarations_over_variables
  void Function(Pointer<T>) callback = (Pointer<T> ptr) {
    completer.complete(ptr.cast<T>());
  };

  final onComplete_interopFnPtr = callback.addFunction();

  try {
    func.call(onComplete_interopFnPtr.cast());

    return await completer.future;
  } finally {
    onComplete_interopFnPtr.dispose();
  }
}

/// Reads one owned, null-terminated UTF-8 string from [func].
///
/// The native function must call the callback exactly once, with null or a
/// string allocated for this result by Thermion. The callback takes ownership.
/// Do not pass borrowed strings, stack memory or Dart-allocated buffers.
/// This helper copies the text and calls StringCallback_free, even if decoding
/// fails. Null produces null.
///
/// Native FFI listeners run later. Keep the allocation valid and unchanged
/// until this helper frees it. [func] may throw only before handing the callback
/// to native code.
Future<String?> withStringCallback(Function(Pointer<NativeFunction<Void Function(Pointer<Char>)>>) func) async {
  final completer = Completer<String?>();
  void callback(Pointer<Char> text) {
    try {
      completer.complete(text == nullptr ? null : text.cast<Utf8>().toDartString());
    } catch (error, stack) {
      completer.completeError(error, stack);
    } finally {
      if (text != nullptr) StringCallback_free(text);
    }
  }

  final pointer = callback.addFunction();
  try {
    func.call(pointer.cast());
    return await completer.future;
  } finally {
    pointer.dispose();
  }
}

Future<bool> withBoolCallback(Function(Pointer<NativeFunction<Void Function(Bool)>>) func) async {
  final completer = Completer<bool>();
  // ignore: prefer_function_declarations_over_variables
  void Function(int) callback = (int result) {
    completer.complete(result == 1);
  };

  final onComplete_interopFnPtr = callback.addFunction();

  try {
    func.call(onComplete_interopFnPtr.cast());

    return await completer.future;
  } finally {
    onComplete_interopFnPtr.dispose();
  }
}

Future<double> withFloatCallback(void Function(Pointer<NativeFunction<void Function(double)>>) func) async {
  final completer = Completer<double>();
  // ignore: prefer_function_declarations_over_variables
  void Function(double) callback = (double result) {
    completer.complete(result);
  };
  var ptr = callback.addFunction();
  try {
    func.call(ptr);
    return await completer.future;
  } finally {
    ptr.dispose();
  }
}

Future<int> withIntCallback(Function(Pointer<NativeFunction<void Function(int)>>) func) async {
  final completer = Completer<int>();
  // ignore: prefer_function_declarations_over_variables
  void Function(int) callback = (int result) {
    completer.complete(result);
  };
  var ptr = callback.addFunction();
  try {
    func.call(ptr);
    return await completer.future;
  } finally {
    ptr.dispose();
  }
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
  // ignore: prefer_function_declarations_over_variables
  void Function(int) callback = (int result) {
    completer.complete(result);
  };
  final ptr = callback.addFunction();
  try {
    func.call(ptr.cast());
    return await completer.future;
  } finally {
    ptr.dispose();
  }
}

Future<String> withCharPtrCallback(Function(Pointer<NativeFunction<Void Function(Pointer<Char>)>>) func) async {
  throw UnimplementedError();
}

extension DartBigIntExtension on int {
  BigInt get toBigInt {
    return BigInt.from(this);
  }
}

Pointer stackSave() => NativeLibrary.instance.stackSave();

void stackRestore(Pointer ptr) => NativeLibrary.instance.stackRestore(ptr.cast());

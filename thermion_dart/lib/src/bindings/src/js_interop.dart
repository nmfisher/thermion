import 'dart:async';
export 'dart:typed_data';

export 'thermion_dart_js_interop.g.dart';
export 'dart:js_interop';
export 'dart:js_interop_unsafe';
import 'package:thermion_dart/src/bindings/src/js_interop.dart';

const FILAMENT_SINGLE_THREADED = true;
const FILAMENT_WASM = true;
const IS_WINDOWS = false;

Int32List makeInt32List(int length) {
  var ptr = malloc<Int32>(length * 4);
  var buf = _NativeLibrary.instance._emscripten_make_int32_buffer(ptr, length);
  return buf.toDart;
}

extension type _NativeLibrary(JSObject _) implements JSObject {
  static _NativeLibrary get instance =>
      NativeLibrary.instance as _NativeLibrary;

  external JSUint8Array _emscripten_make_uint8_buffer(
      Pointer<Uint8> ptr, int length);
  external JSUint16Array _emscripten_make_uint16_buffer(
      Pointer<Uint16> ptr, int length);
  external JSInt16Array _emscripten_make_int16_buffer(
      Pointer<Int16> ptr, int length);
  external JSInt32Array _emscripten_make_int32_buffer(
      Pointer<Int32> ptr, int length);
  external JSFloat32Array _emscripten_make_f32_buffer(
      Pointer<Float32> ptr, int length);
  external JSFloat64Array _emscripten_make_f64_buffer(
      Pointer<Float64> ptr, int length);
  external Pointer _emscripten_get_byte_offset(JSObject obj);

  external int _emscripten_stack_get_free();

  external void _execute_queue();

  @JS('stackSave')
  external Pointer<Void> stackSave();

  @JS('stackRestore')
  external void stackRestore(Pointer<Void> ptr);
}

extension FreeTypedData<T> on TypedData {
  void free() {
    final ptr = Pointer<Void>(this.offsetInBytes);
    ptr.free();
  }
}

Pointer<T> getPointer<T extends NativeType>(TypedData data, JSObject obj) {
  late Pointer<T> ptr;

  if (data.lengthInBytes < 32 * 1024) {
    ptr = stackAlloc(data.lengthInBytes).cast<T>();
  } else {
    ptr = malloc<T>(data.lengthInBytes);
  }

  return ptr;
}

extension JSBackingBuffer on JSUint8Array {
  @JS('buffer')
  external JSObject buffer;
}

@JS('Uint8Array')
extension type Uint8ArrayWrapper._(JSObject _) implements JSObject {
  external Uint8ArrayWrapper(JSObject buffer, int offset, int length);
}

@JS('Int8Array')
extension type Int8ArrayWrapper._(JSObject _) implements JSObject {
  external Int8ArrayWrapper(JSObject buffer, int offset, int length);
}

@JS('Uint16Array')
extension type Uint16ArrayWrapper._(JSObject _) implements JSObject {
  external Uint16ArrayWrapper(JSObject buffer, int offset, int length);
}

@JS('Int16Array')
extension type Int16ArrayWrapper._(JSObject _) implements JSObject {
  external Int16ArrayWrapper(JSObject buffer, int offset, int length);
}

@JS('Uint32Array')
extension type Uint32ArrayWrapper._(JSObject _) implements JSObject {
  external Uint32ArrayWrapper(JSObject buffer, int offset, int length);
}

@JS('Int32Array')
extension type Int32ArrayWrapper._(JSObject _) implements JSObject {
  external Int32ArrayWrapper(JSObject buffer, int offset, int length);
}

@JS('Float32Array')
extension type Float32ArrayWrapper._(JSObject _) implements JSObject {
  external Float32ArrayWrapper(JSObject buffer, int offset, int length);
}
@JS('Float64Array')
extension type Float64ArrayWrapper._(JSObject _) implements JSObject {
  external Float64ArrayWrapper(JSObject buffer, int offset, int length);
}

extension Uint8ListExtension on Uint8List {
  Pointer<Uint8> get address {
    if (this.lengthInBytes == 0) {
      return nullptr;
    }
    final ptr = getPointer<Uint8>(this, this.toJS);
    final bar =
        Uint8ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, ptr, length)
            as JSUint8Array;
    bar.toDart.setRange(0, length, this);
    return ptr;
  }
}

extension Float32ListExtension on Float32List {
  Pointer<Float32> get address {
    final ptr = getPointer<Float32>(this, this.toJS);
    final bar =
        Float32ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, ptr, length)
            as JSFloat32Array;
    bar.toDart.setRange(0, length, this);
    return ptr;
  }
}

extension Int16ListExtension on Int16List {
  Pointer<Int16> get address {
    if (this.lengthInBytes == 0) {
      return nullptr;
    }
    final ptr = getPointer<Int16>(this, this.toJS);
    final bar = Int16ArrayWrapper(NativeLibrary.instance.HEAPU8, ptr, length)
        as JSInt16Array;
    bar.toDart.setRange(0, length, this);
    return ptr;
  }
}

extension Uint16ListExtension on Uint16List {
  Pointer<Uint16> get address {
    final ptr = getPointer<Uint16>(this, this.toJS);
    final bar =
        Uint16ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, ptr, length)
            as JSUint16Array;
    bar.toDart.setRange(0, length, this);
    return ptr;
  }
}

extension UInt32ListExtension on Uint32List {
  Pointer<Uint32> get address {
    if (this.lengthInBytes == 0) {
      return nullptr;
    }
    final ptr = getPointer<Uint32>(this, this.toJS);
    final bar =
        Uint32ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, ptr, length)
            as JSUint32Array;
    bar.toDart.setRange(0, length, this);
    return ptr;
  }
}

extension Int32ListExtension on Int32List {
  Pointer<Int32> get address {
    if (this.lengthInBytes == 0) {
      return nullptr;
    }
    try {
      this.buffer.asUint8List(this.offsetInBytes);
      final ptr = getPointer<Int32>(this, this.toJS);
      final bar =
          Int32ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, ptr, length)
              as JSInt32Array;
      bar.toDart.setRange(0, length, this);
      return ptr;
    } catch (_) {
      return Pointer<Int32>(this.offsetInBytes);
    }
  }
}

extension Int64ListExtension on Int64List {
  Pointer<Float32> get address {
    throw Exception();
  }

  static Int64List create(int length) {
    throw Exception();
  }
}

extension Float64ListExtension on Float64List {
  Pointer<Float64> get address {
    if (this.lengthInBytes == 0) {
      return nullptr;
    }
    final ptr = getPointer<Float64>(this, this.toJS);
    final bar =
        Float64ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, ptr, length)
            as JSFloat64Array;
    bar.toDart.setRange(0, length, this);
    return ptr;
  }
}

extension AsFloat32List on Pointer<Float> {
  Float32List asTypedList(int length) {
    final start = addr;
    final wrapper =
        Float32ArrayWrapper(NativeLibrary.instance.HEAPU8.buffer, start, length)
            as JSFloat32Array;
    return wrapper.toDart;
  }
}

int sizeOf<T extends NativeType>() {
  switch (T) {
    case Float:
      return 4;
    default:
      throw Exception();
  }
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

final _completers = <int, Completer>{};
void Function(int) _voidCallback = (int requestId) {
  _completers[requestId]!.complete();
  _completers.remove(requestId);
};

final _voidCallbackPtr = _voidCallback.addFunction();

Future<void> withVoidCallback(
    Function(int, Pointer<NativeFunction<Void Function(int)>>) func) async {
  final completer = Completer();
  final requestId = _completers.length;
  _completers[requestId] = completer;

  func.call(requestId, _voidCallbackPtr.cast());
  while (!completer.isCompleted) {
    _NativeLibrary.instance._execute_queue();
    await Future.delayed(Duration(milliseconds: 1));
  }
  await completer.future;
}

Future<Pointer<T>> withPointerCallback<T extends NativeType>(
    Function(Pointer<NativeFunction<Void Function(Pointer<T>)>>) func) async {
  final completer = Completer<Pointer<T>>();
  // ignore: prefer_function_declarations_over_variables
  void Function(Pointer<T>) callback = (Pointer<T> ptr) {
    completer.complete(ptr.cast<T>());
  };

  final onComplete_interopFnPtr = callback.addFunction();

  func.call(onComplete_interopFnPtr.cast());

  var ptr = await completer.future;
  onComplete_interopFnPtr.dispose();

  return ptr;
}

Future<bool> withBoolCallback(
    Function(Pointer<NativeFunction<Void Function(Bool)>>) func) async {
  final completer = Completer<bool>();
  // ignore: prefer_function_declarations_over_variables
  void Function(int) callback = (int result) {
    completer.complete(result == 1);
  };

  final onComplete_interopFnPtr = callback.addFunction();

  func.call(onComplete_interopFnPtr.cast());
  await completer.future;

  return completer.future;
}

Future<double> withFloatCallback(
    void Function(Pointer<NativeFunction<void Function(double)>>) func) async {
  final completer = Completer<double>();
  // ignore: prefer_function_declarations_over_variables
  void Function(double) callback = (double result) {
    completer.complete(result);
  };
  var ptr = callback.addFunction();
  func.call(ptr);
  await completer.future;
  return completer.future;
}

Future<int> withIntCallback(
    Function(Pointer<NativeFunction<Void Function(Int32)>>) func) async {
  final completer = Completer<int>();
  // ignore: prefer_function_declarations_over_variables
  void Function(int) callback = (int result) {
    completer.complete(result);
  };
  // final nativeCallable =
  //     NativeCallable<Void Function(Int32)>.listener(callback);
  // func.call(nativeCallable.nativeFunction);
  await completer.future;
  // nativeCallable.close();
  return completer.future;
}

Pointer<T> allocate<T extends NativeType>(int count) {
  switch (T) {
    case PointerClass:
      return malloc(count * 4);
    default:
      throw Exception(T.toString());
  }
}

Future<int> withUInt32Callback(
    Function(Pointer<NativeFunction<Void Function(int)>>) func) async {
  final completer = Completer<int>();
  // ignore: prefer_function_declarations_over_variables
  void Function(int) callback = (int result) {
    completer.complete(result);
  };
  final ptr = callback.addFunction();
  func.call(ptr.cast());
  await completer.future;
  return completer.future;
}

Future<String> withCharPtrCallback(
    Function(Pointer<NativeFunction<Void Function(Pointer<Char>)>>)
        func) async {
  final completer = Completer<String>();
  // ignore: prefer_function_declarations_over_variables
  // void Function(Pointer<Char>) callback = (Pointer<Char> result) {
  //   completer.complete(result.cast<Utf8>().toDartString());
  // };
  // final nativeCallable =
  //     NativeCallable<Void Function(Pointer<Char>)>.listener(callback);
  // func.call(nativeCallable.nativeFunction);
  await completer.future;
  // nativeCallable.close();
  return completer.future;
}

extension DartBigIntExtension on int {
  BigInt get toBigInt {
    return BigInt.from(this);
  }
}

Pointer stackSave() => _NativeLibrary.instance.stackSave();

void stackRestore(Pointer ptr) =>
    _NativeLibrary.instance.stackRestore(ptr.cast());

void getStackFree() {
  print(_NativeLibrary.instance._emscripten_stack_get_free());
}

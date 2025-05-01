import 'dart:async';
import 'dart:js_interop';

export 'dart:typed_data';

export 'thermion_dart_js_interop.g.dart';
export 'dart:js_interop';
export 'dart:js_interop_unsafe';
import 'package:thermion_dart/src/bindings/src/js_interop.dart';

T makeTypedData<T extends TypedData>(int length) {
  TypedData typedData = switch(T) {
    Uint8List => Uint8ListExtension.create(length),
    Int16List => Int16ListExtension.create(length),
    Int32List => Int32ListExtension.create(length),
    Int64List => throw UnimplementedError(),
    Float32List => Float32ListExtension.create(length),
    Float64List => Float64ListExtension.create(length),
    _ => throw UnimplementedError()
  };
  return typedData as T;
}

T makeTypedDataFromIntList<T extends TypedData>(List<int> src) {
  TypedDataList typedData = switch(T) {
    Uint8List => Uint8ListExtension.create(src.length),
    Uint16List => Uint16ListExtension.create(src.length),
    Int16List => Int16ListExtension.create(src.length),
    Int32List => Int32ListExtension.create(src.length),
    _ => throw UnimplementedError()
  };
  typedData.setRange(0, src.length, src);

  return typedData as T;
}


T makeTypedDataFromDoubleList<T extends TypedData>(List<double> src) {
  TypedDataList typedData = switch(T) {
    Float32List => Float32ListExtension.create(src.length),
    Float64List => Float64ListExtension.create(src.length),
    _ => throw UnimplementedError()
  };
  typedData.setRange(0, src.length, src);

  return typedData as T;
}

extension type _NativeLibrary(JSObject _) implements JSObject {

  static _NativeLibrary get instance => NativeLibrary.instance as _NativeLibrary;

  external JSUint8Array _emscripten_make_uint8_buffer(Pointer<Uint8> ptr, int length);
  external JSUint16Array _emscripten_make_uint16_buffer(Pointer<Uint16> ptr, int length);
  external JSInt16Array _emscripten_make_int16_buffer(Pointer<Int16> ptr, int length);
  external JSInt32Array _emscripten_make_int32_buffer(Pointer<Int32> ptr, int length);
  external JSFloat32Array _emscripten_make_f32_buffer(Pointer<Float32> ptr, int length);
  external JSFloat64Array _emscripten_make_f64_buffer(Pointer<Float64> ptr, int length);
  external Pointer _emscripten_get_byte_offset(JSObject obj);
}
final _allocated = <TypedData>{};

extension FreeTypedData<T> on TypedData {
  void free() {
    if(!_allocated.contains(this)) {
      throw Exception("This Uint8List was not allocated directly via emscripten");
    }
    final ptr = Pointer<Void>(this.offsetInBytes);
    ptr.free();
    _allocated.remove(this);
  }
}

Pointer<T> getPointer<T extends NativeType>(TypedData data, JSObject obj) {
  if(_allocated.contains(data)) {
      var offset =  _NativeLibrary.instance._emscripten_get_byte_offset(obj);
      if(offset == 0) {
        throw Exception("This Uint8List was not allocated directly via emscripten");
      }
      return Pointer<T>(offset);
  }
    throw Exception("This Uint8List was not allocated directly via emscripten");
}

extension Uint8ListExtension on Uint8List {
  Pointer<Uint8> get address {
    return getPointer<Uint8>(this, this.toJS);
  }

  static Uint8List create(int length) {
    final ptr = malloc(length);
    final buffer = _NativeLibrary.instance._emscripten_make_uint8_buffer(ptr.cast(), length).toDart;
    _allocated.add(buffer);
    return buffer;
  }

}

extension Float32ListExtension on Float32List {

  Pointer<Float32> get address {
    return getPointer<Float32>(this, this.toJS);
  }

  static Float32List create(int length) {
    final ptr = malloc(length*4);
    final buffer = _NativeLibrary.instance._emscripten_make_f32_buffer(ptr.cast(), length).toDart;
    _allocated.add(buffer);
    return buffer;
  }

}

extension Int16ListExtension on Int16List {
  Pointer<Int16> get address {
    return getPointer<Int16>(this, this.toJS);
  }

  static Int16List create(int length) {
    final ptr = malloc(length*2);
    final buffer = _NativeLibrary.instance._emscripten_make_int16_buffer(ptr.cast(), length).toDart;
    _allocated.add(buffer);
    return buffer;
  }
}

extension Uint16ListExtension on Uint16List {
  Pointer<Uint16> get address {
    return getPointer<Uint16>(this, this.toJS);
  }

  static Uint16List create(int length) {
    final ptr = malloc(length*2);
    final buffer = _NativeLibrary.instance._emscripten_make_uint16_buffer(ptr.cast(), length).toDart;
    _allocated.add(buffer);
    return buffer;
  }
}

extension UInt32ListExtension on Uint32List {
  Pointer<Uint32> get address {
    throw UnimplementedError();
  }
}

extension Int32ListExtension on Int32List {
  Pointer<Int32> get address {
    return getPointer<Int32>(this, this.toJS);
  }

  static Int32List create(int length) {
    final ptr = malloc(length * 4);
    final buffer = _NativeLibrary.instance._emscripten_make_int32_buffer(ptr.cast(), length).toDart;
    _allocated.add(buffer);
    return buffer;
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
    return getPointer<Float64>(this, this.toJS);
  }

  static Float64List create(int length) {
    final ptr = malloc(length * 8);
    final buffer = _NativeLibrary.instance._emscripten_make_f64_buffer(ptr.cast(), length).toDart;
    _allocated.add(buffer);
    return buffer;
  }
}

int sizeOf<T extends NativeType>() {
  switch(T) {
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

class FinalizableUint8List  {
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
    final ptr = addFunction<DartPickCallbackFunction>(this.toJS, "viidddd");
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


Future<void> withVoidCallback(
    Function(Pointer<NativeFunction<Void Function()>>) func) async {
  final completer = Completer();
  // ignore: prefer_function_declarations_over_variables
  void Function() callback = () {
    completer.complete();
  };
  final ptr = callback.addFunction();
  func.call(ptr.cast());
  await completer.future;
  ptr.dispose();
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

Future<double> withFloatCallback(void Function(Pointer<NativeFunction<void Function(double)>>) func) async {
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
  switch(T) {
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
  // final nativeCallable =
  //     NativeCallable<Void Function(Uint32)>.listener(callback);
  // func.call(nativeCallable.nativeFunction);
  await completer.future;
  // nativeCallable.close();
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
export 'thermion_dart_ffi.g.dart';

export 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'package:thermion_dart/thermion_dart.dart';
export 'package:ffi/ffi.dart';
export 'dart:ffi';

const FILAMENT_SINGLE_THREADED = false;
const FILAMENT_WASM = false;
bool get IS_WINDOWS => Platform.isWindows;

class NativeLibrary {
  static void initBindings(String name) {
    throw Exception();
  }
}

typedef IntPtrList = Int64List;
typedef Float64 = Double;
typedef PointerClass<T extends NativeType> = Pointer<T>;
typedef VoidPointerClass = Pointer<Void>;

class CallbackHolder<T extends Function> {
  final NativeCallable<T> nativeCallable;

  Pointer<NativeFunction<T>> get pointer => nativeCallable.nativeFunction;

  CallbackHolder(this.nativeCallable);

  void dispose() {
    nativeCallable.close();
  }
}

Pointer<T> allocate<T extends NativeType>(int count) {
  return calloc.allocate<T>(count * sizeOf<Pointer>());
}

void free(Pointer ptr) {
  calloc.free(ptr);
}

Pointer stackSave() {
  throw Exception();
}

void stackRestore(Pointer ptr) {
  throw Exception();
}

class FinalizableUint8List implements Finalizable {
  final Pointer name;
  final Uint8List data;

  FinalizableUint8List(this.name, this.data);
}

extension GPFBP on void Function(int, double, double, double) {
  CallbackHolder<GizmoPickCallbackFunction> asCallback() {
    var nativeCallable =
        NativeCallable<GizmoPickCallbackFunction>.listener(this);
    return CallbackHolder(nativeCallable);
  }
}

CallbackHolder<PickCallbackFunction> makePickCallbackFunctionPointer(
    DartPickCallbackFunction fn) {
  final nc = NativeCallable<PickCallbackFunction>.listener(fn);
  final cbh = CallbackHolder(nc);
  return cbh;
}

extension VFB on void Function() {
  CallbackHolder<Void Function()> asCallback() {
    var nativeCallable = NativeCallable<Void Function()>.listener(this);
    return CallbackHolder(nativeCallable);
  }
}

extension PCBF on DartPickCallbackFunction {
  CallbackHolder<PickCallbackFunction> asCallback() {
    var nativeCallable = NativeCallable<PickCallbackFunction>.listener(this);
    return CallbackHolder(nativeCallable);
  }
}

Future<void> withVoidCallback(
    Function(Pointer<NativeFunction<Void Function()>>) func) async {
  final completer = Completer();
  // ignore: prefer_function_declarations_over_variables
  void Function() callback = () {
    completer.complete();
  };
  final nativeCallable = NativeCallable<Void Function()>.listener(callback);
  func.call(nativeCallable.nativeFunction);
  await completer.future;
  nativeCallable.close();
}

Future<Pointer<T>> withPointerCallback<T extends NativeType>(
    Function(Pointer<NativeFunction<Void Function(Pointer<T>)>>) func) async {
  final completer = Completer<Pointer<T>>();
  // ignore: prefer_function_declarations_over_variables
  void Function(Pointer<NativeType>) callback = (Pointer<NativeType> ptr) {
    completer.complete(ptr.cast<T>());
  };
  final nativeCallable =
      NativeCallable<Void Function(Pointer<NativeType>)>.listener(callback);
  func.call(nativeCallable.nativeFunction);
  var ptr = await completer.future;
  nativeCallable.close();
  return ptr;
}

Future<bool> withBoolCallback(
    Function(Pointer<NativeFunction<Void Function(Bool)>>) func) async {
  final completer = Completer<bool>();
  // ignore: prefer_function_declarations_over_variables
  void Function(bool) callback = (bool result) {
    completer.complete(result);
  };
  final nativeCallable = NativeCallable<Void Function(Bool)>.listener(callback);
  func.call(nativeCallable.nativeFunction);
  await completer.future;
  nativeCallable.close();
  return completer.future;
}

Future<double> withFloatCallback(
    Function(Pointer<NativeFunction<Void Function(Float)>>) func) async {
  final completer = Completer<double>();
  // ignore: prefer_function_declarations_over_variables
  void Function(double) callback = (double result) {
    completer.complete(result);
  };
  final nativeCallable =
      NativeCallable<Void Function(Float)>.listener(callback);
  func.call(nativeCallable.nativeFunction);
  await completer.future;
  nativeCallable.close();
  return completer.future;
}

Future<int> withIntCallback(
    Function(Pointer<NativeFunction<Void Function(Int32)>>) func) async {
  final completer = Completer<int>();
  // ignore: prefer_function_declarations_over_variables
  void Function(int) callback = (int result) {
    completer.complete(result);
  };
  final nativeCallable =
      NativeCallable<Void Function(Int32)>.listener(callback);
  func.call(nativeCallable.nativeFunction);
  await completer.future;
  nativeCallable.close();
  return completer.future;
}

Future<int> withUInt32Callback(
    Function(Pointer<NativeFunction<Void Function(Uint32)>>) func) async {
  final completer = Completer<int>();
  // ignore: prefer_function_declarations_over_variables
  void Function(int) callback = (int result) {
    completer.complete(result);
  };
  final nativeCallable =
      NativeCallable<Void Function(Uint32)>.listener(callback);
  func.call(nativeCallable.nativeFunction);
  await completer.future;
  nativeCallable.close();
  return completer.future;
}

Future<String> withCharPtrCallback(
    Function(Pointer<NativeFunction<Void Function(Pointer<Char>)>>)
        func) async {
  final completer = Completer<String>();
  // ignore: prefer_function_declarations_over_variables
  void Function(Pointer<Char>) callback = (Pointer<Char> result) {
    completer.complete(result.cast<Utf8>().toDartString());
  };
  final nativeCallable =
      NativeCallable<Void Function(Pointer<Char>)>.listener(callback);
  func.call(nativeCallable.nativeFunction);
  await completer.future;
  nativeCallable.close();
  return completer.future;
}

extension FreeTypedData<T> on TypedData {
  void free() {
    // noop
  }
}

T makeTypedData<T extends TypedData>(int length) {
  TypedData typedData = switch (T) {
    Uint8List => Uint8List(length),
    Float32List => Float32List(length),
    _ => throw UnimplementedError()
  };
  return typedData as T;
}

T makeTypedDataFromIntList<T extends TypedData>(List<int> src) {
  TypedDataList typedData = switch (T) {
    Uint8List => Uint8List.fromList(src),
    Int16List => Int16List.fromList(src),
    Int32List => Int32List.fromList(src),
    _ => throw UnimplementedError()
  };
  return typedData as T;
}

T makeTypedDataFromDoubleList<T extends TypedData>(List<double> src) {
  TypedDataList typedData = switch (T) {
    Float32List => Float32List.fromList(src),
    Float64List => Float64List.fromList(src),
    _ => throw UnimplementedError()
  };
  typedData.setRange(0, src.length, src);

  return typedData as T;
}

extension DartBigIntExtension on int {
  int get toBigInt {
    return this;
  }
}

import 'dart:async';
import 'dart:js_interop';

import 'thermion_dart_js_interop.g.dart';
export 'thermion_dart_js_interop.g.dart';

final nullptr = Pointer<Void>(0);
extension type Bool(int val) {}

typedef Uint32 = Int32;
typedef Utf8 = Char;

Future<void> withVoidCallback(
    Function(Pointer<NativeFunction<Void Function()>>) func) async {
  final completer = Completer();
  // ignore: prefer_function_declarations_over_variables
  void Function() callback = () {
    completer.complete();
  };
  // final nativeCallable = NativeCallable<Void Function()>.listener(callback);
  // func.call(nativeCallable.nativeFunction);
  await completer.future;
  // nativeCallable.close();
}

Future<Pointer<T>> withPointerCallback<T extends NativeType>(
    Function(Pointer<NativeFunction<Void Function(Pointer<T>)>>) func) async {
  var lib = getLib();
  print("got lib");

  final completer = Completer<Pointer<T>>();
  // ignore: prefer_function_declarations_over_variables
  void Function(Pointer<NativeType>) callback = (Pointer<NativeType> ptr) {
    completer.complete(ptr.cast<T>());
  };

  final onComplete_interopFnPtr = lib.addFunction(callback.toJS, "vp");
  print("added function");

  // final nativeCallable =
  //     NativeCallable<Void Function(Pointer<NativeType>)>.listener(callback);
  func.call(onComplete_interopFnPtr.cast());
  print("called");
  var ptr = await completer.future;
  // nativeCallable.close();
  return ptr;
}

Future<bool> withBoolCallback(
    Function(Pointer<NativeFunction<Void Function(Bool)>>) func) async {
  final completer = Completer<bool>();
  // ignore: prefer_function_declarations_over_variables
  void Function(bool) callback = (bool result) {
    completer.complete(result);
  };
  // final nativeCallable = NativeCallable<Void Function(Bool)>.listener(callback);
  // func.call(nativeCallable.nativeFunction);
  await completer.future;
  // nativeCallable.close();
  return completer.future;
}

Future<double> withFloatCallback(
    Function(Pointer<NativeFunction<Void Function(Float32)>>) func) async {
  final completer = Completer<double>();
  // ignore: prefer_function_declarations_over_variables
  void Function(double) callback = (double result) {
    completer.complete(result);
  };
  // final nativeCallable = NativeCallable<Void Function(Float)>.listener(callback);
  // func.call(nativeCallable.nativeFunction);
  await completer.future;
  // nativeCallable.close();
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

Future<int> withUInt32Callback(
    Function(Pointer<NativeFunction<Void Function(Uint32)>>) func) async {
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

import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
export 'package:ffi/ffi.dart';
export 'dart:ffi';
export 'dart_filament.g.dart';

final allocator = calloc;

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

Future<int> withVoidPointerCallback(
    Function(Pointer<NativeFunction<Void Function(Pointer<Void>)>>)
        func) async {
  final completer = Completer<Pointer<Void>>();
  // ignore: prefer_function_declarations_over_variables
  void Function(Pointer<Void>) callback = (Pointer<Void> ptr) {
    completer.complete(ptr);
  };
  final nativeCallable =
      NativeCallable<Void Function(Pointer<Void>)>.listener(callback);
  func.call(nativeCallable.nativeFunction);
  var ptr = await completer.future;
  nativeCallable.close();
  return ptr.address;
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

class Compatibility {}

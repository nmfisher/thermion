import 'dart:async';
import 'dart:js_interop';
import 'package:thermion_dart/thermion_dart/compatibility/web/ffi/interop.dart';

import "allocator.dart";

export "allocator.dart";
export "thermion_dart.g.dart";

export 'package:ffi/ffi.dart' hide StringUtf8Pointer, Utf8Pointer;
export 'dart:ffi'
    hide
        Uint8Pointer,
        FloatPointer,
        DoublePointer,
        Int32Pointer,
        Int64Pointer,
        PointerPointer,
        Allocator;

const allocator = Allocator();

@AbiSpecificIntegerMapping({
  Abi.androidArm: Uint8(),
  Abi.androidArm64: Uint8(),
  Abi.androidIA32: Int8(),
  Abi.androidX64: Int8(),
  Abi.androidRiscv64: Uint8(),
  Abi.fuchsiaArm64: Uint8(),
  Abi.fuchsiaX64: Int8(),
  Abi.fuchsiaRiscv64: Uint8(),
  Abi.iosArm: Int8(),
  Abi.iosArm64: Int8(),
  Abi.iosX64: Int8(),
  Abi.linuxArm: Uint8(),
  Abi.linuxArm64: Uint8(),
  Abi.linuxIA32: Int8(),
  Abi.linuxX64: Int8(),
  Abi.linuxRiscv32: Uint8(),
  Abi.linuxRiscv64: Uint8(),
  Abi.macosArm64: Int8(),
  Abi.macosX64: Int8(),
  Abi.windowsArm64: Int8(),
  Abi.windowsIA32: Int8(),
  Abi.windowsX64: Int8(),
})
final class FooChar extends AbiSpecificInteger {
  const FooChar();
}

class Compatibility {
  final _foo = FooChar();
}

Future<void> withVoidCallback(
    Function(Pointer<NativeFunction<Void Function()>>) func) async {
  JSArray retVal = createVoidCallback();
  var promise = retVal.toDart[0] as JSPromise<JSNumber>;
  var fnPtrAddress = retVal.toDart[1] as JSNumber;
  var fnPtr = Pointer<NativeFunction<Void Function()>>.fromAddress(
      fnPtrAddress.toDartInt);
  func(fnPtr);
  await promise.toDart;
}

Future<int> withVoidPointerCallback(
    void Function(Pointer<NativeFunction<Void Function(Pointer<Void>)>>)
        func) async {
  JSArray retVal = createVoidPointerCallback();
  var promise = retVal.toDart[0] as JSPromise<JSNumber>;

  var fnPtrAddress = retVal.toDart[1] as JSNumber;
  var fnPtr = Pointer<NativeFunction<Void Function(Pointer<Void>)>>.fromAddress(
      fnPtrAddress.toDartInt);
  func(fnPtr);
  final addr = await promise.toDart;
  return addr.toDartInt;
}

Future<bool> withBoolCallback(
    Function(Pointer<NativeFunction<Void Function(Bool)>>) func) async {
  JSArray retVal = createBoolCallback();
  var promise = retVal.toDart[0] as JSPromise<JSBoolean>;

  var fnPtrAddress = retVal.toDart[1] as JSNumber;
  var fnPtr = Pointer<NativeFunction<Void Function(Bool)>>.fromAddress(
      fnPtrAddress.toDartInt);
  func(fnPtr);
  final addr = await promise.toDart;
  return addr.toDart;
}

Future<int> withIntCallback(
    Function(Pointer<NativeFunction<Void Function(Int32)>>) func) async {
  JSArray retVal = createBoolCallback();
  var promise = retVal.toDart[0] as JSPromise<JSNumber>;

  var fnPtrAddress = retVal.toDart[1] as JSNumber;
  var fnPtr = Pointer<NativeFunction<Void Function(Int32)>>.fromAddress(
      fnPtrAddress.toDartInt);
  func(fnPtr);
  final addr = await promise.toDart;
  return addr.toDartInt;
}

Future<String> withCharPtrCallback(
    Function(Pointer<NativeFunction<Void Function(Pointer<Char>)>>)
        func) async {
  JSArray retVal = createVoidPointerCallback();
  var promise = retVal.toDart[0] as JSPromise<JSNumber>;

  var fnPtrAddress = retVal.toDart[1] as JSNumber;
  var fnPtr = Pointer<NativeFunction<Void Function(Pointer<Char>)>>.fromAddress(
      fnPtrAddress.toDartInt);
  func(fnPtr);
  final addr = await promise.toDart;
  return Pointer<Utf8>.fromAddress(addr.toDartInt).toDartString();
}

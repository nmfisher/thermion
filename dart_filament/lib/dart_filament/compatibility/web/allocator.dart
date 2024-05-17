import 'dart:ffi';
export "allocator.dart";
export "dart_filament.g.dart";

import 'dart:convert';
import 'dart:ffi' as ffi hide Uint8Pointer, FloatPointer;
import 'dart:typed_data';

import 'package:dart_filament/dart_filament/compatibility/web/dart_filament.g.dart';

import 'package:ffi/ffi.dart';
export 'package:ffi/ffi.dart' hide StringUtf8Pointer, Utf8Pointer;
export 'dart:ffi'
    hide
        Uint8Pointer,
        FloatPointer,
        DoublePointer,
        Int32Pointer,
        Int64Pointer,
        PointerPointer, Allocator;

class Allocator implements ffi.Allocator {
  const Allocator();
  @override
  ffi.Pointer<T> allocate<T extends ffi.NativeType>(int byteCount,
      {int? alignment}) {
    return flutter_filament_web_allocate(byteCount).cast<T>();
  }

  @override
  void free(ffi.Pointer<ffi.NativeType> pointer) {
    flutter_filament_web_free(pointer.cast<ffi.Void>());
  }
}

extension CharPointer on ffi.Pointer<ffi.Char> {
  int get value {
    return flutter_filament_web_get(this, 0);
  }

  set value(int value) {
    flutter_filament_web_set(this, 0, value);
  }

  void operator []=(int index, int value) {
    this.elementAt(index).value = value;
  }

  ffi.Pointer<ffi.Char> elementAt(int index) =>
      ffi.Pointer.fromAddress(address + ffi.sizeOf<ffi.Char>() * index);
}

extension IntPointer on ffi.Pointer<ffi.Int> {
  int get value {
    return flutter_filament_web_get_int32(this.cast<ffi.Int32>(), 0);
  }

  set value(int value) {
    flutter_filament_web_set_int32(this.cast<ffi.Int32>(), 0, value);
  }

  void operator []=(int index, int value) {
    this.elementAt(index).value = value;
  }

  int operator [](int index) {
    return this.elementAt(index).value;
  }

  ffi.Pointer<ffi.Int> elementAt(int index) =>
      ffi.Pointer.fromAddress(address + ffi.sizeOf<ffi.Int>() * index);
}

extension Int32Pointer on ffi.Pointer<ffi.Int32> {
  int get value {
    return flutter_filament_web_get_int32(this, 0);
  }

  set value(int value) {
    flutter_filament_web_set_int32(this, 0, value);
  }

  void operator []=(int index, int value) {
    this.elementAt(index).value = value;
  }

  int operator [](int index) {
    return this.elementAt(index).value;
  }

  ffi.Pointer<ffi.Int32> elementAt(int index) =>
      ffi.Pointer.fromAddress(address + ffi.sizeOf<ffi.Int32>() * index);
}

extension UInt8Pointer on ffi.Pointer<ffi.Uint8> {
  int get value {
    return flutter_filament_web_get(this.cast<ffi.Char>(), 0);
  }

  set value(int value) {
    flutter_filament_web_set(this.cast<ffi.Char>(), 0, value);
  }

  void operator []=(int index, int value) {
    this.elementAt(index).value = value;
  }

  int operator [](int index) {
    return this.elementAt(index).value;
  }

  ffi.Pointer<ffi.Uint8> elementAt(int index) =>
      ffi.Pointer.fromAddress(address + ffi.sizeOf<ffi.Uint8>() * index);
}

extension PointerPointer<T extends ffi.NativeType>
    on ffi.Pointer<ffi.Pointer<T>> {
  ffi.Pointer<T> get value {
    return flutter_filament_web_get_pointer(cast<ffi.Pointer<ffi.Void>>(), 0)
        .cast<T>();
  }

  set value(ffi.Pointer<T> value) {
    flutter_filament_web_set_pointer(
        cast<ffi.Pointer<ffi.Void>>(), 0, value.cast<ffi.Void>());
  }

  void operator []=(int index, ffi.Pointer<T> value) {
    this.elementAt(index).value = value;
  }

  ffi.Pointer<ffi.Pointer<T>> elementAt(int index) =>
      ffi.Pointer.fromAddress(address + ffi.sizeOf<ffi.Pointer>() * index);
}

extension FloatPointer on ffi.Pointer<ffi.Float> {
  double get value {
    return flutter_filament_web_get_float(this, 0);
  }

  set value(double value) {
    flutter_filament_web_set_float(this, 0, value);
  }

  void operator []=(int index, double value) {
    this.elementAt(index).value = value;
  }

  ffi.Pointer<ffi.Float> elementAt(int index) =>
      ffi.Pointer.fromAddress(address + ffi.sizeOf<ffi.Float>() * index);

  Float32List asTypedList(int length) {
    var list = Float32List(length);

    for (int i = 0; i < length; i++) {
      list[i] = elementAt(i).value;
    }
    return list;
  }
}

extension StringConversion on String {
  ffi.Pointer<Utf8> toNativeUtf8({ffi.Allocator? allocator}) {
    final units = utf8.encode(this);
    final ffi.Pointer<ffi.Uint8> result =
        allocator!<ffi.Uint8>(units.length + 1);
    for (int i = 0; i < units.length; i++) {
      result.elementAt(i).value = units[i];
    }
    result.elementAt(units.length).value = 0;
    return result.cast();
  }
}

extension StringUtf8Pointer on ffi.Pointer<Utf8> {

  
  static int _length(ffi.Pointer<ffi.Uint8> codeUnits) {
    var length = 0;
    while (codeUnits[length] != 0) {
      length++;
    }
    return length;
  }

  String toDartString({int? length}) {
    final codeUnits = this.cast<ffi.Uint8>();
    final list = <int>[];

    if (length != null) {
      RangeError.checkNotNegative(length, 'length');
    } else {
      length = _length(codeUnits);
    }
    for (int i = 0; i < length; i++) {
      list.add(codeUnits.elementAt(i).value);
    }
    return utf8.decode(list);
  }
}

extension DoublePointer on ffi.Pointer<ffi.Double> {
  double get value {
    return flutter_filament_web_get_double(this, 0);
  }

  set value(double value) {
    return flutter_filament_web_set_double(this, 0, value);
  }

  Float64List asTypedList(int length) {
    var list = Float64List(length);

    for (int i = 0; i < length; i++) {
      list[i] = elementAt(i).value;
    }
    return list;
  }

  double operator [](int index) {
    return elementAt(index).value;
  }

  void operator []=(int index, double value) {
    elementAt(index).value = value;
  }

  ffi.Pointer<ffi.Double> elementAt(int index) =>
      ffi.Pointer.fromAddress(address + ffi.sizeOf<ffi.Double>() * index);
}

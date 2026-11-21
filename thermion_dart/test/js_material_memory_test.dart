@TestOn('js')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/bindings/src/js_interop.dart' as js;
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

class _App extends FFIFilamentApp {
  _App()
    : super(
        Pointer<TEngine>.fromAddress(1),
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        nullptr,
        Pointer<TJobThread>.fromAddress(3),
        nullptr,
        null,
        nullptr,
        nullptr,
        nullptr,
      );
}

void main() {
  final module = JSObject();
  var heap = Uint8List(32 * 1024 * 1024);
  final allocations = <int, int>{};
  final callbacks = <int, JSFunction>{};
  var nextAddress = 16;
  var nextCallback = 0;
  var allocationCount = 0;
  var failAllocation = false;
  var failDispatch = false;
  var autoComplete = true;
  var version = 71;
  var resultAddress = 99;
  var validatedAddress = 0;
  var submittedAddress = 0;
  void Function()? pending;
  late _App app;

  void export(String name, JSFunction function) => module.setProperty(name.toJS, function);

  setUpAll(() {
    module.setProperty('HEAPU8'.toJS, heap.toJS);
    export('_FrameScheduler_setTargetFps', ((double fps) {}).toJS);
    export(
      '_malloc',
      ((int size) {
        allocationCount++;
        if (failAllocation) return 0;
        final address = nextAddress;
        nextAddress += (size + 7) & ~7;
        allocations[address] = size;
        return address;
      }).toJS,
    );
    export(
      '_free',
      ((int address) {
        final size = allocations.remove(address)!;
        heap.fillRange(address, address + size, 0xcc);
      }).toJS,
    );
    int stackAlloc(int size) => throw StateError('material transfer used the Wasm stack');
    export('stackAlloc', stackAlloc.toJS);
    export(
      'addFunction',
      ((JSFunction callback, JSString signature) {
        callbacks[++nextCallback] = callback;
        return nextCallback;
      }).toJS,
    );
    export(
      'removeFunction',
      ((int address) {
        callbacks.remove(address);
      }).toJS,
    );
    export('_Material_getSupportedVersion', (() => 71).toJS);
    export(
      '_Material_getPackageVersion',
      ((int address, int length) {
        validatedAddress = address;
        expect(allocations[address], length);
        return version.toJSBigInt;
      }).toJS,
    );
    export(
      '_Engine_buildMaterialJobThread',
      ((int job, int engine, int address, int length, int callback) {
        if (failDispatch) throw StateError('dispatch failed');
        expect(job, 3);
        expect(engine, 1);
        expect(address, validatedAddress);
        expect(allocations[address], length);
        submittedAddress = address;
        void complete() => callbacks[callback]!.callAsFunction(null, resultAddress.toJS);
        if (autoComplete) {
          scheduleMicrotask(complete);
        } else {
          pending = complete;
        }
      }).toJS,
    );
    js.NativeLibrary.instance = module as js.NativeLibrary;
    app = _App();
  });

  setUp(() {
    expect(allocations, isEmpty);
    expect(callbacks, isEmpty);
    nextAddress = 16;
    allocationCount = 0;
    failAllocation = false;
    failDispatch = false;
    autoComplete = true;
    version = 71;
    resultAddress = 99;
    pending = null;
    submittedAddress = 0;
  });
  tearDown(() {
    expect(allocations, isEmpty);
    expect(callbacks, isEmpty);
  });

  test('large subview uses one heap copy retained until completion', () async {
    autoComplete = false;
    final source = Uint8List(12 * 1024 * 1024 + 2)..fillRange(0, 12 * 1024 * 1024 + 2, 7);
    final bytes = Uint8List.sublistView(source, 1, source.length - 1);
    final operation = app.createMaterial(bytes);
    expect(allocationCount, 1);
    expect(allocations, hasLength(1));
    expect(heap[submittedAddress], 7);
    bytes.fillRange(0, bytes.length, 0);
    // The copy remains readable while native completion is delayed.
    await Future<void>.delayed(Duration.zero);
    expect(heap[submittedAddress], 7);
    expect(heap[submittedAddress + bytes.length - 1], 7);
    pending!();
    final material = await operation;
    expect(material.getNativeHandle(), Pointer<TMaterial>.fromAddress(resultAddress));
  });

  test('version rejection frees storage before dispatch', () async {
    for (final rejected in [-1, 70]) {
      version = rejected;
      await expectLater(app.createMaterial(Uint8List(16)), throwsFormatException);
      expect(allocations, isEmpty);
      expect(submittedAddress, 0);
    }
  });

  test('dispatch exception frees storage and callback', () async {
    failDispatch = true;
    await expectLater(app.createMaterial(Uint8List(16)), throwsStateError);
  });

  test('asynchronous null result frees storage', () async {
    autoComplete = false;
    resultAddress = 0;
    final operation = app.createMaterial(Uint8List(16));
    final expectation = expectLater(operation, throwsStateError);
    expect(allocations, hasLength(1));
    pending!();
    await expectation;
  });

  test('allocation failure does not dispatch or register a callback', () async {
    failAllocation = true;
    await expectLater(app.createMaterial(Uint8List(16)), throwsStateError);
    expect(submittedAddress, 0);
  });

  test('empty input is rejected without allocation', () async {
    await expectLater(app.createMaterial(Uint8List(0)), throwsFormatException);
    expect(allocationCount, 0);
  });
}

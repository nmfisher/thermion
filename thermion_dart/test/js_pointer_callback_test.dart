@TestOn('js')
library;

import 'dart:async';

import 'package:test/test.dart';

import '../lib/src/bindings/src/js_interop.dart';

void main() {
  // Exercise the JS bindings without loading Filament or a Wasm engine.
  final callbacks = <int, JSFunction>{};
  final removed = <int>[];
  var next = 0;
  void Function()? pump;

  setUp(() {
    callbacks.clear();
    removed.clear();
    next = 0;
    pump = null;
    final module = JSObject();
    module.setProperty(
      'addFunction'.toJS,
      ((JSFunction callback, JSString signature) {
        callbacks[++next] = callback;
        return next;
      }).toJS,
    );
    module.setProperty(
      'removeFunction'.toJS,
      ((int index) {
        expect(callbacks.remove(index), isNotNull);
        removed.add(index);
      }).toJS,
    );
    module.setProperty('_execute_queue'.toJS, (() => pump?.call()).toJS);
    NativeLibrary.instance = module as NativeLibrary;
  });

  for (final address in [0, 0x1234]) {
    test('pointer completion returns $address and releases its table entry', () async {
      final result = await withPointerCallback<TMaterial>((callback) {
        callbacks[callback.address]!.callAsFunction(null, address.toJS);
      });

      expect(result.address, address);
      expect(callbacks, isEmpty);
      expect(removed, [1]);
    });
  }

  test('pending pointer callback stays registered until completion', () async {
    late int callbackAddress;
    final pending = withPointerCallback<TMaterial>((callback) {
      callbackAddress = callback.address;
    });

    expect(callbacks.keys, [callbackAddress]);
    expect(removed, isEmpty);
    callbacks[callbackAddress]!.callAsFunction(null, 0x5678.toJS);

    expect((await pending).address, 0x5678);
    expect(callbacks, isEmpty);
    expect(removed, [callbackAddress]);
  });

  test('pointer dispatch failure releases its table entry and preserves the error', () async {
    final error = StateError('dispatch failed');
    await expectLater(withPointerCallback<TMaterial>((_) => throw error), throwsA(same(error)));

    expect(callbacks, isEmpty);
    expect(removed, [1]);
  });

  test('asynchronous pointer completion does not poll the native queue', () async {
    pump = () => throw StateError('native queue must not be polled');
    final pending = withPointerCallback<TMaterial>((callback) {
      Timer.run(() => callbacks[callback.address]!.callAsFunction(null, 0x5678.toJS));
    });

    expect((await pending).address, 0x5678);
    expect(callbacks, isEmpty);
    expect(removed, [1]);
  });

  test('string completion copies borrowed text before the callback returns', () async {
    var text = 'original view name';
    NativeLibrary.instance.setProperty('UTF8ToString'.toJS, ((int _) => text.toJS).toJS);
    final result = await withStringCallback((callback) {
      callbacks[callback.address]!.callAsFunction(null, 0x1234.toJS);
      text = 'native string is no longer valid';
    });

    expect(result, 'original view name');
    expect(callbacks, isEmpty);
    expect(removed, [1]);
  });

  test('null string completion returns null and releases its table entry', () async {
    final result = await withStringCallback((callback) {
      callbacks[callback.address]!.callAsFunction(null, 0.toJS);
    });

    expect(result, isNull);
    expect(callbacks, isEmpty);
    expect(removed, [1]);
  });

  test('string dispatch failure releases its table entry and preserves the error', () async {
    final error = StateError('string dispatch failed');
    await expectLater(withStringCallback((_) => throw error), throwsA(same(error)));

    expect(callbacks, isEmpty);
    expect(removed, [1]);
  });

  test('asynchronous string conversion failure releases its table entry', () async {
    final error = StateError('invalid string');
    JSString failConversion(int _) => throw error;
    NativeLibrary.instance.setProperty('UTF8ToString'.toJS, failConversion.toJS);
    final pending = withStringCallback((callback) {
      Timer.run(() => callbacks[callback.address]!.callAsFunction(null, 0x1234.toJS));
    });

    await expectLater(pending, throwsA(same(error)));
    expect(callbacks, isEmpty);
    expect(removed, [1]);
  });
}

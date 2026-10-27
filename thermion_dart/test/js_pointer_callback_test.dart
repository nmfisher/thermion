@TestOn('js')
library;

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

  test('queue pump failure releases its table entry and preserves the error', () async {
    final error = StateError('queue pump failed');
    pump = () => throw error;
    await expectLater(withPointerCallback<TMaterial>((_) {}), throwsA(same(error)));

    expect(callbacks, isEmpty);
    expect(removed, [1]);
  });
}

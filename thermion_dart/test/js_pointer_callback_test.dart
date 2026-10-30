@TestOn('js')
library;

import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';

import '../lib/src/bindings/src/js_interop.dart';
import '../lib/src/bindings/string_buffer.dart';

void main() {
  // Exercise the JS bindings without loading Filament or a Wasm engine.
  final callbacks = <int, JSFunction>{};
  final removed = <int>[];
  final freedBuffers = <int>[];
  final allocations = <int, int>{};
  late Uint8List heap;
  var nextAddress = 16;
  var next = 0;
  void Function()? pump;

  setUp(() {
    callbacks.clear();
    removed.clear();
    freedBuffers.clear();
    allocations.clear();
    heap = Uint8List(64 * 1024);
    nextAddress = 16;
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
    module.setProperty('HEAPU8'.toJS, heap.toJS);
    module.setProperty(
      '_malloc'.toJS,
      ((int size) {
        final address = nextAddress;
        nextAddress += size;
        allocations[address] = size;
        return address;
      }).toJS,
    );
    module.setProperty(
      '_free'.toJS,
      ((int address) {
        final size = allocations.remove(address)!;
        freedBuffers.add(address);
        heap.fillRange(address, address + size, 0xcc);
      }).toJS,
    );
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

  test('null string result frees its output buffer', () async {
    expect(await readString((_, _) async => 0), isNull);
    expect(allocations, isEmpty);
    expect(freedBuffers, hasLength(1));
  });

  test('allocation failure does not submit a native read', () async {
    NativeLibrary.instance.setProperty('_malloc'.toJS, ((int _) => 0).toJS);
    var submitted = false;
    await expectLater(
      readString((_, _) async {
        submitted = true;
        return 0;
      }),
      throwsA(isA<StateError>().having((error) => error.message, 'message', 'String buffer allocation failed')),
    );
    expect(submitted, isFalse);
    expect(allocations, isEmpty);
    expect(freedBuffers, isEmpty);
    expect(callbacks, isEmpty);
  });

  for (final text in ['', 'view Ω🚗', List.filled(128, 'long name Ω🚗').join()]) {
    test('string buffer reads ${utf8.encode(text).length} UTF-8 bytes and frees every attempt', () async {
      final bytes = utf8.encode(text);
      final capacities = <int>[];
      final result = await readString(
        (buffer, capacity) => withSizeCallback((callback) {
          capacities.add(capacity);
          if (bytes.length + 1 <= capacity) {
            heap.setRange(buffer.address, buffer.address + bytes.length, bytes);
            heap[buffer.address + bytes.length] = 0;
          }
          callbacks[callback.address]!.callAsFunction(null, (bytes.length + 1).toJS);
        }),
      );
      expect(result, text);
      expect(capacities, bytes.length + 1 > 256 ? [256, bytes.length + 1] : [256]);
      expect(freedBuffers, hasLength(capacities.length));
      expect(allocations, isEmpty);
      expect(callbacks, isEmpty);
      expect(removed, hasLength(capacities.length));
    });
  }

  test('output buffer stays allocated until asynchronous completion', () async {
    late void Function() complete;
    final pending = readString(
      (buffer, capacity) => withSizeCallback((callback) {
        complete = () {
          heap.setRange(buffer.address, buffer.address + 3, [104, 105, 0]);
          callbacks[callback.address]!.callAsFunction(null, 3.toJS);
        };
      }),
    );
    expect(allocations, hasLength(1));
    expect(freedBuffers, isEmpty);
    complete();
    expect(await pending, 'hi');
    expect(allocations, isEmpty);
    expect(freedBuffers, hasLength(1));
    expect(callbacks, isEmpty);
  });

  test('dispatch failure releases the output buffer and callback entry', () async {
    final error = StateError('string dispatch failed');
    await expectLater(readString((_, _) => withSizeCallback((_) => throw error)), throwsA(same(error)));
    expect(allocations, isEmpty);
    expect(freedBuffers, hasLength(1));
    expect(callbacks, isEmpty);
    expect(removed, [1]);
  });

  test('invalid UTF-8 releases the output buffer and callback entry', () async {
    await expectLater(
      readString(
        (buffer, _) => withSizeCallback((callback) {
          heap.setRange(buffer.address, buffer.address + 2, [0xff, 0]);
          callbacks[callback.address]!.callAsFunction(null, 2.toJS);
        }),
      ),
      throwsFormatException,
    );
    expect(allocations, isEmpty);
    expect(freedBuffers, hasLength(1));
    expect(callbacks, isEmpty);
    expect(removed, [1]);
  });
}

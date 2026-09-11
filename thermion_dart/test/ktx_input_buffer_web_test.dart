@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/src/js_interop.dart' as bindings;

void main() {
  late Uint8List heap;
  late Set<int> allocations;
  late int stackTop;
  late int heapTop;
  late int Function(int, int) construct;

  setUp(() {
    heap = Uint8List(1024 * 1024);
    allocations = {};
    stackTop = 1024;
    heapTop = 128 * 1024;
    construct = (_, __) => 123;
    // Exercise the real web buffer adapter with a small instrumented native
    // boundary. No renderer is needed to check allocation ownership.
    final module = JSObject();
    module.setProperty('HEAPU8'.toJS, heap.toJS);
    module.setProperty(
      '_malloc'.toJS,
      ((int size) {
        final pointer = heapTop;
        heapTop += size;
        allocations.add(pointer);
        return pointer;
      }).toJS,
    );
    module.setProperty(
      '_free'.toJS,
      ((int pointer) {
        expect(allocations.remove(pointer), isTrue);
      }).toJS,
    );
    module.setProperty('stackSave'.toJS, (() => stackTop).toJS);
    module.setProperty('stackRestore'.toJS, ((int marker) => stackTop = marker).toJS);
    module.setProperty(
      'stackAlloc'.toJS,
      ((int size) {
        final pointer = stackTop;
        stackTop += size;
        return pointer;
      }).toJS,
    );
    module.setProperty('_Ktx1Bundle_create'.toJS, ((int pointer, int size) => construct(pointer, size)).toJS);
    bindings.NativeLibrary.instance = module as bindings.NativeLibrary;
  });

  for (final size in [64, 64 * 1024]) {
    test('repeated $size-byte inputs release temporary storage', () {
      final input = Uint8List(size)..fillRange(0, size, 42);
      construct = (pointer, length) {
        expect(heap.sublist(pointer, pointer + length), input);
        return 123;
      };
      for (var i = 0; i < 5; i++) {
        expect(bindings.createKtx1BundleFromData(input).address, 123);
        expect(allocations, isEmpty);
        expect(stackTop, 1024);
      }
    });
  }

  test('borrowed WASM storage remains owned by the caller', () {
    // .address registers a heap allocation; derive a view from that pointer
    // so freeing the borrowed pointer would be observable in this test.
    final pointer = bindings.Uint8ListExtension(Uint8List(64 * 1024)).address;
    final input = Uint8List.sublistView(heap, pointer.address, pointer.address + 64 * 1024);
    bindings.createKtx1BundleFromData(input);
    expect(allocations, {pointer.address});
    pointer.free();
    expect(allocations, isEmpty);
  });

  test('constructor failure still releases temporary storage', () {
    construct = (_, __) => throw StateError('constructor failed');
    expect(() => bindings.createKtx1BundleFromData(Uint8List(64 * 1024)), throwsA(anything));
    expect(allocations, isEmpty);
    expect(stackTop, 1024);
  });
}

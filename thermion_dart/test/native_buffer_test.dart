@TestOn('vm')
library;

import 'dart:typed_data';
import 'dart:ffi';
import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/src/heap_buffer_ffi.dart';

void main() {
  test('non-leaf input uses an independent allocation with the exact view bounds', () {
    final backing = Uint8List.fromList([99, 1, 2, 3, 99]);
    final input = Uint8List.sublistView(backing, 1, 4);
    final result = withNativeBuffer(input, (pointer) {
      final native = pointer.asTypedList(3);
      expect(native, [1, 2, 3]);
      input[0] = 7;
      expect(native[0], 1);
      native[1] = 8;
      return 42;
    });
    expect(result, 42);
    expect(backing, [99, 7, 2, 3, 99]);
  });

  test('copy-back updates only the caller view and preserves partial output', () {
    final backing = Uint8List.fromList([99, 1, 2, 3, 99]);
    final output = Uint8List.sublistView(backing, 1, 4);
    withNativeBuffer(output, (pointer) {
      pointer.asTypedList(3)[1] = 7;
    }, copyBack: true);
    expect(backing, [99, 1, 7, 3, 99]);
  });

  test('empty buffers have a valid address without exposing bytes', () {
    withNativeBuffer(Uint8List(0), (pointer) => expect(pointer.address, isNonZero));
  });

  test('a failed operation propagates its error without copying partial output', () {
    final output = Uint8List.fromList([1, 2]);
    final failure = StateError('native dispatch failed');
    expect(
      () => withNativeBuffer(output, (pointer) {
        pointer.asTypedList(2)[0] = 99;
        throw failure;
      }, copyBack: true),
      throwsA(same(failure)),
    );
    expect(output, [1, 2]);
  });
}

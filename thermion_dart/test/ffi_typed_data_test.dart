import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/heap_buffer.dart';
import 'package:thermion_dart/src/bindings/src/ffi.dart';

void main() {
  group('TypedData.pass native borrowing', () {
    final views = <String, TypedData>{
      '16-bit indices': Uint16List.sublistView(Uint16List.fromList([99, 1, 2, 99]), 1, 3),
      '32-bit indices': Uint32List.sublistView(Uint32List.fromList([99, 1, 2, 99]), 1, 3),
      '64-bit handles': Int64List.sublistView(Int64List.fromList([99, 0x100000001, 0x200000002, 99]), 1, 3),
    };
    for (final entry in views.entries) {
      test('borrows ${entry.key} without copying', () async {
        final view = entry.value;
        final sourceBytes = view.buffer.asUint8List(view.offsetInBytes, view.lengthInBytes);
        await view.pass<void>((bytes) {
          _expectMatchingBytes(view, bytes);
          sourceBytes.first = 0x7a;
          expect(bytes.first, 0x7a);
          bytes.last = 0x3c;
          expect(sourceBytes.last, 0x3c);
        });
        expect(sourceBytes.first, 0x7a);
        expect(sourceBytes.last, 0x3c);
      });
    }
  });

  group('TypedData asUint8List', () {
    test('preserves Float32List view bounds', () {
      final values = Float32List.fromList([1, 2, 3, 4]);
      final view = Float32List.sublistView(values, 1, 3);

      _expectMatchingBytes(view, view.asUint8List());
    });

    test('preserves Int16List view bounds', () {
      final values = Int16List.fromList([1, 2, 3, 4]);
      final view = Int16List.sublistView(values, 1, 3);

      _expectMatchingBytes(view, view.asUint8List());
    });

    test('preserves Int32List view bounds', () {
      final values = Int32List.fromList([1, 2, 3, 4]);
      final view = Int32List.sublistView(values, 1, 3);

      _expectMatchingBytes(view, view.asUint8List());
    });

    test('preserves Uint16List view bounds', () {
      final values = Uint16List.fromList([1, 2, 3, 4]);
      final view = Uint16List.sublistView(values, 1, 3);

      _expectMatchingBytes(view, view.asUint8List());
    });

    test('preserves Uint32List view bounds', () {
      final values = Uint32List.fromList([1, 2, 3, 4]);
      final view = Uint32List.sublistView(values, 1, 3);

      _expectMatchingBytes(view, view.asUint8List());
    });

    test('generic TypedData conversion preserves view bounds', () {
      final values = Float64List.fromList([1, 2, 3, 4]);
      final view = Float64List.sublistView(values, 1, 3);

      _expectMatchingBytes(view, view.asUint8List());
    });
  });
}

void _expectMatchingBytes(TypedData view, Uint8List actual) {
  final expected = view.buffer.asUint8List(view.offsetInBytes, view.lengthInBytes);
  expect(actual, orderedEquals(expected));
  expect(actual.lengthInBytes, view.lengthInBytes);
}

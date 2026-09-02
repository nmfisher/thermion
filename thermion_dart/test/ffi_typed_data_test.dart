import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/src/ffi.dart';

void main() {
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

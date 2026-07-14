import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

void main() {
  group('CascadeSplitPositions validation', () {
    test('should accept correct number of split positions for 1 cascade', () {
      final options = ShadowOptions(
        shadowCascades: 1,
        cascadeSplitPositions: [], // No splits needed for 1 cascade
      );

      expect(options.shadowCascades, equals(1));
      expect(options.cascadeSplitPositions.length, equals(0));
    });

    test('should accept correct number of split positions for 2 cascades', () {
      final options = ShadowOptions(
        shadowCascades: 2,
        cascadeSplitPositions: [0.25], // 1 split needed for 2 cascades
      );

      expect(options.shadowCascades, equals(2));
      expect(options.cascadeSplitPositions.length, equals(1));
    });

    test('should accept correct number of split positions for 4 cascades', () {
      final options = ShadowOptions(
        shadowCascades: 4,
        cascadeSplitPositions: [
          0.125,
          0.25,
          0.50,
        ], // 3 splits needed for 4 cascades
      );

      expect(options.shadowCascades, equals(4));
      expect(options.cascadeSplitPositions.length, equals(3));
    });

    test('should use default split positions for maximum cascades', () {
      final options = ShadowOptions(shadowCascades: 4);

      expect(options.shadowCascades, equals(4));
      expect(options.cascadeSplitPositions.length, equals(3));
      expect(options.cascadeSplitPositions[0], equals(0.125));
      expect(options.cascadeSplitPositions[1], equals(0.25));
      expect(options.cascadeSplitPositions[2], equals(0.50));
    });
  });
}

import 'dart:typed_data';

import 'package:test/test.dart';

import '../../examples/dart/examples_lib/lib/src/parallax_ambient_occlusion.dart';

void main() {
  const size = 32;
  Float32List bake(Float32List heights, {double scale = 0.1}) =>
      bakeHeightFieldAmbientOcclusion(heights, size: size, heightScale: scale);

  test('constant height fields are fully accessible to ambient light', () {
    for (final height in [0.0, 0.5, 1.0]) {
      final result = bake(Float32List(size * size)..fillRange(0, size * size, height));
      expect(result, everyElement(closeTo(1, 1e-6)));
    }
  });

  test('deeper crevices block more ambient light; zero depth disables occlusion', () {
    final heights = Float32List(size * size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        heights[y * size + x] = x >= 14 && x <= 17 ? 0 : 1;
      }
    }
    final shallow = bake(heights, scale: 0.03);
    final deep = bake(heights, scale: 0.15);
    // This finite-radius bake leaves directions along the trench open.
    expect(deep[16 * size + 16], lessThan(0.6));
    expect(deep[16 * size + 16], lessThan(shallow[16 * size + 16]));
    expect(deep[16 * size + 8], closeTo(1, 1e-6));
    expect(bake(heights, scale: 0), everyElement(1));

    // Moving the joint across the repeating texture seam must preserve AO.
    final shifted = Float32List(size * size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        shifted[y * size + x] = heights[y * size + (x + 16) % size];
      }
    }
    final shiftedAo = bake(shifted, scale: 0.15);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        expect(shiftedAo[y * size + x], closeTo(deep[y * size + (x + 16) % size], 1e-6));
      }
    }
  });

  test('an unobstructed slope does not acquire cavity occlusion', () {
    final heights = Float32List(size * size);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        heights[y * size + x] = x / size;
      }
    }
    // The radius stays clear of the discontinuity at the repeating seam.
    expect(bake(heights, scale: 0.5)[16 * size + 16], closeTo(1, 0.001));
  });
}

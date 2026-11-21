import 'dart:math' as math;
import 'dart:typed_data';

/// Bakes local, cosine-weighted ambient visibility for a repeating height field.
///
/// Heights are in [0, 1]; [heightScale] and [radius] are in UV units, matching
/// the POM shader. Re-bake when the height field or displacement scale changes.
/// The finite radius and discrete horizon samples approximate local occlusion;
/// they do not include other objects or directional environment lighting.
Float32List bakeHeightFieldAmbientOcclusion(
  Float32List heights, {
  required int size,
  required double heightScale,
  double radius = 0.125,
  int directions = 16,
}) {
  if (size < 1 ||
      heights.length != size * size ||
      !heightScale.isFinite ||
      heightScale < 0 ||
      !radius.isFinite ||
      radius <= 0 ||
      directions < 4) {
    throw ArgumentError('Invalid height-field dimensions or bake settings');
  }
  final result = Float32List(heights.length);
  if (heightScale == 0) {
    result.fillRange(0, result.length, 1);
    return result;
  }

  // At most one texel between horizon samples, with bilinear reconstruction
  // and wrapped coordinates matching the material's repeating sampler.
  final steps = math.max(1, (radius * size).ceil());
  for (var direction = 0; direction < directions; direction++) {
    final angle = direction * 2 * math.pi / directions;
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    final offsetsX = Int32List(steps);
    final offsetsY = Int32List(steps);
    final fractionsX = Float64List(steps);
    final fractionsY = Float64List(steps);
    final slopeScales = Float64List(steps);
    for (var step = 0; step < steps; step++) {
      final distance = radius * (step + 1) / steps;
      final x = dx * distance * size;
      final y = dy * distance * size;
      offsetsX[step] = x.floor();
      offsetsY[step] = y.floor();
      fractionsX[step] = x - x.floor();
      fractionsY[step] = y - y.floor();
      slopeScales[step] = heightScale / distance;
    }

    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final index = y * size + x;
        final height = heights[index];
        var horizonSlope = -double.infinity;
        for (var step = 0; step < steps; step++) {
          final sx = (x + offsetsX[step]) % size;
          final sy = (y + offsetsY[step]) % size;
          final nextX = (sx + 1) % size;
          final nextY = (sy + 1) % size;
          final fx = fractionsX[step];
          final fy = fractionsY[step];
          final lower = heights[sy * size + sx] * (1 - fx) +
              heights[sy * size + nextX] * fx;
          final upper = heights[nextY * size + sx] * (1 - fx) +
              heights[nextY * size + nextX] * fx;
          final sample = lower * (1 - fy) + upper * fy;
          horizonSlope =
              math.max(horizonSlope, (sample - height) * slopeScales[step]);
        }

        // Use the same central-difference normal as the normal map. Integrate
        // max(dot(normal, light), 0) above the horizon in this azimuth slice,
        // including solid-angle weighting. A slope alone is not a crevice.
        final gx = (heights[y * size + (x + 1) % size] -
                heights[y * size + (x - 1) % size]) *
            size *
            heightScale *
            0.5;
        final gy = (heights[((y + 1) % size) * size + x] -
                heights[((y - 1) % size) * size + x]) *
            size *
            heightScale *
            0.5;
        final invLength = 1 / math.sqrt(gx * gx + gy * gy + 1);
        final a = -(gx * dx + gy * dy) * invLength;
        final b = invLength;
        final elevation = math.max(math.atan(horizonSlope), math.atan2(-a, b));
        final cosine = math.cos(elevation);
        final integral =
            a * (math.pi / 4 - elevation / 2 - math.sin(2 * elevation) / 4) +
                b * cosine * cosine / 2;
        result[index] += 2 * integral / directions;
      }
    }
  }
  for (var i = 0; i < result.length; i++) {
    result[i] = result[i].clamp(0.0, 1.0);
  }
  return result;
}

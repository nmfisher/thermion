import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

void main() {
  group('SphereGeometry', () {
    test('emits only outward-facing, non-degenerate triangles', () {
      const latitudeBands = 8;
      const longitudeBands = 12;
      final geometry = GeometryUtils.sphere(latitudeBands: latitudeBands, longitudeBands: longitudeBands);

      expect(geometry.indices.length ~/ 3, 2 * longitudeBands * (latitudeBands - 1));

      for (var i = 0; i < geometry.indices.length; i += 3) {
        final i0 = geometry.indices[i] * 3;
        final i1 = geometry.indices[i + 1] * 3;
        final i2 = geometry.indices[i + 2] * 3;

        final ax = geometry.vertices[i1] - geometry.vertices[i0];
        final ay = geometry.vertices[i1 + 1] - geometry.vertices[i0 + 1];
        final az = geometry.vertices[i1 + 2] - geometry.vertices[i0 + 2];
        final bx = geometry.vertices[i2] - geometry.vertices[i0];
        final by = geometry.vertices[i2 + 1] - geometry.vertices[i0 + 1];
        final bz = geometry.vertices[i2 + 2] - geometry.vertices[i0 + 2];

        final nx = ay * bz - az * by;
        final ny = az * bx - ax * bz;
        final nz = ax * by - ay * bx;
        final areaSquared = nx * nx + ny * ny + nz * nz;
        expect(areaSquared, greaterThan(1e-12), reason: 'triangle ${i ~/ 3}');

        final cx = geometry.vertices[i0] + geometry.vertices[i1] + geometry.vertices[i2];
        final cy = geometry.vertices[i0 + 1] + geometry.vertices[i1 + 1] + geometry.vertices[i2 + 1];
        final cz = geometry.vertices[i0 + 2] + geometry.vertices[i1 + 2] + geometry.vertices[i2 + 2];
        expect(nx * cx + ny * cy + nz * cz, greaterThan(0), reason: 'triangle ${i ~/ 3}');
      }
    });

    test('uses unit outward vertex normals', () {
      final geometry = GeometryUtils.sphere(latitudeBands: 8, longitudeBands: 12);

      expect(geometry.normals.length, geometry.vertices.length);
      for (var i = 0; i < geometry.vertices.length; i += 3) {
        final x = geometry.vertices[i];
        final y = geometry.vertices[i + 1];
        final z = geometry.vertices[i + 2];
        final nx = geometry.normals[i];
        final ny = geometry.normals[i + 1];
        final nz = geometry.normals[i + 2];

        expect(nx, closeTo(x, 1e-6));
        expect(ny, closeTo(y, 1e-6));
        expect(nz, closeTo(z, 1e-6));
        expect(nx * nx + ny * ny + nz * nz, closeTo(1.0, 1e-6));
      }
    });

    test('validates tessellation', () {
      expect(() => GeometryUtils.sphere(latitudeBands: 1), throwsArgumentError);
      expect(() => GeometryUtils.sphere(longitudeBands: 2), throwsArgumentError);
    });
  });
}

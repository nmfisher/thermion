import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/interface/geometry.dart';

// Unit tests for the Geometry constructor's dummy-attribute behavior.
// Regression coverage for the dummy-UV assignment bug: dummy UVs were
// created locally but never assigned to this.uvs, so hasUVs stayed false
// for geometry constructed without UVs.
void main() {
  // A single triangle.
  final vertices = Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]);
  final indices = [0, 1, 2];

  group('Geometry constructor dummy attributes', () {
    test(
      'createDummyUvs=true supplies zero UVs for UV-less geometry',
      () async {
        final geometry = Geometry(vertices, indices);
        expect(
          geometry.hasUVs,
          true,
          reason: 'dummy UVs should be created and assigned',
        );
        expect(geometry.uvs.length, 3 * 2, reason: 'one UV pair per vertex');
        expect(
          geometry.uvs.every((v) => v == 0.0),
          true,
          reason: 'dummy UVs are zero-filled',
        );
      },
    );

    test('createDummyUvs=false leaves UVs empty', () async {
      final geometry = Geometry(vertices, indices, createDummyUvs: false);
      expect(geometry.hasUVs, false);
      expect(geometry.uvs.length, 0);
    });

    test('provided UVs are preserved (not overwritten by dummies)', () async {
      final uvs = Float32List.fromList([0.1, 0.2, 0.3, 0.4, 0.5, 0.6]);
      final geometry = Geometry(vertices, indices, uvs: uvs);
      expect(geometry.hasUVs, true);
      expect(geometry.uvs, uvs);
    });

    test('createDummyColors=true supplies opaque white RGBA colors', () async {
      final geometry = Geometry(vertices, indices);
      expect(
        geometry.hasColors,
        true,
        reason: 'dummy colors should be created and assigned',
      );
      expect(geometry.colors.length, 3 * 4, reason: 'RGBA per vertex');
      expect(
        geometry.colors.every((c) => c == 1.0),
        true,
        reason: 'dummy colors are opaque white',
      );
    });

    test('createDummyColors=false leaves colors empty', () async {
      final geometry = Geometry(vertices, indices, createDummyColors: false);
      expect(geometry.hasColors, false);
      expect(geometry.colors.length, 0);
    });

    test('dummy UV1 mirrors UV0 when UV0 exists, else zeros', () async {
      final uvs = Float32List.fromList([0.1, 0.2, 0.3, 0.4, 0.5, 0.6]);
      final withUvs = Geometry(vertices, indices, uvs: uvs);
      expect(withUvs.hasUVs1, true);
      expect(withUvs.uvs1, uvs);

      final withoutUvs = Geometry(vertices, indices);
      expect(
        withoutUvs.hasUVs1,
        true,
        reason: 'ubershader requires two UV sets',
      );
      expect(withoutUvs.uvs1.length, 3 * 2);
      expect(withoutUvs.uvs1.every((v) => v == 0.0), true);
    });
  });
}

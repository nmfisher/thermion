import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_surface_orientation.dart';
import 'src/test_io.dart';
import 'package:thermion_dart/src/filament/src/interface/surface_orientation.dart';

void main() {
  setUpAll(initTestBindings);

  for (final withTangents in [false, true]) {
    test('build reads current normals${withTangents ? " and tangents" : ""}', () async {
      Future<List<double>> build(bool configureBeforeEdits) async {
        // The subview and padding exercise both the input offset and byte stride.
        final storage = Float32List.fromList([99, 0, 0, 1, 99, 0, 1, 0, 99]);
        final normals = Float32List.sublistView(storage, 1);
        final tangents = Float32List.fromList([1, 0, 0, 1, 1, 0, 0, 1]);
        final builder = FFISurfaceOrientationBuilder();
        void configure() {
          builder.normals(normals, stride: 16);
          if (withTangents) builder.tangents(tangents);
          // Counts may be configured after the data setters.
          builder.vertexCount(2);
        }

        if (configureBeforeEdits) configure();
        await Future<void>.delayed(Duration.zero);
        normals.setAll(0, [1, 0, 0, 99, 0, 0, 1, 99]);
        tangents.setAll(0, [0, 1, 0, 1, 0, 1, 0, -1]);
        if (!configureBeforeEdits) configure();
        final orientation = await builder.build();
        // A completed orientation must no longer depend on the input arrays.
        normals.fillRange(0, normals.length, 0);
        tangents.fillRange(0, tangents.length, 0);
        try {
          final quats = await orientation.getQuats(QuaternionFormat.FLOAT4, 2) as Float32List;
          expect(quats.every((value) => value.isFinite), true);
          return quats.toList();
        } finally {
          await orientation.destroy();
        }
      }

      expect(await build(true), await build(false));
    });
  }

  for (final shortIndices in [false, true]) {
    test('build reads current positions, UVs and ${shortIndices ? 16 : 32}-bit triangles', () async {
      Future<List<double>> build(bool configureBeforeEdits) async {
        final positions = Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]);
        final normals = Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1]);
        final uvs = Float32List.fromList([0, 0, 1, 0, 0, 1]);
        final indices32 = Uint32List.fromList([0, 1, 2]);
        final indices16 = Uint16List.fromList([0, 1, 2]);
        final builder = FFISurfaceOrientationBuilder();
        void configure() {
          builder.positions(positions);
          builder.normals(normals);
          builder.uvs(uvs);
          if (shortIndices) {
            builder.trianglesUint16(indices16);
          } else {
            builder.trianglesUint32(indices32);
          }
          builder.vertexCount(3);
          builder.triangleCount(1);
        }

        if (configureBeforeEdits) configure();
        await Future<void>.delayed(Duration.zero);
        positions.setAll(0, [0, 0, 0, 0, 1, 0, -1, 0, 0]);
        uvs.setAll(0, [0, 0, 0, 1, 1, 0]);
        indices16.setAll(0, [2, 0, 1]);
        indices32.setAll(0, [2, 0, 1]);
        if (!configureBeforeEdits) configure();
        final orientation = await builder.build();
        positions.fillRange(0, positions.length, 0);
        normals.fillRange(0, normals.length, 0);
        uvs.fillRange(0, uvs.length, 0);
        indices16.fillRange(0, 3, 0);
        indices32.fillRange(0, 3, 0);
        try {
          final quats = await orientation.getQuats(QuaternionFormat.FLOAT4, 3) as Float32List;
          expect(quats.every((value) => value.isFinite), true);
          return quats.toList();
        } finally {
          await orientation.destroy();
        }
      }

      expect(await build(true), await build(false));
    });
  }
}

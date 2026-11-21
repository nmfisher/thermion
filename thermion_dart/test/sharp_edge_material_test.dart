import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper('sharp_edge_material');
  await testHelper.setup();

  test('each CUSTOM0 mask bit draws its opposite edge', () async {
    const size = 128;
    final builder = ViewerBuilder(testHelper).setCameraPosition(Vector3(0, 0, 3)).setViewportDimensions(size, size);
    await builder.execute((result) async {
      final material = await FilamentApp.instance!.createBuiltInMaterial(BuiltInMaterial.sharpEdge);
      addTearDown(material.destroy);
      final edges = await material.createInstance();
      addTearDown(edges.destroy);
      await edges.setParameterFloat4('edgeColor', 1, 0, 0, 1);
      await edges.setParameterFloat('edgeWidth', 3);

      // BC is diagonal, CA is vertical, and AB is horizontal.
      final positions = Float32List.fromList([-0.7, -0.7, 0, 0.7, -0.7, 0, -0.7, 0.7, 0]);
      final thin = inInclusiveRange(1, 8);
      final long = greaterThan(15);
      final cases = [(0, equals(0), equals(0)), (1, long, long), (2, thin, long), (4, long, thin)];
      for (final (mask, expectedWidth, expectedHeight) in cases) {
        final geometry = GeometryUtils.duplicateVerticesWithBarycentrics(positions, [0, 1, 2]);
        for (var corner = 0; corner < 3; corner++) {
          geometry.attribute0[corner * 4 + 3] = mask.toDouble();
        }
        final asset = await result.viewer.createGeometry(geometry, materialInstances: [edges]);
        await result.viewer.addToScene(asset);
        final bytes = (await testHelper.capture(result.viewer.view, null)).values.single;
        final pixels = bytes.buffer.asFloat32List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 4);
        final columns = <int>{};
        final rows = <int>{};
        for (var i = 0; i < pixels.length; i += 4) {
          if (pixels[i] > 0.8 && pixels[i + 1] < 0.2 && pixels[i + 2] < 0.2) {
            columns.add((i ~/ 4) % size);
            rows.add((i ~/ 4) ~/ size);
          }
        }
        await result.viewer.destroyAsset(asset);
        expect(columns.length, expectedWidth, reason: 'mask $mask');
        expect(rows.length, expectedHeight, reason: 'mask $mask');
      }
    });
  });
}

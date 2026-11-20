import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("sharp_edge_material");
  await testHelper.setup();

  test('apply sharp edge material to glTF asset', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .setCameraPosition(Vector3(0, 1, 1.5))
        .execute((result) async {
      final asset = await result.viewer.loadGltf(
          "file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf",
          rebuildVertices: true,
          addToScene: true);

      await testHelper.capture(result.viewer.view, "before_sharp_edge");

      final sharpEdge =
          await FilamentApp.instance!.createSharpEdgeMaterialInstance();
      await sharpEdge.setDoubleSided(true);
      await sharpEdge.setEdgeColor(1.0, 1.0, 1.0, 1.0);
      await sharpEdge.setBaseColor(0.1, 0.1, 0.1, 1.0);
      await sharpEdge.setEdgeWidth(1.0);

      await asset.setMaterialInstanceForAll(sharpEdge.materialInstance);
      await testHelper.capture(result.viewer.view, "sharp_edge_default");

      // Thicker edges
      await sharpEdge.setEdgeWidth(2.0);
      await testHelper.capture(result.viewer.view, "sharp_edge_thick");

      // Custom colors
      await sharpEdge.setEdgeWidth(1.0);
      await sharpEdge.setEdgeColor(1.0, 0.0, 0.0, 1.0);
      await sharpEdge.setBaseColor(0.05, 0.05, 0.05, 1.0);
      await testHelper.capture(
          result.viewer.view, "sharp_edge_red_on_dark");

      await result.viewer.removeFromScene(asset);
    });
  });

  test('apply sharp edge material to cube', () async {
    await ViewerBuilder(testHelper)
        .setCameraPosition(Vector3(2, 2, 2))
        .execute((result) async {
      final asset = await result.viewer.loadGltf(
          "file://${testHelper.assetsDir}/cube.glb",
          rebuildVertices: true,
          addToScene: true);

      await testHelper.capture(result.viewer.view, "cube_before");

      final sharpEdge =
          await FilamentApp.instance!.createSharpEdgeMaterialInstance();
      await sharpEdge.setEdgeColor(1.0, 1.0, 1.0, 1.0);
      await sharpEdge.setBaseColor(0.1, 0.1, 0.1, 1.0);
      await sharpEdge.setEdgeWidth(1.5);

      await asset.setMaterialInstanceForAll(sharpEdge.materialInstance);
      await testHelper.capture(result.viewer.view, "cube_sharp_edge");

      await result.viewer.removeFromScene(asset);
    });
  });
}

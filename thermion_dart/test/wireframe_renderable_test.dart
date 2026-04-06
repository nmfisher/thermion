import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("wireframe_renderable");
  await testHelper.setup();

  test('load with rebuildVertices and apply wireframe material', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .setCameraPosition(Vector3(0, 1, 1.5))
        .execute((result) async {
      final asset1 = await result.viewer.loadGltf(
          "file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf",
          rebuildVertices: false,
          addToScene: true);
      await testHelper.capture(
          result.viewer.view, "flighthelmet_rebuildVertices_false");
      await result.viewer.removeFromScene(asset1);
      final asset = await result.viewer.loadGltf(
          "file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf",
          rebuildVertices: true,
          addToScene: true);

      await testHelper.capture(result.viewer.view, "flighthelmet_rebuildVertices_true");

      // Use typed wireframe wrapper
      final wireframe = await FilamentApp.instance!.createWireframeMaterial();
      await wireframe.setEdgeColor(0.3, 0.3, 0.3, 1.0);
      await wireframe.setFaceColor(0.1, 0.1, 0.1, 1.0);
      await wireframe.setEdgeWidth(0.5);
      await wireframe.setDoubleSided(true);

      await asset.setMaterialInstanceForAll(wireframe.materialInstance);
      await testHelper.capture(result.viewer.view, "flighthelmet_rebuildVertices_true_wireframe");
    });
  });

  test('load with rebuildVertices and apply ubershader material', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      final asset = await result.viewer.loadGltf(
          "file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf",
          rebuildVertices: true);

      await result.viewer.addToScene(asset);

      // Use typed ubershader wrapper for solid shading look
      final ubershader = await FilamentApp.instance!.createUbershaderMaterial(
        doubleSided: true,
      );

      await ubershader.setBaseColorFactor(0.8, 0.8, 0.8, 1.0);
      await ubershader.setMetallicFactor(0.0);
      await ubershader.setRoughnessFactor(1.0);

      await asset.setMaterialInstanceForAll(ubershader.materialInstance);
      await testHelper.capture(result.viewer.view, "preserved_solid");
    });
  });

  test('load with rebuildVertices on instanced glTF', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      final asset = await result.viewer.loadGltf(
          "file://${testHelper.assetsDir}/cube.glb",
          addToScene: true,
          initialInstances: 2,
          rebuildVertices: true);

      final instance2 = await asset.createInstance();
      await instance2.setTransform(Matrix4.translation(Vector3(2, 0, 0)));
      await result.viewer.addToScene(instance2);
      await testHelper.capture(
          result.viewer.view, "instanced_preserved_before");

      // Use typed wireframe wrapper
      final wireframe = await FilamentApp.instance!.createWireframeMaterial();
      await wireframe.setEdgeColor(1.0, 0.0, 1.0, 1.0);
      await wireframe.setFaceColor(0.0, 0.0, 0.0, 1.0);
      await wireframe.setEdgeWidth(1.0);
      await wireframe.setDoubleSided(true);

      await instance2.setMaterialInstanceForAll(wireframe.materialInstance);
      await testHelper.capture(
          result.viewer.view, "instanced_preserved_wireframe");
    });
  });
}

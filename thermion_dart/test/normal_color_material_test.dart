import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("normal_color_material");
  await testHelper.setup();

  test('apply normal color material to glTF asset', () async {
    await ViewerBuilder(testHelper)
        .addSun()
        .setCameraPosition(Vector3(0, 1, 1.5))
        .execute((result) async {
      final asset = await result.viewer.loadGltf(
          "file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf",
          rebuildVertices: true,
          addToScene: true);

      await testHelper.capture(result.viewer.view, "before_normal_color");

      final normalColor =
          await FilamentApp.instance!.createNormalColorMaterialInstance();
      await normalColor.setDoubleSided(true);

      await asset.setMaterialInstanceForAll(normalColor.materialInstance);
      await testHelper.capture(result.viewer.view, "normal_color_default");

      // Switch to absolute value mode
      await normalColor.setUseAbsoluteValue(true);
      await testHelper.capture(
          result.viewer.view, "normal_color_absolute_value");

      // Test opacity
      await normalColor.setOpacity(0.5);
      await testHelper.capture(
          result.viewer.view, "normal_color_half_opacity");

      await result.viewer.removeFromScene(asset);
    });
  });

  test('apply normal color material to cube', () async {
    await ViewerBuilder(testHelper)
        .setCameraPosition(Vector3(2, 2, 2))
        .execute((result) async {
      final asset = await result.viewer.loadGltf(
          "file://${testHelper.assetsDir}/cube.glb",
          rebuildVertices: true,
          addToScene: true);

      final normalColor =
          await FilamentApp.instance!.createNormalColorMaterialInstance();

      await asset.setMaterialInstanceForAll(normalColor.materialInstance);
      await testHelper.capture(result.viewer.view, "cube_normal_color");

      await normalColor.setUseAbsoluteValue(true);
      await testHelper.capture(
          result.viewer.view, "cube_normal_color_absolute");

      await result.viewer.removeFromScene(asset);
    });
  });
}

import 'package:thermion_dart/src/filament/src/implementation/ffi_indirect_light.dart';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("lights");
  await testHelper.setup();

  test('add/clear point light', () async {
    await testHelper.withViewer((viewer) async {
      await viewer.loadGltf("file://${testHelper.testDir}/assets/cube.glb");

      var light = await viewer.addDirectLight(
          DirectLight.point(intensity: 1000000, falloffRadius: 10));
      await viewer.setLightPosition(light, 1, 2, 2);
      await testHelper.capture(viewer.view, "add_point_light");
      await viewer.setLightPosition(light, -1, 2, 2);
      await testHelper.capture(viewer.view, "move_point_light");
      await viewer.removeLight(light);
      await testHelper.capture(viewer.view, "remove_point_light");
    });
  });

  test('load/remove ibl from KTX', () async {
    await testHelper.withViewer((viewer) async {
      var asset =
          await viewer.loadGltf("file://${testHelper.testDir}/assets/cube.glb");
      await viewer
          .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
      await testHelper.capture(viewer.view, "ibl_ktx_loaded");
      await viewer.removeIbl();
      await testHelper.capture(viewer.view, "ibl_ktx_removed");
    }, cameraPosition: Vector3(0, 0, 5));
  });

  test('load/remove ibl with manually constructed texture', () async {
    await testHelper.withViewer((viewer) async {
      var asset =
          await viewer.loadGltf("file://${testHelper.testDir}/assets/cube.glb");

      final texture = await FilamentApp.instance!.createTexture(1, 1,
          textureSamplerType: TextureSamplerType.SAMPLER_CUBEMAP,
          flags: {
            TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
          });
      await texture.setImage(
          0,
          Float32List.fromList(List<double>.filled(1 * 1 * 4, 1.0))
              .asUint8List(),
          1,
          1,
          PixelDataFormat.RGBA,
          PixelDataType.FLOAT);

      var indirectLight = await FFIIndirectLight.fromIrradianceTexture(
          texture,
          reflectionsTexture: texture,
          intensity: 30000.0);
      final scene = await viewer.view.getScene();
      await scene.setIndirectLight(indirectLight);

      await testHelper.capture(viewer.view, "ibl_from_texture_loaded");

      await viewer.removeIbl();
      await testHelper.capture(viewer.view, "ibl_from_texture_removed");
    }, cameraPosition: Vector3(0, 0, 5), addSkybox: true);
  });
}

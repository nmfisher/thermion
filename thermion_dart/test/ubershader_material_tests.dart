import 'dart:io';
import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("material");

  await testHelper.setup();

  test('ubershader material with color only', () async {
    await testHelper.withViewer((viewer) async {
      var materialInstance =
          await FilamentApp.instance!.createUbershaderMaterialInstance();
      await viewer
          .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
      var cube = await viewer.createGeometry(
          GeometryHelper.cube(normals: true, uvs: true),
          materialInstances: [materialInstance]);

      await materialInstance.setParameterFloat4(
          "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
      await materialInstance.setParameterInt("baseColorIndex", -1);
      await testHelper.capture(viewer.view, "ubershader_material_base_color");
      await materialInstance.destroy();
    }, bg: kRed, postProcessing: true);
  });

  test('ubershader + baseColorMap texture', () async {
    await testHelper.withViewer((viewer) async {
      var materialInstance = await FilamentApp.instance!
          .createUbershaderMaterialInstance(unlit: true);
      final cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstances: [materialInstance]);
      var data =
          File("${testHelper.testDir}/assets/cube_texture_512x512_flipped.png")
              .readAsBytesSync();
      final image = await FilamentApp.instance!.decodeImage(data);
      final texture = await FilamentApp.instance!.createTexture(
          await image.getWidth(), await image.getHeight(),
          textureFormat: TextureFormat.RGBA32F);
      await texture.setLinearImage(
          image, PixelDataFormat.RGBA, PixelDataType.FLOAT);
      final sampler = await FilamentApp.instance!.createTextureSampler();
      await materialInstance.setParameterFloat4(
          "baseColorFactor", 1.0, 1.0, 1.0, 0.0);
      await materialInstance.setParameterInt("baseColorIndex", 0);
      await materialInstance.setParameterTexture(
          "baseColorMap", texture, sampler);

      await testHelper.capture(
          viewer.view, "geometry_cube_with_custom_material_ubershader_texture");
      await viewer.destroyAsset(cube);
      await materialInstance.destroy();
      await texture.dispose();
    });
  });

  test('baseColorMap texture with mip levels', () async {
    await testHelper.withViewer((viewer) async {
      var materialInstance = await FilamentApp.instance!
          .createUbershaderMaterialInstance(unlit: true);
      final cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstances: [materialInstance]);

      final red = await FilamentApp.instance!.decodeImage(
          File("${testHelper.testDir}/assets/red_24x24.png").readAsBytesSync());
      final green = await FilamentApp.instance!.decodeImage(
          File("${testHelper.testDir}/assets/green_12x12.png").readAsBytesSync());

      final texture = await FilamentApp.instance!
          .createTexture(24, 24, levels: 2, textureFormat: TextureFormat.RGB32F);

      expect(await texture.getLevels(), 2);

      final redF32 = await red.getData();
      final greenF32 = await green.getData();

      await texture.setImage(
          0,
          redF32.buffer.asUint8List(redF32.offsetInBytes),
          24,
          24,
          await red.getChannels(),
          PixelDataFormat.RGB,
          PixelDataType.FLOAT);
      await texture.setImage(
          1,
          greenF32.buffer.asUint8List(greenF32.offsetInBytes),
          12,
          12,
          await green.getChannels(),
          PixelDataFormat.RGB,
          PixelDataType.FLOAT);

      final sampler = await FilamentApp.instance!.createTextureSampler(minFilter: TextureMinFilter.NEAREST_MIPMAP_LINEAR);

      await materialInstance.setParameterFloat4(
          "baseColorFactor", 1.0, 1.0, 1.0, 0.0);
      await materialInstance.setParameterInt("baseColorIndex", 0);
      await materialInstance.setParameterTexture(
          "baseColorMap", texture, sampler);

      await testHelper.capture(viewer.view, "mip_level_0");

      final camera = await viewer.getActiveCamera();
      await viewer.view.setFrustumCullingEnabled(false);
      await camera.lookAt(Vector3(0, 0, 600));
      await testHelper.capture(viewer.view, "mip_level_1");
      await viewer.destroyAsset(cube);
      await materialInstance.destroy();
      await texture.dispose();
    });
  });
}

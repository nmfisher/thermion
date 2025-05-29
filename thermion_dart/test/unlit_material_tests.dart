import 'dart:io';
import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("material");

  await testHelper.setup();

  test('unlit + baseColorFactor', () async {
    await testHelper.withViewer((viewer) async {
      await viewer.setPostProcessing(true);
      await viewer.setToneMapping(ToneMapper.LINEAR);

      var materialInstance =
          await FilamentApp.instance!.createUnlitMaterialInstance();
      var cube = await viewer.createGeometry(
          GeometryHelper.cube(normals: false, uvs: false),
          materialInstances: [materialInstance]);

      await materialInstance.setParameterFloat4(
          "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
      await materialInstance.setParameterInt("baseColorIndex", -1);
      await testHelper.capture(viewer.view, "unlit_material_base_color");
      await materialInstance.destroy();
    }, bg: kRed);
  });

  test('unlit + baseColorMap', () async {
    await testHelper.withViewer((viewer) async {
      var materialInstance =
          await await FilamentApp.instance!.createUnlitMaterialInstance();
      var cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstances: [materialInstance]);

      await materialInstance.setParameterFloat4(
          "baseColorFactor", 1.0, 1.0, 1.0, 1.0);
      // await materialInstance.setParameterFloat2("uvScale", 1.0, 1.0);
      await materialInstance.setParameterInt("baseColorIndex", 0);

      var data = File("${testHelper.testDir}/assets/cube_texture_512x512.png")
          .readAsBytesSync();
      final image = await await FilamentApp.instance!.decodeImage(data);

      final texture = await await FilamentApp.instance!.createTexture(
          await image.getWidth(), await image.getHeight(),
          textureFormat: TextureFormat.RGBA32F);
      await texture.setLinearImage(
          image, PixelDataFormat.RGBA, PixelDataType.FLOAT);
      final sampler = await await FilamentApp.instance!.createTextureSampler();

      await materialInstance.setParameterTexture(
          "baseColorMap", texture, sampler);

      await testHelper.capture(viewer.view, "unlit_baseColorMap");

      await image.destroy();
      await texture.dispose();
      await sampler.dispose();

      await materialInstance.destroy();
    });
  });

  test('unlit + baseColorMap (apply material after creation)', () async {
    await testHelper.withViewer((viewer) async {
      var cube = await viewer
          .createGeometry(GeometryHelper.cube(), materialInstances: []);
      var materialInstance =
          await FilamentApp.instance!.createUnlitMaterialInstance();
      await materialInstance.setParameterFloat4(
          "baseColorFactor", 1.0, 1.0, 1.0, 1.0);
      // await materialInstance.setParameterFloat2("uvScale", 1.0, 1.0);
      await materialInstance.setParameterInt("baseColorIndex", 0);

      var data = File("${testHelper.testDir}/assets/cube_texture_512x512.png")
          .readAsBytesSync();
      final image = await FilamentApp.instance!.decodeImage(data);

      final texture = await FilamentApp.instance!.createTexture(
          await image.getWidth(), await image.getHeight(),
          textureFormat: TextureFormat.RGBA32F);
      await texture.setLinearImage(
          image, PixelDataFormat.RGBA, PixelDataType.FLOAT);
      final sampler = await FilamentApp.instance!.createTextureSampler();

      await materialInstance.setParameterTexture(
          "baseColorMap", texture, sampler);
      await cube.setMaterialInstanceAt(materialInstance);
      await testHelper.capture(
          viewer.view, "unlit_baseColorMap_material_created_after");

      await image.destroy();
      await texture.dispose();
      await sampler.dispose();

      await materialInstance.destroy();
    });
  });

  test('unlit + baseColorMap (fetch material after creation)', () async {
    await testHelper.withViewer((viewer) async {
      var materialInstance =
          await FilamentApp.instance!.createUnlitMaterialInstance();
      var cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstances: [materialInstance]);

      materialInstance = await cube.getMaterialInstanceAt(index: 0);

      await materialInstance.setParameterFloat4(
          "baseColorFactor", 1.0, 1.0, 1.0, 1.0);
      await materialInstance.setParameterInt("baseColorIndex", 0);

      var data = File("${testHelper.testDir}/assets/cube_texture_512x512.png")
          .readAsBytesSync();
      final image = await FilamentApp.instance!.decodeImage(data);

      final texture = await FilamentApp.instance!.createTexture(
          await image.getWidth(), await image.getHeight(),
          textureFormat: TextureFormat.RGBA32F);
      await texture.setLinearImage(
          image, PixelDataFormat.RGBA, PixelDataType.FLOAT);
      final sampler = await FilamentApp.instance!.createTextureSampler();

      await materialInstance.setParameterTexture(
          "baseColorMap", texture, sampler);
      await cube.setMaterialInstanceAt(materialInstance);
      await testHelper.capture(
          viewer.view, "unlit_baseColorMap_fetch_material");

      await image.destroy();
      await texture.dispose();
      await sampler.dispose();

      await materialInstance.destroy();
    });
  });

  test('unlit material with color + alpha', () async {
    await testHelper.withViewer((viewer) async {
      await viewer.setPostProcessing(true);
      await viewer.setToneMapping(ToneMapper.LINEAR);

      var materialInstance =
          await FilamentApp.instance!.createUnlitMaterialInstance();
      var cube = await viewer.createGeometry(
          GeometryHelper.cube(normals: false, uvs: false),
          materialInstances: [materialInstance]);

      await materialInstance.setParameterFloat4(
          "baseColorFactor", 0.0, 1.0, 0.0, 0.1);
      await materialInstance.setParameterInt("baseColorIndex", -1);
      await testHelper.capture(viewer.view, "unlit_material_base_color_alpha");
      await materialInstance.destroy();
    }, bg: kRed);
  });

  test('unlit fixed size material', () async {
    var viewer = await testHelper.createViewer();
    await viewer.setCameraPosition(0, 0, 6);
    await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);
    await viewer.setPostProcessing(true);
    await viewer.setToneMapping(ToneMapper.LINEAR);

    var materialInstance = await viewer.createUnlitFixedSizeMaterialInstance();
    var cube = await viewer.createGeometry(GeometryHelper.cube(),
        materialInstances: [materialInstance]);

    await materialInstance.setParameterFloat4(
        "baseColorFactor", 0.0, 1.0, 0.0, 1.0);

    await testHelper.capture(viewer.view, "unlit_fixed_size_default_scale");

    await materialInstance.setParameterFloat("scale", 10.0);

    await testHelper.capture(viewer.view, "unlit_fixed_size_scale_10");

    await viewer.dispose();
  });
}

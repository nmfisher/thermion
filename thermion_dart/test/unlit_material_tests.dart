import 'dart:io';
import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

Future<
    ({
      ThermionAsset blueCube,
      MaterialInstance blueMaterialInstance,
      ThermionAsset greenCube,
      MaterialInstance greenMaterialInstance
    })> setup(ThermionViewer viewer) async {
  var blueMaterialInstance =
      await FilamentApp.instance!.createUnlitMaterialInstance();
  final blueCube = await viewer.createGeometry(GeometryHelper.cube(),
      materialInstances: [blueMaterialInstance]);
  await blueMaterialInstance.setParameterFloat4(
      "baseColorFactor", 0.0, 0.0, 1.0, 1.0);

  // Position blue cube slightly behind and to the right
  await blueCube.setTransform(Matrix4.translation(Vector3(1.0, 0.0, -1.0)));

  var greenMaterialInstance =
      await FilamentApp.instance!.createUnlitMaterialInstance();
  final greenCube = await viewer.createGeometry(GeometryHelper.cube(),
      materialInstances: [greenMaterialInstance]);
  await greenMaterialInstance.setParameterFloat4(
      "baseColorFactor", 0.0, 1.0, 0.0, 1.0);

  return (
    blueCube: blueCube,
    blueMaterialInstance: blueMaterialInstance,
    greenCube: greenCube,
    greenMaterialInstance: greenMaterialInstance
  );
}


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

    test('disable depth write', () async {
      await testHelper.withViewer((viewer) async {
        final (
          :blueCube,
          :blueMaterialInstance,
          :greenCube,
          :greenMaterialInstance
        ) = await setup(viewer);

        // With depth write enabled on both materials, green cube renders behind the blue cube
        await testHelper.capture(
            viewer.view, "material_instance_depth_write_enabled");

        // Disable depth write on green cube, blue cube will always appear in front (green cube renders behind everything, including the image material, so not it's not visible at all)
        await greenMaterialInstance.setDepthWriteEnabled(false);
        await testHelper.capture(
            viewer.view, "material_instance_depth_write_disabled");

        // Set priority for greenCube to render last, making it appear in front
        await viewer.setPriority(greenCube.entity, 7);
        await testHelper.capture(viewer.view,
            "material_instance_depth_write_disabled_with_priority");
      });
    });

    test('enable stencil write', () async {
      await testHelper.withViewer((viewer) async {
        final (
          :blueCube,
          :blueMaterialInstance,
          :greenCube,
          :greenMaterialInstance
        ) = await setup(viewer);

        // force depth to always pass so we're just comparing stencil test
        await greenMaterialInstance.setDepthFunc(SamplerCompareFunction.A);
        await blueMaterialInstance.setDepthFunc(SamplerCompareFunction.A);

        await testHelper.capture(
            viewer.view, "material_instance_depth_pass_stencil_disabled");

        assert(await greenMaterialInstance.isStencilWriteEnabled() == false);
        assert(await blueMaterialInstance.isStencilWriteEnabled() == false);

        await greenMaterialInstance.setStencilWriteEnabled(true);
        await blueMaterialInstance.setStencilWriteEnabled(true);

        assert(await greenMaterialInstance.isStencilWriteEnabled() == true);
        assert(await blueMaterialInstance.isStencilWriteEnabled() == true);

        // just a sanity check, no difference from the last
        await testHelper.capture(
            viewer.view, "material_instance_depth_pass_stencil_enabled");
      }, postProcessing: true, bg: null);
    });

    test('stencil always fail', () async {
      await testHelper.withViewer((viewer) async {
        final (
          :blueCube,
          :blueMaterialInstance,
          :greenCube,
          :greenMaterialInstance
        ) = await setup(viewer);

        // force depth to always pass so we're just comparing stencil test
        await greenMaterialInstance.setDepthFunc(SamplerCompareFunction.A);
        await blueMaterialInstance.setDepthFunc(SamplerCompareFunction.A);

        await greenMaterialInstance.setStencilWriteEnabled(true);

        assert(await greenMaterialInstance.isStencilWriteEnabled() == true);

        await greenMaterialInstance
            .setStencilCompareFunction(SamplerCompareFunction.N);

        // green cube isn't rendered
        await testHelper.capture(
            viewer.view, "material_instance_stencil_always_fail");
      }, postProcessing: true, bg: null);
    });

    test('fail stencil not equal', () async {
      await testHelper.withViewer((viewer) async {
        final (
          :blueCube,
          :blueMaterialInstance,
          :greenCube,
          :greenMaterialInstance
        ) = await setup(viewer);

        // this ensures the blue cube is rendered before the green cube
        await viewer.setPriority(blueCube.entity, 0);
        await viewer.setPriority(greenCube.entity, 1);

        await blueMaterialInstance.setStencilWriteEnabled(true);
        await blueMaterialInstance.setStencilReferenceValue(1);
        await blueMaterialInstance
            .setStencilCompareFunction(SamplerCompareFunction.A);
        await blueMaterialInstance
            .setStencilOpDepthStencilPass(StencilOperation.REPLACE);

        await greenMaterialInstance.setStencilReferenceValue(1);
        await greenMaterialInstance
            .setStencilCompareFunction(SamplerCompareFunction.E);

        // green cube is only rendered where it intersects with the blue cube
        await testHelper.capture(viewer.view, "fail_stencil_ne");
      }, postProcessing: true);
    });
}

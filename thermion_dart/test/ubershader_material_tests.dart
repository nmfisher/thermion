import 'dart:io';
import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("material");

  await testHelper.setup();

  test('ubershader material with color only', () async {
    await testHelper.withViewer(
      (viewer) async {
        var materialInstance = await FilamentApp.instance!.createUbershaderMaterialInstance();
        await viewer.loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");
        var cube = await viewer.createGeometry(
          GeometryUtils.cube(normals: true, uvs: true),
          materialInstances: [materialInstance],
        );

        await materialInstance.setParameterFloat4("baseColorFactor", 0.0, 1.0, 0.0, 1.0);
        await materialInstance.setParameterInt("baseColorIndex", -1);
        await testHelper.capture(viewer.view, "ubershader_material_base_color");
        await materialInstance.destroy();
      },
      bg: kRed,
      postProcessing: true,
    );
  });

  test('ubershader + baseColorMap texture', () async {
    await testHelper.withViewer((viewer) async {
      var materialInstance = await FilamentApp.instance!.createUbershaderMaterialInstance(unlit: true);
      final cube = await viewer.createGeometry(GeometryUtils.cube(), materialInstances: [materialInstance]);
      await materialInstance.setParameterFloat4("baseColorFactor", 0.0, 0.0, 1.0, 1.0);
      await testHelper.capture(viewer.view, "ubershader_notexture");
      var data = File("${testHelper.assetsDir}/cube_texture_512x512.png").readAsBytesSync();
      final image = await FilamentApp.instance!.decodeImage(data);

      final channels = await image.getChannels();
      final texture = await FilamentApp.instance!.createTexture(
        await image.getWidth(),
        await image.getHeight(),
        textureFormat: channels == 4 ? TextureFormat.RGBA32F : TextureFormat.RGB32F,
      );

      await texture.setLinearImage(
        image,
        channels == 4 ? PixelDataFormat.RGBA : PixelDataFormat.RGB,
        PixelDataType.FLOAT,
      );

      final sampler = await FilamentApp.instance!.createTextureSampler();
      await materialInstance.setParameterFloat4("baseColorFactor", 1.0, 1.0, 1.0, 0.0);
      await materialInstance.setParameterInt("baseColorIndex", 0);
      await materialInstance.setParameterTexture("baseColorMap", texture, sampler);

      await testHelper.capture(viewer.view, "ubershader_textured");
      await viewer.destroyAsset(cube);
      await materialInstance.destroy();
      await texture.dispose();
    });
  });

  test('baseColorMap texture with mip levels', () async {
    await testHelper.withViewer((viewer) async {
      var materialInstance = await FilamentApp.instance!.createUbershaderMaterialInstance(unlit: true);
      final cube = await viewer.createGeometry(GeometryUtils.cube(), materialInstances: [materialInstance]);

      final red = await FilamentApp.instance!.decodeImage(
        File("${testHelper.assetsDir}/red_24x24.png").readAsBytesSync(),
      );
      final green = await FilamentApp.instance!.decodeImage(
        File("${testHelper.assetsDir}/green_12x12.png").readAsBytesSync(),
      );

      final texture = await FilamentApp.instance!.createTexture(24, 24, levels: 2, textureFormat: TextureFormat.RGB32F);

      expect(await texture.getLevels(), 2);

      final redF32 = await red.getData();
      final greenF32 = await green.getData();

      await texture.setImage(
        0,
        redF32.buffer.asUint8List(redF32.offsetInBytes, redF32.lengthInBytes),
        24,
        24,
        // await red.getChannels(),
        PixelDataFormat.RGB,
        PixelDataType.FLOAT,
      );
      await texture.setImage(
        1,
        greenF32.buffer.asUint8List(greenF32.offsetInBytes, greenF32.lengthInBytes),
        12,
        12,
        // await green.getChannels(),
        PixelDataFormat.RGB,
        PixelDataType.FLOAT,
      );

      final sampler = await FilamentApp.instance!.createTextureSampler(
        minFilter: TextureMinFilter.NEAREST_MIPMAP_LINEAR,
      );

      await materialInstance.setParameterFloat4("baseColorFactor", 1.0, 1.0, 1.0, 0.0);
      await materialInstance.setParameterInt("baseColorIndex", 0);
      await materialInstance.setParameterTexture("baseColorMap", texture, sampler);

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

  test('ubershader material with baseColorUvMatrix', () async {
    await testHelper.withViewer((viewer) async {
      var materialInstance = await FilamentApp.instance!.createUbershaderMaterialInstance(unlit: true);
      final cube = await viewer.createGeometry(GeometryUtils.cube(), materialInstances: [materialInstance]);

      var data = File("${testHelper.assetsDir}/cube_texture_512x512.png").readAsBytesSync();
      final image = await FilamentApp.instance!.decodeImage(data);
      final channels = await image.getChannels();
      final texture = await FilamentApp.instance!.createTexture(
        await image.getWidth(),
        await image.getHeight(),
        textureFormat: channels == 4 ? TextureFormat.RGBA32F : TextureFormat.RGB32F,
      );
      await texture.setLinearImage(
        image,
        channels == 4 ? PixelDataFormat.RGBA : PixelDataFormat.RGB,
        PixelDataType.FLOAT,
      );
      final sampler = await FilamentApp.instance!.createTextureSampler();

      await materialInstance.setParameterFloat4("baseColorFactor", 1.0, 1.0, 1.0, 1.0);
      await materialInstance.setParameterInt("baseColorIndex", 0);
      await materialInstance.setParameterTexture("baseColorMap", texture, sampler);

      await testHelper.capture(viewer.view, "ubershader_material_base_color_uv_matrix_identity");

      final uvMatrix = Matrix3.fromList([
        0.0, -1.0, 1.0, // Rotate 90° and translate
        1.0, 0.0, 0.0, //
        0.0, 0.0, 1.0, // Homogeneous coordinate
      ]);

      await materialInstance.setParameterMat3("baseColorUvMatrix", uvMatrix);

      await testHelper.capture(viewer.view, "ubershader_material_base_color_uv_matrix_rotated");
      await viewer.destroyAsset(cube);
      await materialInstance.destroy();
      await texture.dispose();
    });
  });

  test('getTransparencyMode', () async {
    await testHelper.withViewer((viewer) async {
      var materialInstance = await FilamentApp.instance!.createUbershaderMaterialInstance();

      // Default transparency mode should be DEFAULT
      var mode = await materialInstance.getTransparencyMode();
      expect(mode, TransparencyMode.DEFAULT);

      // Set to TWO_PASSES_ONE_SIDE
      await materialInstance.setTransparencyMode(TransparencyMode.TWO_PASSES_ONE_SIDE);
      mode = await materialInstance.getTransparencyMode();
      expect(mode, TransparencyMode.TWO_PASSES_ONE_SIDE);

      // Set to TWO_PASSES_TWO_SIDES
      await materialInstance.setTransparencyMode(TransparencyMode.TWO_PASSES_TWO_SIDES);
      mode = await materialInstance.getTransparencyMode();
      expect(mode, TransparencyMode.TWO_PASSES_TWO_SIDES);

      // Set back to DEFAULT
      await materialInstance.setTransparencyMode(TransparencyMode.DEFAULT);
      mode = await materialInstance.getTransparencyMode();
      expect(mode, TransparencyMode.DEFAULT);

      await materialInstance.destroy();
    });
  });

  test('UbershaderMaterial typed wrapper', () async {
    await testHelper.withViewer(
      (viewer) async {
        final ubershader = await FilamentApp.instance!.createUbershaderMaterial();

        await viewer.loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");

        await ubershader.setBaseColorFactor(0.0, 1.0, 0.0, 1.0);
        await ubershader.setBaseColorUV(-1);
        await ubershader.setMetallicFactor(0.0);
        await ubershader.setRoughnessFactor(1.0);

        await viewer.createGeometry(
          GeometryUtils.cube(normals: true, uvs: true),
          materialInstances: [ubershader.materialInstance],
        );

        await testHelper.capture(viewer.view, "ubershader_typed_wrapper_base_color");

        // Verify the underlying instance is accessible
        expect(ubershader.materialInstance, isNotNull);

        await ubershader.materialInstance.destroy();
      },
      bg: kRed,
      postProcessing: true,
    );
  });
}

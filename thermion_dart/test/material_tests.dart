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

  group("unlit material", () {
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

        var data =
            File("${testHelper.testDir}/assets/cube_texture2_512x512.png")
                .readAsBytesSync();
        final image = await await FilamentApp.instance!.decodeImage(data);

        final texture = await await FilamentApp.instance!.createTexture(
            await image.getWidth(), await image.getHeight(),
            textureFormat: TextureFormat.RGBA32F);
        await texture.setLinearImage(
            image, PixelDataFormat.RGBA, PixelDataType.FLOAT);
        final sampler =
            await await FilamentApp.instance!.createTextureSampler();

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

        var data =
            File("${testHelper.testDir}/assets/cube_texture2_512x512.png")
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

        var data =
            File("${testHelper.testDir}/assets/cube_texture2_512x512.png")
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
        await testHelper.capture(
            viewer.view, "unlit_material_base_color_alpha");
        await materialInstance.destroy();
      }, bg: kRed);
    });

    test('unlit fixed size material', () async {
      var viewer = await testHelper.createViewer();
      await viewer.setCameraPosition(0, 0, 6);
      await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);
      await viewer.setPostProcessing(true);
      await viewer.setToneMapping(ToneMapper.LINEAR);

      var materialInstance =
          await viewer.createUnlitFixedSizeMaterialInstance();
      var cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstances: [materialInstance]);

      await materialInstance.setParameterFloat4(
          "baseColorFactor", 0.0, 1.0, 0.0, 1.0);

      await testHelper.capture(viewer.view, "unlit_fixed_size_default_scale");

      await materialInstance.setParameterFloat("scale", 10.0);

      await testHelper.capture(viewer.view, "unlit_fixed_size_scale_10");

      await viewer.dispose();
    });
  });

  group("ubershader material tests", () {
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
        var data = File(
                "${testHelper.testDir}/assets/cube_texture2_512x512_flipped.png")
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

        await testHelper.capture(viewer.view,
            "geometry_cube_with_custom_material_ubershader_texture");
        await viewer.destroyAsset(cube);
        await materialInstance.destroy();
        await texture.dispose();
      });
    });

    test('create cube with custom material instance (unlit)', () async {
      var viewer = await testHelper.createViewer();
      await viewer.setCameraPosition(0, 2, 6);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);
      await viewer.setPostProcessing(true);
      await viewer.setToneMapping(ToneMapper.LINEAR);

      var materialInstance =
          await FilamentApp.instance!.createUnlitMaterialInstance();
      var cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstances: [materialInstance]);

      var textureData =
          File("${testHelper.testDir}/assets/cube_texture_512x512.png")
              .readAsBytesSync();
      throw UnimplementedError();
      // var texture = await FilamentApp.instance!.createTexture(textureData);
      // await viewer.applyTexture(texture, cube.entity);
      // await testHelper.capture(
      //     viewer, "geometry_cube_with_custom_material_unlit_texture_only");
      // await viewer.destroyAsset(cube);

      // cube = await viewer.createGeometry(GeometryHelper.cube(),
      //     materialInstances: [materialInstance]);
      // // reusing same material instance, so set baseColorIndex to -1 to disable the texture
      // await materialInstance.setParameterInt("baseColorIndex", -1);
      // await materialInstance.setParameterFloat4(
      //     "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
      // await testHelper.capture(
      //     viewer, "geometry_cube_with_custom_material_unlit_color_only");
      // await viewer.destroyAsset(cube);

      // cube = await viewer.createGeometry(GeometryHelper.cube(),
      //     materialInstances: [materialInstance]);
      // // now set baseColorIndex to 0 to enable the texture and the base color
      // await materialInstance.setParameterInt("baseColorIndex", 0);
      // await materialInstance.setParameterFloat4(
      //     "baseColorFactor", 0.0, 1.0, 0.0, 0.5);
      // await viewer.applyTexture(texture, cube.entity);

      // await testHelper.capture(
      //     viewer, "geometry_cube_with_custom_material_unlit_color_and_texture");

      // await viewer.destroyAsset(cube);

      // await viewer.destroyTexture(texture);
      // await materialInstance.destroy();
      // await viewer.dispose();
    });
  });
  group('depth & stencil', () {
    test('set depth func to always', () async {
      await testHelper.withViewer((viewer) async {
        final (
          :blueCube,
          :blueMaterialInstance,
          :greenCube,
          :greenMaterialInstance
        ) = await setup(viewer);

        // with default depth func, blue cube renders behind the green cube
        await testHelper.capture(
            viewer.view, "material_instance_depth_func_default");

        await greenMaterialInstance.setDepthFunc(SamplerCompareFunction.A);

        // with green material depth func set to always pass, green cube will render in front of blue cube
        await testHelper.capture(
            viewer.view, "material_instance_depth_func_always");
      });
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
  });
}

Float32List unprojectTexture({
  required Float32List renderTarget,
  required Float32List uvCoordinates,
  required int renderTargetWidth,
  required int renderTargetHeight,
  required int renderTargetChannels,
  required int uvWidth,
  required int uvHeight,
  required int uvChannels,
  required int outputWidth,
  required int outputHeight,
  int uChannel = 0,
  int vChannel = 1,
}) {
  // Create output texture (initially transparent/zero)
  final outputSize = outputWidth * outputHeight * renderTargetChannels;
  final outputTexture = Float32List(outputSize);

  // Make sure the input dimensions match
  assert(renderTargetWidth == uvWidth && renderTargetHeight == uvHeight,
      'Render target and UV texture dimensions must match');

  // For each pixel in the render target
  for (int y = 0; y < renderTargetHeight; y++) {
    for (int x = 0; x < renderTargetWidth; x++) {
      // Calculate index in the source textures
      final srcIndex = (y * renderTargetWidth + x);
      final renderPixelIndex = srcIndex * renderTargetChannels;
      final uvPixelIndex = srcIndex * uvChannels;

      // Read UV coordinates directly from UV texture
      // Since we're using Float32List, values should already be in 0-1 range
      final u = uvCoordinates[uvPixelIndex + uChannel];
      final v = uvCoordinates[uvPixelIndex + vChannel];

      // Skip invalid UVs (e.g., background or out of bounds)
      if (u < 0.0 || u > 1.0 || v < 0.0 || v > 1.0) {
        continue;
      }

      // final u = x / renderTargetWidth;
      // final v = y / renderTargetHeight;

      // Convert UV to output texture coordinates
      final outX = (u * (outputWidth - 1)).round();
      final outY = (v * (outputHeight - 1)).round();

      // Calculate the destination index in the output texture
      final outIndex = (outY * outputWidth + outX) * renderTargetChannels;

      // Copy color data from render target to output at the UV position
      for (int c = 0; c < renderTargetChannels; c++) {
        outputTexture[outIndex + c] = renderTarget[renderPixelIndex + c];
      }
    }
  }

  return outputTexture;
}


        // // Rotate the camera in 30-degree increments and capture at each position
        // for (int i = 0; i <= 180; i += 30) {
        //   final angle = i * (pi / 180); // Convert to radians

        //   // Calculate camera position
        //   // Start at (0, 1, 5) (facing the sphere from +z) and rotate around to (-5, 1, 0)
        //   final radius = 5.0;
        //   final x = -radius * sin(angle);
        //   final z = radius * cos(angle);

        //   // Create view matrix for this camera position
        //   final matrix = makeViewMatrix(
        //       Vector3(x, 1, z),
        //       Vector3.zero(), // Looking at origin
        //       Vector3(0, 1, 0) // Up vector
        //       )
        //     ..invert();

        //   await viewer.setCameraModelMatrix4(matrix);

        //   // Take a snapshot at this position
        //   await testHelper.capture(viewer.view, "projection_${i}deg");
        // }

  // group("MaterialInstance", () {

  //   test('disable depth write', () async {
  //     var viewer = await testHelper.createViewer();
  //     await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);
  //     await viewer.setCameraPosition(0, 0, 6);
  //     await viewer.addDirectLight(
  //         DirectLight.sun(direction: Vector3(0, 0, -1)..normalize()));

  //     final cube1 = await viewer.createGeometry(GeometryHelper.cube());
  //     var materialInstance = await viewer.getMaterialInstanceAt(cube1, 0);

  //     final cube2 = await viewer.createGeometry(GeometryHelper.cube());
  //     await viewer.setMaterialPropertyFloat4(
  //         cube2, "baseColorFactor", 0, 0, 1, 0, 1);
  //     await viewer.setPosition(cube2, 1.0, 0.0, -1.0);

  //     expect(materialInstance, isNotNull);

  //     // with depth write enabled on both materials, cube2 renders behind the white cube
  //     await testHelper.capture(viewer.view, "material_instance_depth_write_enabled");

  //     // if we disable depth write on cube1, then cube2 will always appear in front
  //     // (relying on insertion order)
  //     materialInstance!.setDepthWriteEnabled(false);
  //     await testHelper.capture(
  //         viewer, "material_instance_depth_write_disabled");

  //     // set priority for the cube1 cube to 7 (render) last, cube1 renders in front
  //     await viewer.setPriority(cube1, 7);
  //     await testHelper.capture(
  //         viewer, "material_instance_depth_write_disabled_with_priority");
  //     await viewer.dispose();
  //   });

  //   test('set uv scaling (unlit)', () async {
  //     var viewer = await testHelper.createViewer();
  //     await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);
  //     await viewer.setCameraPosition(0, 0, 6);
  //     await viewer.addDirectLight(
  //         DirectLight.sun(direction: Vector3(0, 0, -1)..normalize()));

  //     final unlitMaterialInstance = await FilamentApp.instance!.createUnlitMaterialInstance();
  //     final cube = await viewer.createGeometry(GeometryHelper.cube(),
  //         materialInstance: unlitMaterialInstance);
  //     await viewer.setMaterialPropertyFloat4(
  //         cube, 'baseColorFactor', 0, 1, 1, 1, 1);
  //     await viewer.setMaterialPropertyInt(cube, 'baseColorIndex', 0, 1);
  //     unlitMaterialInstance.setParameterFloat2("uvScale", 2.0, 4.0);

  //     var textureData =
  //         File("${testHelper.testDir}/assets/cube_texture_512x512.png")
  //             .readAsBytesSync();
  //     var texture = await FilamentApp.instance!.createTexture(textureData);
  //     await viewer.applyTexture(texture, cube);
  //     await testHelper.capture(viewer.view, "set_uv_scaling");
  //     await viewer.dispose();
  //   });
  // });

  // group("texture", () {
  //   test("create/apply/dispose texture", () async {
  //     var viewer = await testHelper.createViewer();

  //     var textureData =
  //         File("${testHelper.testDir}/assets/cube_texture_512x512.png")
  //             .readAsBytesSync();

  //     var texture = await FilamentApp.instance!.createTexture(textureData);
  //     await viewer.setBackgroundColor(0.0, 0.0, 0.0, 1.0);
  //     await viewer.addDirectLight(
  //         DirectLight.sun(direction: Vector3(0, -10, -1)..normalize()));
  //     await viewer.addDirectLight(DirectLight.spot(
  //         intensity: 1000000,
  //         position: Vector3(0, 0, 1.5),
  //         direction: Vector3(0, 0, -1)..normalize(),
  //         falloffRadius: 10,
  //         spotLightConeInner: 1,
  //         spotLightConeOuter: 1));
  //     await viewer.setCameraPosition(0, 2, 6);
  //     await viewer
  //         .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
  //     var materialInstance =
  //         await FilamentApp.instance!.createUbershaderMaterialInstance(unlit: true);
  //     var cube = await viewer.createGeometry(GeometryHelper.cube(),
  //         materialInstances: [materialInstance]);

  //     await viewer.setPostProcessing(true);
  //     await viewer.setToneMapping(ToneMapper.LINEAR);

  //     await viewer.applyTexture(texture, cube,
  //         materialIndex: 0, parameterName: "baseColorMap");

  //     await testHelper.capture(viewer.view, "texture_applied_to_geometry");

  //     await viewer.destroyAsset(cube);
  //     await viewer.destroyTexture(texture);
  //     await viewer.dispose();
  //   });
  // });

  // group("unproject", () {
  //   test("unproject", () async {
  //     final dimensions = (width: 1280, height: 768);

  //     var viewer = await testHelper.createViewer(viewportDimensions: dimensions);
  //     await viewer.setPostProcessing(false);
  //     // await viewer.setToneMapping(ToneMapper.LINEAR);
  //     await viewer.setBackgroundColor(1.0, 1.0, 1.0, 1.0);
  //     // await viewer.createIbl(1.0, 1.0, 1.0, 100000);
  //     await viewer.addLight(LightType.SUN, 6500, 100000, -2, 0, 0, 1, -1, 0);
  //     await viewer.addLight(LightType.SPOT, 6500, 500000, 0, 0, 2, 0, 0, -1,
  //         falloffRadius: 10, spotLightConeInner: 1.0, spotLightConeOuter: 2.0);

  //     await viewer.setCameraPosition(-3, 4, 6);
  //     await viewer.setCameraRotation(
  //         Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
  //             Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 6));
  //     var cube =
  //         await viewer.createGeometry(GeometryHelper.cube(), keepData: true);
  //     await viewer.setMaterialPropertyFloat4(
  //         cube, "baseColorFactor", 0, 1.0, 1.0, 1.0, 1.0);
  //     var textureData =
  //         File("${testHelper.testDir}/assets/cube_texture_512x512.png").readAsBytesSync();
  //     var texture = await FilamentApp.instance!.createTexture(textureData);
  //     await viewer.applyTexture(texture, cube,
  //         materialIndex: 0, parameterName: "baseColorMap");

  //     var numFrames = 60;

  //     // first do the render
  //     for (int i = 0; i < numFrames; i++) {
  //       await viewer.setCameraPosition(-3 + (i / numFrames * 2), 4, 6);

  //       await viewer.setCameraRotation(
  //           Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
  //               Quaternion.axisAngle(
  //                   Vector3(1, 0, 0), -pi / 6 - (i / numFrames * pi / 6)));

  //       var rendered = await testHelper.capture(viewer.view, "unproject_render$i");
  //       var renderPng =
  //           await pixelsToPng(rendered, dimensions.width, dimensions.height);

  //       File("${outDir.path}/unproject_render${i}.png")
  //           .writeAsBytesSync(renderPng);
  //     }

  //     // then go off and convert the video

  //     // now unproject the render back onto the geometry
  //     final textureSize = (width: 1280, height: 768);
  //     var pixels = <Uint8List>[];
  //     // note we skip the first frame
  //     for (int i = 0; i < numFrames; i++) {
  //       await viewer.setCameraPosition(-3 + (i / numFrames * 2), 4, 6);

  //       await viewer.setCameraRotation(
  //           Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
  //               Quaternion.axisAngle(
  //                   Vector3(1, 0, 0), -pi / 6 - (i / numFrames * pi / 6)));

  //       var input = pngToPixelBuffer(File(
  //               "${outDir.path}/a8c317af-6081-4848-8a06-f6b69bc57664_${i + 1}.png")
  //           .readAsBytesSync());
  //       var pixelBuffer = await (await viewer as ThermionViewerFFI).unproject(
  //           cube,
  //           input,
  //           dimensions.width,
  //           dimensions.height,
  //           textureSize.width,
  //           textureSize.height);

  //       // var png = await pixelsToPng(Uint8List.fromList(pixelBuffer),
  //       //     dimensions.width, dimensions.height);

  //       await savePixelBufferToBmp(
  //           pixelBuffer,
  //           textureSize.width,
  //           textureSize.height,
  //           p.join(outDir.path, "unprojected_texture${i}.bmp"));

  //       pixels.add(pixelBuffer);

  //       if (i > 10) {
  //         break;
  //       }
  //     }

  //     // }

  //     final aggregatePixelBuffer = medianImages(pixels);
  //     await savePixelBufferToBmp(aggregatePixelBuffer, textureSize.width,
  //         textureSize.height, "unproject_texture.bmp");
  //     var pixelBufferPng = await pixelsToPng(
  //         Uint8List.fromList(aggregatePixelBuffer),
  //         dimensions.width,
  //         dimensions.height);
  //     File("${outDir.path}/unproject_texture.png")
  //         .writeAsBytesSync(pixelBufferPng);

  //     await viewer.setPostProcessing(true);
  //     await viewer.setToneMapping(ToneMapper.LINEAR);

  //     final unlit = await FilamentApp.instance!.createUnlitMaterialInstance();
  //     await viewer.destroyAsset(cube);
  //     cube = await viewer.createGeometry(GeometryHelper.cube(),
  //         materialInstance: unlit);
  //     var reconstructedTexture = await FilamentApp.instance!.createTexture(pixelBufferPng);
  //     await viewer.applyTexture(reconstructedTexture, cube);

  //     await viewer.setCameraRotation(
  //         Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
  //             Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 6));
  //     await testHelper.capture(viewer.view, "unproject_reconstruct");

  //     // now re-render
  //     for (int i = 0; i < numFrames; i++) {
  //       await viewer.setCameraPosition(-3 + (i / numFrames * 2), 4, 6);

  //       await viewer.setCameraRotation(
  //           Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
  //               Quaternion.axisAngle(
  //                   Vector3(1, 0, 0), -pi / 6 - (i / numFrames * pi / 6)));

  //       var rendered = await testHelper.capture(viewer.view, "unproject_rerender$i");
  //       var renderPng =
  //           await pixelsToPng(rendered, dimensions.width, dimensions.height);

  //       File("${outDir.path}/unproject_rerender${i}.png")
  //           .writeAsBytesSync(renderPng);
  //     }
  //   }, timeout: Timeout(Duration(minutes: 2)));
  // });
// }

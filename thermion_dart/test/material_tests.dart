import 'dart:io';
import 'dart:math';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_viewer_ffi.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';

import 'package:vector_math/vector_math_64.dart';

import 'helpers.dart';

Future<
    ({
      ThermionAsset blueCube,
      MaterialInstance blueMaterialInstance,
      ThermionAsset greenCube,
      MaterialInstance greenMaterialInstance
    })> setup(ThermionViewer viewer) async {
  var blueMaterialInstance = await viewer.createUnlitMaterialInstance();
  final blueCube = await viewer.createGeometry(GeometryHelper.cube(),
      materialInstances: [blueMaterialInstance]);
  await blueMaterialInstance.setParameterFloat4(
      "baseColorFactor", 0.0, 0.0, 1.0, 1.0);

  // Position blue cube slightly behind and to the right
  await viewer.setTransform(
      blueCube.entity, Matrix4.translation(Vector3(1.0, 0.0, -1.0)));

  var greenMaterialInstance = await viewer.createUnlitMaterialInstance();
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

  group("material tests", () {
    test('unlit material with color only', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setPostProcessing(true);
        await viewer.setToneMapping(ToneMapper.LINEAR);

        var materialInstance = await viewer.createUnlitMaterialInstance();
        var cube = await viewer.createGeometry(
            GeometryHelper.cube(normals: false, uvs: false),
            materialInstances: [materialInstance]);

        await materialInstance.setParameterFloat4(
            "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
        await materialInstance.setParameterInt("baseColorIndex", -1);
        await testHelper.capture(viewer, "unlit_material_base_color");
        await viewer.destroyMaterialInstance(materialInstance);
      }, bg: kRed);
    });

    test('unlit material with color + alpha', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setPostProcessing(true);
        await viewer.setToneMapping(ToneMapper.LINEAR);

        var materialInstance = await viewer.createUnlitMaterialInstance();
        var cube = await viewer.createGeometry(
            GeometryHelper.cube(normals: false, uvs: false),
            materialInstances: [materialInstance]);

        await materialInstance.setParameterFloat4(
            "baseColorFactor", 0.0, 1.0, 0.0, 0.1);
        await materialInstance.setParameterInt("baseColorIndex", -1);
        await testHelper.capture(viewer, "unlit_material_base_color_alpha");
        await viewer.destroyMaterialInstance(materialInstance);
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

      await testHelper.capture(viewer, "unlit_fixed_size_default_scale");

      await materialInstance.setParameterFloat("scale", 10.0);

      await testHelper.capture(viewer, "unlit_fixed_size_scale_10");

      await viewer.dispose();
    });

    test('apply texture to custom ubershader material instance', () async {
      var viewer = await testHelper.createViewer();
      await viewer.addLight(LightType.SUN, 6500, 1000000, 0, 0, 0, 0, 0, -1);
      await viewer.setCameraPosition(0, 2, 6);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);

      var materialInstance = await viewer.createUbershaderMaterialInstance();
      final cube = await viewer.createGeometry(
          GeometryHelper.cube(uvs: true, normals: true),
          materialInstances: [materialInstance]);
      var textureData =
          File("${testHelper.testDir}/assets/cube_texture_512x512.png")
              .readAsBytesSync();
      var texture = await viewer.createTexture(textureData);
      await viewer.applyTexture(texture as ThermionFFITexture, cube.entity);
      await testHelper.capture(
          viewer, "geometry_cube_with_custom_material_ubershader_texture");
      await viewer.destroyAsset(cube);
      await viewer.destroyMaterialInstance(materialInstance);
      await viewer.destroyTexture(texture);
      await viewer.dispose();
    });

    test('create cube with custom material instance (unlit)', () async {
      var viewer = await testHelper.createViewer();
      await viewer.setCameraPosition(0, 2, 6);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);
      await viewer.setPostProcessing(true);
      await viewer.setToneMapping(ToneMapper.LINEAR);

      var materialInstance = await viewer.createUnlitMaterialInstance();
      var cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstances: [materialInstance]);

      var textureData =
          File("${testHelper.testDir}/assets/cube_texture_512x512.png")
              .readAsBytesSync();
      var texture = await viewer.createTexture(textureData);
      await viewer.applyTexture(texture, cube.entity);
      await testHelper.capture(
          viewer, "geometry_cube_with_custom_material_unlit_texture_only");
      await viewer.destroyAsset(cube);

      cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstances: [materialInstance]);
      // reusing same material instance, so set baseColorIndex to -1 to disable the texture
      await materialInstance.setParameterInt("baseColorIndex", -1);
      await materialInstance.setParameterFloat4(
          "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
      await testHelper.capture(
          viewer, "geometry_cube_with_custom_material_unlit_color_only");
      await viewer.destroyAsset(cube);

      cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstances: [materialInstance]);
      // now set baseColorIndex to 0 to enable the texture and the base color
      await materialInstance.setParameterInt("baseColorIndex", 0);
      await materialInstance.setParameterFloat4(
          "baseColorFactor", 0.0, 1.0, 0.0, 0.5);
      await viewer.applyTexture(texture, cube.entity);

      await testHelper.capture(
          viewer, "geometry_cube_with_custom_material_unlit_color_and_texture");

      await viewer.destroyAsset(cube);

      await viewer.destroyTexture(texture);
      await viewer.destroyMaterialInstance(materialInstance);
      await viewer.dispose();
    });

    test('create sphere (no normals)', () async {
      var viewer = await testHelper.createViewer();
      await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
      await viewer.setCameraPosition(0, 0, 6);
      await viewer
          .createGeometry(GeometryHelper.sphere(normals: false, uvs: false));
      await testHelper.capture(viewer, "geometry_sphere_no_normals");

      await viewer.dispose();
    });

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
            viewer, "material_instance_depth_func_default");

        await greenMaterialInstance.setDepthFunc(SamplerCompareFunction.A);

        // with green material depth func set to always pass, green cube will render in front of blue cube
        await testHelper.capture(viewer, "material_instance_depth_func_always");
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
            viewer, "material_instance_depth_write_enabled");

        // Disable depth write on green cube, blue cube will always appear in front (green cube renders behind everything, including the image material, so not it's not visible at all)
        await greenMaterialInstance.setDepthWriteEnabled(false);
        await testHelper.capture(
            viewer, "material_instance_depth_write_disabled");

        // Set priority for greenCube to render last, making it appear in front
        await viewer.setPriority(greenCube.entity, 7);
        await testHelper.capture(
            viewer, "material_instance_depth_write_disabled_with_priority");
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
            viewer, "material_instance_depth_pass_stencil_disabled");

        assert(await greenMaterialInstance.isStencilWriteEnabled() == false);
        assert(await blueMaterialInstance.isStencilWriteEnabled() == false);

        await greenMaterialInstance.setStencilWriteEnabled(true);
        await blueMaterialInstance.setStencilWriteEnabled(true);

        assert(await greenMaterialInstance.isStencilWriteEnabled() == true);
        assert(await blueMaterialInstance.isStencilWriteEnabled() == true);

        // just a sanity check, no difference from the last
        await testHelper.capture(
            viewer, "material_instance_depth_pass_stencil_enabled");
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
            viewer, "material_instance_stencil_always_fail");
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
        await testHelper.capture(viewer, "fail_stencil_ne");
      }, postProcessing: true);
    });
  });
}

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
  //     await testHelper.capture(viewer, "material_instance_depth_write_enabled");

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

  //     final unlitMaterialInstance = await viewer.createUnlitMaterialInstance();
  //     final cube = await viewer.createGeometry(GeometryHelper.cube(),
  //         materialInstance: unlitMaterialInstance);
  //     await viewer.setMaterialPropertyFloat4(
  //         cube, 'baseColorFactor', 0, 1, 1, 1, 1);
  //     await viewer.setMaterialPropertyInt(cube, 'baseColorIndex', 0, 1);
  //     unlitMaterialInstance.setParameterFloat2("uvScale", 2.0, 4.0);

  //     var textureData =
  //         File("${testHelper.testDir}/assets/cube_texture_512x512.png")
  //             .readAsBytesSync();
  //     var texture = await viewer.createTexture(textureData);
  //     await viewer.applyTexture(texture, cube);
  //     await testHelper.capture(viewer, "set_uv_scaling");
  //     await viewer.dispose();
  //   });
  // });

  // group("texture", () {
  //   test("create/apply/dispose texture", () async {
  //     var viewer = await testHelper.createViewer();

  //     var textureData =
  //         File("${testHelper.testDir}/assets/cube_texture_512x512.png")
  //             .readAsBytesSync();

  //     var texture = await viewer.createTexture(textureData);
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
  //         await viewer.createUbershaderMaterialInstance(unlit: true);
  //     var cube = await viewer.createGeometry(GeometryHelper.cube(),
  //         materialInstances: [materialInstance]);

  //     await viewer.setPostProcessing(true);
  //     await viewer.setToneMapping(ToneMapper.LINEAR);

  //     await viewer.applyTexture(texture, cube,
  //         materialIndex: 0, parameterName: "baseColorMap");

  //     await testHelper.capture(viewer, "texture_applied_to_geometry");

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
  //     var texture = await viewer.createTexture(textureData);
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

  //       var rendered = await testHelper.capture(viewer, "unproject_render$i");
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

  //     final unlit = await viewer.createUnlitMaterialInstance();
  //     await viewer.destroyAsset(cube);
  //     cube = await viewer.createGeometry(GeometryHelper.cube(),
  //         materialInstance: unlit);
  //     var reconstructedTexture = await viewer.createTexture(pixelBufferPng);
  //     await viewer.applyTexture(reconstructedTexture, cube);

  //     await viewer.setCameraRotation(
  //         Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
  //             Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 6));
  //     await testHelper.capture(viewer, "unproject_reconstruct");

  //     // now re-render
  //     for (int i = 0; i < numFrames; i++) {
  //       await viewer.setCameraPosition(-3 + (i / numFrames * 2), 4, 6);

  //       await viewer.setCameraRotation(
  //           Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
  //               Quaternion.axisAngle(
  //                   Vector3(1, 0, 0), -pi / 6 - (i / numFrames * pi / 6)));

  //       var rendered = await testHelper.capture(viewer, "unproject_rerender$i");
  //       var renderPng =
  //           await pixelsToPng(rendered, dimensions.width, dimensions.height);

  //       File("${outDir.path}/unproject_rerender${i}.png")
  //           .writeAsBytesSync(renderPng);
  //     }
  //   }, timeout: Timeout(Duration(minutes: 2)));
  // });
// }

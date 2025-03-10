@Timeout(const Duration(seconds: 600))
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("material");

  group("image", () {
    test('create 2D texture & set from decoded image', () async {
      await testHelper.withViewer((viewer) async {
        var imageData =
            File("${testHelper.testDir}/assets/cube_texture_512x512.png")
                .readAsBytesSync();
        final image = await viewer.decodeImage(imageData);
        expect(await image.getChannels(), 4);
        expect(await image.getWidth(), 512);
        expect(await image.getHeight(), 512);

        final texture = await viewer.createTexture(
            await image.getWidth(), await image.getHeight(),
            textureFormat: TextureFormat.RGBA32F);
        await texture.setLinearImage(
            image, PixelDataFormat.RGBA, PixelDataType.FLOAT);
        await texture.dispose();
      }, bg: kRed);
    });

    test('create 2D texture and set image from raw buffer', () async {
      await testHelper.withViewer((viewer) async {
        var imageData =
            File("${testHelper.testDir}/assets/cube_texture_512x512.png")
                .readAsBytesSync();
        final image = await viewer.decodeImage(imageData);
        expect(await image.getChannels(), 4);
        expect(await image.getWidth(), 512);
        expect(await image.getHeight(), 512);

        final texture = await viewer.createTexture(
            await image.getWidth(), await image.getHeight(),
            textureFormat: TextureFormat.RGBA32F);
        var data = await image.getData();

        await texture.setImage(0, data.buffer.asUint8List(data.offsetInBytes),
            512, 512, 4, PixelDataFormat.RGBA, PixelDataType.FLOAT);
        await texture.dispose();
      }, bg: kRed);
    });

    test('create 3D texture and set image from buffers', () async {
      await testHelper.withViewer((viewer) async {
        final width = 128;
        final height = 128;
        final channels = 4;
        final depth = 5;
        final texture = await viewer.createTexture(width, height,
            depth: depth,
            textureSamplerType: TextureSamplerType.SAMPLER_3D,
            textureFormat: TextureFormat.RGBA32F);

        for (int i = 0; i < depth; i++) {
          final buffer = Uint8List(width * height * channels * sizeOf<Float>());
          await texture.setImage3D(0, 0, 0, i, width, height, channels, 1,
              buffer, PixelDataFormat.RGBA, PixelDataType.FLOAT);
        }
        await texture.dispose();
      }, bg: kRed);
    });

    test('apply 3D texture material ', () async {
      await testHelper.withViewer((viewer) async {
        final material = await viewer.createMaterial(File(
                "/Users/nickfisher/Documents/thermion/materials/texture_array.filamat")
            .readAsBytesSync());
        final materialInstance = await material.createInstance();
        final sampler = await viewer.createTextureSampler();
        final cube = await viewer.createGeometry(GeometryHelper.cube(),
            materialInstances: [materialInstance]);

        final width = 1;
        final height = 1;
        final channels = 4;
        final numTextures = 2;
        final texture = await viewer.createTexture(width, height,
            depth: numTextures,
            textureSamplerType: TextureSamplerType.SAMPLER_3D,
            textureFormat: TextureFormat.RGBA32F);

        for (int i = 0; i < numTextures; i++) {
          var pixelBuffer = Float32List.fromList(
              [i == 0 ? 1.0 : 0.0, i == 1 ? 1.0 : 0.0, 0.0, 1.0]);
          var byteBuffer =
              pixelBuffer.buffer.asUint8List(pixelBuffer.offsetInBytes);

          await texture.setImage3D(0, 0, 0, i, width, height, channels, 1,
              byteBuffer, PixelDataFormat.RGBA, PixelDataType.FLOAT);
        }

        await materialInstance.setParameterTexture(
            "textures", texture, sampler);
        await materialInstance.setParameterInt("activeTexture", 0);

        await testHelper.capture(viewer, "3d_texture_0");

        await materialInstance.setParameterInt("activeTexture", 1);

        await testHelper.capture(viewer, "3d_texture_1");

        await viewer.destroyAsset(cube);
        await materialInstance.dispose();
        await material.dispose();
        await texture.dispose();
      });
    });
  });

  group("sampler", () {
    test('create sampler', () async {
      await testHelper.withViewer((viewer) async {
        final sampler = viewer.createTextureSampler();
      }, bg: kRed);
    });
  });

  group('projection', () {
    test('project texture & UV unwrap', () async {
      await testHelper.withViewer((viewer) async {
        // setup base material + geometry
        final sampler = await viewer.createTextureSampler();
        var inputTextureData =
            File("${testHelper.testDir}/assets/cube_texture2_512x512.png")
                .readAsBytesSync();
        var inputImage = await viewer.decodeImage(inputTextureData);
        var inputTexture = await viewer.createTexture(
            await inputImage.getWidth(), await inputImage.getHeight(),
            textureFormat: TextureFormat.RGBA32F);
        await inputTexture.setLinearImage(
            inputImage, PixelDataFormat.RGBA, PixelDataType.FLOAT);
        var material =
            await viewer.createUbershaderMaterialInstance(unlit: true);

        // var material =
        //     await viewer.createUnlitMaterialInstance();
        await material.setParameterInt("baseColorIndex", 0);
        await material.setParameterTexture(
            "baseColorMap", inputTexture, sampler);
        await material.setParameterFloat4(
            "baseColorFactor", 1.0, 1.0, 1.0, 1.0);

        final cube = await viewer.createGeometry(GeometryHelper.cube(),
            materialInstances: [material]);

        await cube.removeFromScene();
        var objects = {"cube": cube};

        // setup render target
        final view = await viewer.getViewAt(0);
        final rtTextureHandle = await testHelper.createTexture(512, 512);
        final rt = await viewer.createRenderTarget(
            512, 512, rtTextureHandle.metalTextureAddress);
        await view.setRenderTarget(rt);

        var captureUvMaterial = await viewer.createMaterial(File(
                "/Users/nickfisher/Documents/thermion/materials/capture_uv.filamat")
            .readAsBytesSync());
        expect(await captureUvMaterial.hasParameter("flipUVs"), true);
        var captureUvMaterialInstance =
            await captureUvMaterial.createInstance();
        await captureUvMaterialInstance.setParameterBool("flipUVs", false);

        await captureUvMaterialInstance.setParameterTexture(
            "color", await rt.getColorTexture(), sampler);

        for (final entry in objects.entries) {
          final object = entry.value;
          final key = entry.key;

          await object.addToScene();

          var divisions = 8;
          for (int i = 0; i < divisions; i++) {
            var matrix = makeViewMatrix(
                Vector3(sin(i / divisions * pi) * 5, 0,
                    cos(i / divisions * pi) * 5),
                Vector3.zero(),
                Vector3(0, 1, 0));
            matrix.invert();
            await viewer.setCameraModelMatrix4(matrix);
            await testHelper.capture(viewer, "color_${key}_$i",
                renderTarget: rt);

            await object.setMaterialInstanceAt(captureUvMaterialInstance);

            var projected = await testHelper
                .capture(viewer, "uv_capture_${key}_$i", renderTarget: rt);

            var floatPixelBuffer = Float32List.fromList(
                projected.map((p) => p.toDouble() / 255.0).toList());

            final reappliedImage = await viewer.createImage(512, 512, 4);
            final data = await reappliedImage.getData();
            data.setRange(0, data.length, floatPixelBuffer);
            final reappliedTexture = await viewer.createTexture(512, 512,
                textureFormat: TextureFormat.RGBA32F);
            await reappliedTexture.setLinearImage(
                reappliedImage, PixelDataFormat.RGBA, PixelDataType.FLOAT);

            await material.setParameterTexture(
                "baseColorMap", reappliedTexture, sampler);
            await object.setMaterialInstanceAt(material);
            await testHelper.capture(viewer, "retextured_${key}_$i",
                renderTarget: rt);
            await material.setParameterTexture(
                "baseColorMap", inputTexture, sampler);
          }
          await viewer.destroyAsset(object);
        }

        // cleanup

        await sampler.dispose();
        await captureUvMaterialInstance.dispose();
        await captureUvMaterial.dispose();
      }, viewportDimensions: (width: 512, height: 512));
    });

    test('view dependent texture mapping', () async {
      await testHelper.withViewer((viewer) async {
        final sampler = await viewer.createTextureSampler();
        final numCameraPositions = 3;
        final textureDims = (width: 1, height: 1, channels: 4);

        var texture = await viewer.createTexture(
            textureDims.width, textureDims.height,
            textureSamplerType: TextureSamplerType.SAMPLER_3D,
            depth: numCameraPositions,
            textureFormat: TextureFormat.RGBA32F);

        for (int i = 0; i < numCameraPositions; i++) {
          final pixelBuffer = Float32List.fromList(
              [1 - (i/ numCameraPositions), i / numCameraPositions, 0.0, 1.0]);
          var byteBuffer =
              pixelBuffer.buffer.asUint8List(pixelBuffer.offsetInBytes);
          await texture.setImage3D(
              0,
              0,
              0,
              i,
              textureDims.width,
              textureDims.height,
              textureDims.channels,
              1,
              byteBuffer,
              PixelDataFormat.RGBA,
              PixelDataType.FLOAT);
        }
        final vdtm = await viewer.createMaterial(
            File("/Users/nickfisher/Documents/thermion/materials/vdtm.filamat")
                .readAsBytesSync());

        final materialInstance = await vdtm.createInstance();
        await materialInstance.setParameterTexture(
            "perspectives", texture, sampler);

        final cube = await viewer.createGeometry(GeometryHelper.cube(),
            materialInstances: [materialInstance]);

        final cameraPositions = [Vector3(0, 0, 5), Vector3(0, 0, -5)];
        await materialInstance.setParameterFloat3Array(
            "cameraPositions", cameraPositions);

        for (int i = 0; i < 8; i++) {
          final cameraPosition = Vector3(sin(pi * (i / 7)) * 5, 0, cos(pi * (i / 7))* 5 );
          final viewMatrix =
              makeViewMatrix(cameraPosition, Vector3.zero(), Vector3(0, 1, 0));
          viewMatrix.invert();
          await viewer.setCameraModelMatrix4(viewMatrix);

          await testHelper.capture(viewer, "view_dependent_texture_mapping_$i");
        }

        // // var material =
        // //     await viewer.createUnlitMaterialInstance();
        // await material.setParameterInt("baseColorIndex", 0);
        // await material.setParameterTexture(
        //     "baseColorMap", inputTexture, sampler);
        // await material.setParameterFloat4(
        //     "baseColorFactor", 1.0, 1.0, 1.0, 1.0);
        // // final plane = await viewer.createGeometry(
        // //     GeometryHelper.plane(width: 3, height: 3),
        // //     materialInstances: [material]);
        // // await plane.removeFromScene();
        // // var cube = await viewer
        // //     .loadGlb("file://${testHelper.testDir}/assets/cube.glb");
        // // await cube.setMaterialInstanceAt(material);
        // final cube = await viewer.createGeometry(GeometryHelper.cube(),
        //     materialInstances: [material]);

        // await cube.removeFromScene();
        // var objects = {
        //   // "plane": plane,
        //   "cube": cube
        // };

        // // setup render target
        // final view = await viewer.getViewAt(0);
        // final rtTextureHandle = await testHelper.createTexture(512, 512);
        // final rt = await viewer.createRenderTarget(
        //     512, 512, rtTextureHandle.metalTextureAddress);
        // await view.setRenderTarget(rt);

        // var captureUvMaterial = await viewer.createMaterial(File(
        //         "/Users/nickfisher/Documents/thermion/materials/capture_uv.filamat")
        //     .readAsBytesSync());
        // expect(await captureUvMaterial.hasParameter("flipUVs"), true);
        // var captureUvMaterialInstance =
        //     await captureUvMaterial.createInstance();
        // await captureUvMaterialInstance.setParameterBool("flipUVs", false);

        // await captureUvMaterialInstance.setParameterTexture(
        //     "color", await rt.getColorTexture(), sampler);

        // for (final entry in objects.entries) {
        //   final object = entry.value;
        //   final key = entry.key;

        //   await object.addToScene();

        //   var divisions = 8;
        //   for (int i = 0; i < divisions; i++) {
        //     var matrix = makeViewMatrix(
        //         Vector3(sin(i / divisions * pi) * 5, 0,
        //             cos(i / divisions * pi) * 5),
        //         Vector3.zero(),
        //         Vector3(0, 1, 0));
        //     matrix.invert();
        //     await viewer.setCameraModelMatrix4(matrix);
        //     await testHelper.capture(viewer, "color_${key}_$i",
        //         renderTarget: rt);
        //     // continue;

        //     await object.setMaterialInstanceAt(captureUvMaterialInstance);

        //     var projected = await testHelper
        //         .capture(viewer, "uv_capture_${key}_$i", renderTarget: rt);
        //     // File("/tmp/projected_texture.bmp")
        //     //     .writeAsBytesSync(await pixelBufferToBmp(projected, 512, 512));
        //     var floatPixelBuffer = Float32List.fromList(
        //         projected.map((p) => p.toDouble() / 255.0).toList());

        //     final reappliedImage = await viewer.createImage(512, 512, 4);
        //     final data = await reappliedImage.getData();
        //     data.setRange(0, data.length, floatPixelBuffer);
        //     final reappliedTexture = await viewer.createTexture(512, 512,
        //         textureFormat: TextureFormat.RGBA32F);
        //     await reappliedTexture.setLinearImage(
        //         reappliedImage, PixelDataFormat.RGBA, PixelDataType.FLOAT);

        //     await material.setParameterTexture(
        //         "baseColorMap", reappliedTexture, sampler);
        //     await object.setMaterialInstanceAt(material);
        //     await testHelper.capture(viewer, "retextured_${key}_$i",
        //         renderTarget: rt);
        //     await material.setParameterTexture(
        //         "baseColorMap", inputTexture, sampler);
        //   }
        //   await viewer.destroyAsset(object);
        // }

        // // cleanup

        // await sampler.dispose();
        // await captureUvMaterialInstance.dispose();
        // await captureUvMaterial.dispose();
      }, viewportDimensions: (width: 512, height: 512));
    });
  });
}

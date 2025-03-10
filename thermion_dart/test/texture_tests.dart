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
    Future withProjectionMaterial(
        ThermionViewer viewer,
        Future Function(TextureSampler sampler, MaterialInstance mi,
                RenderTarget rt, int width, int height)
            fn) async {
      // setup render target
      final view = await viewer.getViewAt(0);
      final vp = await view.getViewport();
      ;
      final rtTextureHandle = await testHelper.createTexture(512, 512);
      final (viewportWidth, viewportHeight) = (vp.width, vp.height);

      final rt = await viewer.createRenderTarget(
          viewportWidth, viewportHeight, rtTextureHandle.metalTextureAddress);

      await view.setRenderTarget(rt);

      // setup base material + geometry
      final sampler = await viewer.createTextureSampler();

      var projectionMaterial = await viewer.createMaterial(File(
              "/Users/nickfisher/Documents/thermion/materials/capture_uv.filamat")
          .readAsBytesSync());
      expect(await projectionMaterial.hasParameter("flipUVs"), true);
      var projectionMaterialInstance =
          await projectionMaterial.createInstance();
      await projectionMaterialInstance.setParameterBool("flipUVs", true);

      await projectionMaterialInstance.setParameterTexture(
          "color", await rt.getColorTexture(), sampler);

      await fn(sampler, projectionMaterialInstance, rt, viewportWidth,
          viewportHeight);

      // cleanup
      await sampler.dispose();
      await projectionMaterialInstance.dispose();
      await projectionMaterial.dispose();
    }

    Future withCube(
        ThermionViewer viewer,
        Future Function(ThermionAsset asset, MaterialInstance mi,
                Future Function() resetMaterial)
            fn) async {
      // var material = await viewer.createUbershaderMaterialInstance(unlit: true);
      var material = await viewer.createUnlitMaterialInstance();
      final cube = await viewer
          .createGeometry(GeometryHelper.cube(), materialInstances: [material]);
      var sampler = await viewer.createTextureSampler();
      var inputTextureData =
          File("${testHelper.testDir}/assets/cube_texture2_512x512.png")
              .readAsBytesSync();
      var inputImage = await viewer.decodeImage(inputTextureData);
      var inputTexture = await viewer.createTexture(
          await inputImage.getWidth(), await inputImage.getHeight(),
          textureFormat: TextureFormat.RGBA32F);
      await inputTexture.setLinearImage(
          inputImage, PixelDataFormat.RGBA, PixelDataType.FLOAT);
      final resetMaterial = () async {
        await material.setParameterInt("baseColorIndex", 0);
        await material.setParameterTexture(
            "baseColorMap", inputTexture, sampler);
        await material.setParameterFloat4(
            "baseColorFactor", 1.0, 1.0, 1.0, 1.0);
      };
      await resetMaterial();

      await fn(cube, material, resetMaterial);
    }

    test('project texture & UV unwrap', () async {
      await testHelper.withViewer((viewer) async {
        final camera = await viewer.getMainCamera();
        await withProjectionMaterial(viewer,
            (sampler, projectionMaterialInstance, rt, width, height) async {
          await withCube(viewer, (cube, ubershader, resetMaterial) async {
            var objects = {"cube": cube};

            for (final entry in objects.entries) {
              final object = entry.value;
              final key = entry.key;

              await object.addToScene();

              var divisions = 8;
              for (int i = 0; i < divisions; i++) {
                await camera.lookAt(Vector3(sin(i / divisions * pi) * 5, 0,
                    cos(i / divisions * pi) * 5));

                await testHelper.capture(viewer, "color_${key}_$i",
                    renderTarget: rt);

                await object.setMaterialInstanceAt(projectionMaterialInstance);

                var projectionOutput = await testHelper
                    .capture(viewer, "uv_capture_${key}_$i", renderTarget: rt);

                var floatPixelBuffer = Float32List.fromList(
                    projectionOutput.map((p) => p.toDouble() / 255.0).toList());

                final projectedImage = await viewer.createImage(512, 512, 4);
                final data = await projectedImage.getData();
                data.setRange(0, data.length, floatPixelBuffer);
                final projectedTexture = await viewer.createTexture(512, 512,
                    textureFormat: TextureFormat.RGBA32F);
                await projectedTexture.setLinearImage(
                    projectedImage, PixelDataFormat.RGBA, PixelDataType.FLOAT);

                await ubershader.setParameterTexture(
                    "baseColorMap", projectedTexture, sampler);
                await object.setMaterialInstanceAt(ubershader);
                await testHelper.capture(viewer, "retextured_${key}_$i",
                    renderTarget: rt);
                await resetMaterial();
              }
              await viewer.destroyAsset(object);
            }
          });
        });
      }, viewportDimensions: (width: 512, height: 512));
    });

    Future usingVDTM(
        ThermionViewer viewer,
        List<Vector3> cameraPositions,
        int width,
        int height,
        int channels,
        Future Function(Texture texture, MaterialInstance mi) fn) async {
      final sampler = await viewer.createTextureSampler();

      var texture = await viewer.createTexture(width, height,
          textureSamplerType: TextureSamplerType.SAMPLER_3D,
          depth: cameraPositions.length,
          textureFormat: TextureFormat.RGBA32F);

      final vdtm = await viewer.createMaterial(
          File("/Users/nickfisher/Documents/thermion/materials/vdtm.filamat")
              .readAsBytesSync());

      final materialInstance = await vdtm.createInstance();

      await materialInstance.setParameterFloat3Array(
          "cameraPositions", cameraPositions);
      await materialInstance.setParameterTexture(
          "perspectives", texture, sampler);
      await fn(texture, materialInstance);

      await materialInstance.dispose();
      await vdtm.dispose();
      await texture.dispose();
      await sampler.dispose();
    }

    test('view dependent texture mapping (interpolated colors)', () async {
      await testHelper.withViewer((viewer) async {
        final cameraPositions = [
          Vector3(0, 0, 5),
          Vector3(5, 0, 0),
          Vector3(0, 0, -5)
        ];
        final camera = await viewer.getMainCamera();

        final (numCameraPositions, width, height, channels) =
            (cameraPositions.length, 1, 1, 4);

        await usingVDTM(viewer, cameraPositions, width, height, channels,
            (texture, materialInstance) async {
          for (int i = 0; i < numCameraPositions; i++) {
            final pixelBuffer = Float32List.fromList([
              1 - (i / numCameraPositions),
              i / numCameraPositions,
              0.0,
              1.0
            ]);
            var byteBuffer =
                pixelBuffer.buffer.asUint8List(pixelBuffer.offsetInBytes);
            await texture.setImage3D(0, 0, 0, i, width, height, channels, 1,
                byteBuffer, PixelDataFormat.RGBA, PixelDataType.FLOAT);
          }

          final cube = await viewer.createGeometry(GeometryHelper.cube(),
              materialInstances: [materialInstance]);

          for (int i = 0; i < 8; i++) {
            final cameraPosition =
                Vector3(sin(pi * (i / 7)) * 5, 0, cos(pi * (i / 7)) * 5);
            await camera.lookAt(cameraPosition);
            await testHelper.capture(
                viewer, "view_dependent_texture_mapping_$i");
          }
        });
      }, viewportDimensions: (width: 512, height: 512));
    });

    test('VDTM + Texture Projection', () async {
      await testHelper.withViewer((viewer) async {
        final cameraPositions = [
          Vector3(0, 0, 5),
          Vector3(5, 0, 0),
          Vector3(0, 0, -5)
        ];

        final camera = await viewer.getMainCamera();

        await withProjectionMaterial(viewer, (TextureSampler projectionSampler,
            MaterialInstance projectionMaterialInstance,
            RenderTarget rt,
            int width,
            int height) async {
          await withCube(viewer, (cube, ubershader, resetMaterial) async {
            var pixelBuffers = <Float32List>[];
            for (int i = 0; i < cameraPositions.length; i++) {
              await camera.lookAt(cameraPositions[i]);

              await testHelper.capture(viewer, "vdtm_$i", renderTarget: rt);

              await cube.setMaterialInstanceAt(projectionMaterialInstance);

              var projectionOutput = await testHelper
                  .capture(viewer, "vdtm_unwrapped_$i", renderTarget: rt);

              var floatPixelBuffer = Float32List.fromList(
                  projectionOutput.map((p) => p.toDouble() / 255.0).toList());
              pixelBuffers.add(floatPixelBuffer);
              final projectedImage = await viewer.createImage(width, height, 4);
              final data = await projectedImage.getData();
              data.setRange(0, data.length, floatPixelBuffer);
              final projectedTexture = await viewer.createTexture(width, height,
                  textureFormat: TextureFormat.RGBA32F);
              await projectedTexture.setLinearImage(
                  projectedImage, PixelDataFormat.RGBA, PixelDataType.FLOAT);

              await ubershader.setParameterTexture(
                  "baseColorMap", projectedTexture, projectionSampler);
              await cube.setMaterialInstanceAt(ubershader);

              await testHelper.capture(viewer, "vdtm_projected_$i",
                  renderTarget: rt);

              await resetMaterial();
            }

            await usingVDTM(viewer, cameraPositions, width, height, 4,
                (vdtmTexture, vdtmMaterial) async {
              await cube.setMaterialInstanceAt(vdtmMaterial);
              for (int i = 0; i < cameraPositions.length; i++) {
                await vdtmTexture.setImage3D(
                    0,
                    0,
                    0,
                    i,
                    width,
                    height,
                    4,
                    1,
                    pixelBuffers[i]
                        .buffer
                        .asUint8List(pixelBuffers[i].offsetInBytes),
                    PixelDataFormat.RGBA,
                    PixelDataType.FLOAT);
              }

              for (int i = 0; i < 8; i++) {
                await camera.lookAt(
                    Vector3(sin(pi * (i / 7)) * 5, 0, cos(pi * (i / 7)) * 5));
                await testHelper.capture(viewer, "vdtm_reprojected_$i",
                    renderTarget: rt);
              }
            });
          });
        });
      }, viewportDimensions: (width: 512, height: 512));
    });
  });
}

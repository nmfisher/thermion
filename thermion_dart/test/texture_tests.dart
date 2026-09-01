import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("material");
  await testHelper.setup();

  test('decode PNG and set 2D texture', () async {
    await ViewerBuilder(testHelper).setBackgroundColor(kRed).execute((result) async {
      var imageData = await loadResourceBytes("${testHelper.assetsDir}/cube_texture_512x512.png");
      final image = await FilamentApp.instance!.decodeImage(imageData, requireAlpha: true);
      expect(await image.getChannels(), 4);
      expect(await image.getWidth(), 512);
      expect(await image.getHeight(), 512);

      final texture = await FilamentApp.instance!.createTexture(
        await image.getWidth(),
        await image.getHeight(),
        textureFormat: TextureFormat.RGBA32F,
      );
      await texture.setLinearImage(image, PixelDataFormat.RGBA, PixelDataType.FLOAT);
      await image.destroy();
      await texture.dispose();
    });
  });

  test('decode JPEG and set 2D texture', () async {
    await ViewerBuilder(testHelper).setBackgroundColor(kRed).execute((result) async {
      var imageData = await loadResourceBytes("${testHelper.assetsDir}/cube_texture_512x512.jpeg");
      final image = await FilamentApp.instance!.decodeImage(imageData, requireAlpha: true);
      expect(await image.getChannels(), 4);
      expect(await image.getWidth(), 512);
      expect(await image.getHeight(), 512);

      final texture = await FilamentApp.instance!.createTexture(
        await image.getWidth(),
        await image.getHeight(),
        textureFormat: TextureFormat.RGBA32F,
      );
      await texture.setLinearImage(image, PixelDataFormat.RGBA, PixelDataType.FLOAT);
      await image.destroy();
      await texture.dispose();
    });
  });

  test('set cubemap texture from pixel buffer', () async {
    await ViewerBuilder(testHelper).setBackgroundColor(kRed).execute((result) async {
      final texture = await FilamentApp.instance!.createTexture(
        1,
        1,
        depth: 6,
        textureSamplerType: TextureSamplerType.SAMPLER_CUBEMAP,
        textureFormat: TextureFormat.RGBA32F,
      );
      final byteBuffer = Float32List.fromList([1.0, 1.0, 1.0, 1.0]);
      for (int i = 0; i < 6; i++) {
        await texture.setImage(
          0,
          byteBuffer.asUint8List(),
          1,
          1,
          zOffset: i,
          PixelDataFormat.RGBA,
          PixelDataType.FLOAT,
        );
      }
      await texture.dispose();
    });
  });

  test('generate mipmaps', () async {
    await ViewerBuilder(testHelper).setBackgroundColor(kRed).execute((result) async {
      var imageData = await loadResourceBytes("${testHelper.assetsDir}/cube_texture_512x512.png");
      // RGBA32F + matching pixel format: generateMipmaps requires a
      // color-renderable format, and on WebGL only RGBA float textures are
      // renderable (RGB32F is not, even with EXT_color_buffer_float).
      final texture = await LinearImage.decodeToTexture(
        imageData,
        app: result.viewer.app,
        levels: 4,
        requireAlpha: true,
        textureFormat: TextureFormat.RGBA32F,
        pixelDataFormat: PixelDataFormat.RGBA,
        pixelDataType: PixelDataType.FLOAT,
      );
      expect(await texture.getLevels(), 4);
      await texture.generateMipmaps();
      await texture.dispose();
    });
  });

  test('create 2D texture and set image from raw buffer', () async {
    await ViewerBuilder(testHelper).setBackgroundColor(kRed).execute((result) async {
      var imageData = await loadResourceBytes("${testHelper.assetsDir}/cube_texture_512x512.png");
      final image = await FilamentApp.instance!.decodeImage(imageData, requireAlpha: true);
      expect(await image.getChannels(), 4);
      expect(await image.getWidth(), 512);
      expect(await image.getHeight(), 512);

      final texture = await FilamentApp.instance!.createTexture(
        await image.getWidth(),
        await image.getHeight(),
        textureFormat: TextureFormat.RGBA32F,
      );
      var data = await image.getData();

      await texture.setImage(
        0,
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        512,
        512,
        PixelDataFormat.RGBA,
        PixelDataType.FLOAT,
      );
      await image.destroy();
      await texture.dispose();
    });
  });

  test('create 3D texture and set image from buffers', () async {
    await ViewerBuilder(testHelper).setBackgroundColor(kRed).execute((result) async {
      final width = 128;
      final height = 128;
      final channels = 4;
      final depth = 5;
      final texture = await FilamentApp.instance!.createTexture(
        width,
        height,
        depth: depth,
        textureSamplerType: TextureSamplerType.SAMPLER_3D,
        textureFormat: TextureFormat.RGBA32F,
      );

      for (int i = 0; i < depth; i++) {
        final buffer = Uint8List(width * height * channels * sizeOf<Float>());
        await texture.setImage(0, buffer, width, height, PixelDataFormat.RGBA, PixelDataType.FLOAT, zOffset: i);
      }
      await texture.dispose();
    });
  });

  // test('apply 3D texture material ', () async {
  //   await testHelper.withViewer((viewer) async {
  //     final material = await FilamentApp.instance!.createMaterial(
  //       File(
  //         "/Users/nickfisher/Documents/thermion/materials/texture_array.filamat",
  //       ).readAsBytesSync(),
  //     );
  //     final materialInstance = await material.createInstance();
  //     final sampler = await FilamentApp.instance!.createTextureSampler();
  //     final cube = await result.viewer.createGeometry(
  //       GeometryUtils.cube(),
  //       materialInstances: [materialInstance],
  //     );

  //     final width = 1;
  //     final height = 1;
  //     final channels = 4;
  //     final numTextures = 2;
  //     final texture = await FilamentApp.instance!.createTexture(
  //       width,
  //       height,
  //       depth: numTextures,
  //       textureSamplerType: TextureSamplerType.SAMPLER_3D,
  //       textureFormat: TextureFormat.RGBA32F,
  //     );

  //     for (int i = 0; i < numTextures; i++) {
  //       var pixelBuffer = Float32List.fromList([
  //         i == 0 ? 1.0 : 0.0,
  //         i == 1 ? 1.0 : 0.0,
  //         0.0,
  //         1.0,
  //       ]);
  //       var byteBuffer = pixelBuffer.buffer.asUint8List(
  //         pixelBuffer.offsetInBytes,
  //       );

  //       await texture.setImage(
  //         0,
  //         byteBuffer,
  //         width,
  //         height,
  //         PixelDataFormat.RGBA,
  //         PixelDataType.FLOAT,
  //         zOffset: i,
  //       );
  //     }

  //     await materialInstance.setParameterTexture(
  //       "textures",
  //       texture,
  //       sampler,
  //     );
  //     await materialInstance.setParameterInt("activeTexture", 0);

  //     await testHelper.capture(result.viewer.view, "3d_texture_0");

  //     await materialInstance.setParameterInt("activeTexture", 1);

  //     await testHelper.capture(result.viewer.view, "3d_texture_1");

  //     await result.viewer.destroyAsset(cube);
  //     await materialInstance.destroy();
  //     await material.destroy();
  //     await texture.dispose();
  //   });
  // });

  test('load KTX2 texture ', () async {
    await ViewerBuilder(testHelper).setBackgroundColor(kRed).execute((result) async {
      final data = await loadResourceBytes("${testHelper.assetsDir}/2d_uastc.ktx2");
      final texture = await FilamentApp.instance!.loadKtx2(data);
      expect(await texture.getHeight(), 40);
      expect(await texture.getWidth(), 40);
    });
  });

  test('paint sub-region of texture', () async {
    await ViewerBuilder(testHelper)
        .setCameraLookAt(Vector3(10, 10, 10), focus: Vector3.zero())
        .addPlane(color: kGreen, createUbershader: true, unlit: true)
        .execute((result) async {
          const textureSize = 256;
          const paintSize = 64;
          const paintX = 96;
          const paintY = 96;

          // Create a blue texture initially
          final texture = await FilamentApp.instance!.createTexture(
            textureSize,
            textureSize,
            textureFormat: TextureFormat.RGBA32F,
          );

          // Fill initial texture with blue color
          final initialBuffer = Float32List(textureSize * textureSize * 4);
          for (int i = 0; i < initialBuffer.length; i += 4) {
            initialBuffer[i] = 0.2; // R
            initialBuffer[i + 1] = 0.2; // G
            initialBuffer[i + 2] = 1.0; // B (blue)
            initialBuffer[i + 3] = 1.0; // A
          }

          await texture.setImage(
            0,
            initialBuffer.buffer.asUint8List(initialBuffer.offsetInBytes, initialBuffer.lengthInBytes),
            textureSize,
            textureSize,
            PixelDataFormat.RGBA,
            PixelDataType.FLOAT,
          );

          final plane = result.assets.first;

          // Apply texture to the plane's material
          final materialInstance = await plane.getMaterialInstanceAt();
          await materialInstance.setParameterFloat4("baseColorFactor", 1, 1, 1, 0);
          await materialInstance.setParameterInt("baseColorIndex", 0);
          final sampler = await FilamentApp.instance!.createTextureSampler();
          await materialInstance.setParameterTexture("baseColorMap", texture, sampler);
          await testHelper.capture(result.viewer.view, "paint_test_initial");

          // Create a red "paint" buffer
          final paintBuffer = Float32List(paintSize * paintSize * 4);
          for (int i = 0; i < paintBuffer.length; i += 4) {
            paintBuffer[i] = 1.0; // R (red)
            paintBuffer[i + 1] = 0.0; // G
            paintBuffer[i + 2] = 0.0; // B
            paintBuffer[i + 3] = 1.0; // A
          }

          // Apply the paint to a sub-region of the texture
          await texture.setImage(
            0,
            paintBuffer.buffer.asUint8List(paintBuffer.offsetInBytes, paintBuffer.lengthInBytes),
            paintSize,
            paintSize,
            PixelDataFormat.RGBA,
            PixelDataType.FLOAT,
            xOffset: paintX,
            yOffset: paintY,
          );

          // Capture the modified state (blue plane with red square)
          await testHelper.capture(result.viewer.view, "paint_test_modified");
          await texture.dispose();
        });
  });

  group("getFormat", () {
    for (final fmt in const [
      TextureFormat.RGBA32F,
      TextureFormat.RGBA16F,
      TextureFormat.RGBA8,
      TextureFormat.R16F,
      TextureFormat.DEPTH32F,
    ]) {
      test('round-trips $fmt through createTexture', () async {
        await ViewerBuilder(testHelper).execute((result) async {
          final tex = await FilamentApp.instance!.createTexture(
            16,
            16,
            flags: fmt == TextureFormat.DEPTH32F
                ? {TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT}
                : const {TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
            textureFormat: fmt,
          );
          expect(await tex.getFormat(), fmt);
          await tex.dispose();
        });
      });
    }

    test('RenderTarget.getColorTexture exposes the FLOAT color format', () async {
      await ViewerBuilder(testHelper).execute((result) async {
        final color = await FilamentApp.instance!.createTexture(
          16,
          16,
          flags: const {
            TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
            TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
            TextureUsage.TEXTURE_USAGE_BLIT_SRC,
          },
          textureFormat: TextureFormat.RGBA32F,
        );
        final depth = await FilamentApp.instance!.createTexture(
          16,
          16,
          flags: const {TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT},
          textureFormat: TextureFormat.DEPTH32F,
        );
        final rt = await FilamentApp.instance!.createRenderTarget(16, 16, color: color, depth: depth);
        final readBack = await rt.getColorTexture();
        expect(await readBack.getFormat(), TextureFormat.RGBA32F);
        await rt.destroy();
        await color.dispose();
        await depth.dispose();
      });
    });
  });

  group("sampler", () {
    test('create sampler', () async {
      await ViewerBuilder(testHelper).setBackgroundColor(kRed).execute((result) async {
        final sampler = FilamentApp.instance!.createTextureSampler();
      });
    });
  });
}

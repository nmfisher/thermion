import 'dart:io';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("material");
  await testHelper.setup();

  group("image", () {
    test('set 2D texture from decoded image', () async {
      await testHelper.withViewer((viewer) async {
        var imageData = File(
          "${testHelper.testDir}/assets/cube_texture_512x512.png",
        ).readAsBytesSync();
        final image = await FilamentApp.instance!
            .decodeImage(imageData, requireAlpha: true);
        expect(await image.getChannels(), 4);
        expect(await image.getWidth(), 512);
        expect(await image.getHeight(), 512);

        final texture = await FilamentApp.instance!.createTexture(
          await image.getWidth(),
          await image.getHeight(),
          textureFormat: TextureFormat.RGBA32F,
        );
        await texture.setLinearImage(
          image,
          PixelDataFormat.RGBA,
          PixelDataType.FLOAT,
        );
        await texture.dispose();
      }, bg: kRed);
    });

    test('set cubemap texture from pixel buffer', () async {
      await testHelper.withViewer((viewer) async {
        final texture = await FilamentApp.instance!.createTexture(
          1,
          1,
          depth: 6,
          textureSamplerType: TextureSamplerType.SAMPLER_CUBEMAP,
          textureFormat: TextureFormat.RGBA32F,
        );
        final byteBuffer = Float32List.fromList([
          1.0,
          1.0,
          1.0,
          1.0,
        ]);
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
      }, bg: kRed);
    });

    test('generate mipmaps', () async {
      await testHelper.withViewer((viewer) async {
        var imageData = File(
          "${testHelper.testDir}/assets/cube_texture_512x512.png",
        ).readAsBytesSync();
        final texture = await LinearImage.decodeToTexture(imageData, levels: 4);
        expect(await texture.getLevels(), 4);
        await texture.generateMipmaps();
        await texture.dispose();
      }, bg: kRed);
    });

    test('create 2D texture and set image from raw buffer', () async {
      await testHelper.withViewer((viewer) async {
        var imageData = File(
          "${testHelper.testDir}/assets/cube_texture_512x512.png",
        ).readAsBytesSync();
        final image = await FilamentApp.instance!
            .decodeImage(imageData, requireAlpha: true);
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
          data.buffer.asUint8List(data.offsetInBytes),
          512,
          512,
          PixelDataFormat.RGBA,
          PixelDataType.FLOAT,
        );
        await texture.dispose();
      }, bg: kRed);
    });

    test('create 3D texture and set image from buffers', () async {
      await testHelper.withViewer((viewer) async {
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
          await texture.setImage(
            0,
            buffer,
            width,
            height,
            PixelDataFormat.RGBA,
            PixelDataType.FLOAT,
            zOffset: i,
          );
        }
        await texture.dispose();
      }, bg: kRed);
    });

    test('apply 3D texture material ', () async {
      await testHelper.withViewer((viewer) async {
        final material = await FilamentApp.instance!.createMaterial(
          File(
            "/Users/nickfisher/Documents/thermion/materials/texture_array.filamat",
          ).readAsBytesSync(),
        );
        final materialInstance = await material.createInstance();
        final sampler = await FilamentApp.instance!.createTextureSampler();
        final cube = await viewer.createGeometry(
          GeometryHelper.cube(),
          materialInstances: [materialInstance],
        );

        final width = 1;
        final height = 1;
        final channels = 4;
        final numTextures = 2;
        final texture = await FilamentApp.instance!.createTexture(
          width,
          height,
          depth: numTextures,
          textureSamplerType: TextureSamplerType.SAMPLER_3D,
          textureFormat: TextureFormat.RGBA32F,
        );

        for (int i = 0; i < numTextures; i++) {
          var pixelBuffer = Float32List.fromList([
            i == 0 ? 1.0 : 0.0,
            i == 1 ? 1.0 : 0.0,
            0.0,
            1.0,
          ]);
          var byteBuffer = pixelBuffer.buffer.asUint8List(
            pixelBuffer.offsetInBytes,
          );

          await texture.setImage(
            0,
            byteBuffer,
            width,
            height,
            PixelDataFormat.RGBA,
            PixelDataType.FLOAT,
            zOffset: i,
          );
        }

        await materialInstance.setParameterTexture(
          "textures",
          texture,
          sampler,
        );
        await materialInstance.setParameterInt("activeTexture", 0);

        await testHelper.capture(viewer.view, "3d_texture_0");

        await materialInstance.setParameterInt("activeTexture", 1);

        await testHelper.capture(viewer.view, "3d_texture_1");

        await viewer.destroyAsset(cube);
        await materialInstance.destroy();
        await material.destroy();
        await texture.dispose();
      });
    });

    test('load KTX2 texture ', () async {
      await testHelper.withViewer((viewer) async {
        final data = File("${testHelper.testDir}/assets/2d_uastc.ktx2")
            .readAsBytesSync();
        final texture = await FilamentApp.instance!.loadKtx2(data);
        expect(await texture.getHeight(), 40);
        expect(await texture.getWidth(), 40);
        
      }, bg: kRed);
    });
  });

  group("sampler", () {
    test('create sampler', () async {
      await testHelper.withViewer((viewer) async {
        final sampler = FilamentApp.instance!.createTextureSampler();
      }, bg: kRed);
    });
  });
}

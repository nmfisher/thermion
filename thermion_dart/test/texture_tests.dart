import 'dart:io';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("material");

  group("image", () {
    test('decode image', () async {
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
  });

  group("sampler", () {
    test('create sampler', () async {
      await testHelper.withViewer((viewer) async {
        final sampler = viewer.createTextureSampler();
      }, bg: kRed);
    });
  });
}

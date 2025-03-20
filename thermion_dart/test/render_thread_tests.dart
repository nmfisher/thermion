import 'dart:async';
import 'dart:ffi';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("render_thread");
  
  await testHelper.setup();

  group("render thread/capture", () {
    test("request frame on render thread", () async {
      await testHelper.withViewer((viewer) async {
        var metalTexture = await testHelper.createTexture(500, 500);
        var texture = await FilamentApp.instance!.createTexture(
          500, 500,
          importedTextureHandle: metalTexture.metalTextureAddress,
          flags: {
            TextureUsage.TEXTURE_USAGE_BLIT_DST,
            TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
            TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT  
          });

        var renderTarget = await FilamentApp.instance!
            .createRenderTarget(500, 500, color: texture);

        await viewer.view.setRenderTarget(renderTarget);

        await viewer.render();

        await Future.delayed(Duration(milliseconds: 1));

        var data = metalTexture.getTextureBytes()!;
        var pixels = data.bytes.cast<Uint8>().asTypedList(data.length);

        savePixelBufferToBmp(
            pixels, 500, 500, "${testHelper.testDir}/request_frame.bmp");
        await viewer.dispose();
      });
    });
  });
}

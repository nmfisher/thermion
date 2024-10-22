import 'dart:async';
import 'dart:ffi';
import 'package:test/test.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("render_thread");
  group("render thread/capture", () {
    test("request frame on render thread", () async {
      var viewer = await testHelper.createViewer();
      await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);

      var texture = await testHelper.createTexture(500, 500);
      var renderTarget = await viewer.createRenderTarget(
          500, 500, texture.metalTextureAddress);
      
      final view = await viewer.getViewAt(0);
      await view.setRenderTarget(renderTarget);

      await viewer.render();

      await Future.delayed(Duration(milliseconds: 1));

      var data = texture.getTextureBytes()!;
      var pixels = data.bytes.cast<Uint8>().asTypedList(data.length);

      savePixelBufferToBmp(
          pixels, 500, 500, "${testHelper.testDir}/request_frame.bmp");
      await viewer.dispose();
    });
  });
}

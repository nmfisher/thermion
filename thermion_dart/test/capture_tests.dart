import 'dart:async';
import 'dart:ffi';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("render_thread");

  await testHelper.setup();

  test("capture with RGBA byte", () async {
    await testHelper.withViewer((viewer) async {
      await testHelper.capture(viewer.view, "capture_rgba_float", pixelDataFormat: PixelDataFormat.RGBA, pixelDataType: PixelDataType.FLOAT);
      await testHelper.capture(viewer.view, "capture_rgba_byte", pixelDataFormat: PixelDataFormat.RGBA, pixelDataType: PixelDataType.UBYTE);
    }, bg: kRed);
  });
}

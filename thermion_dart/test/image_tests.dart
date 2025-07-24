import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_ktx1_bundle.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("images");
  await testHelper.setup();
  test('decode KTX', () async {
    await testHelper.withViewer((viewer) async {
      final ktx1Data =
          File("${testHelper.testDir}/assets/default_env_skybox.ktx")
              .readAsBytesSync();
      final bundle = await FFIKtx1Bundle.create(ktx1Data);
    });
  });

  test('set background color', () async {
    await testHelper.withViewer((viewer) async {
      await viewer.setBackgroundColor(0, 1, 0, 1);
      await testHelper.capture(viewer.view, "background_green");
      await viewer.setBackgroundColor(1, 0, 0, 1);
      await testHelper.capture(viewer.view, "background_red");
    });
  });

  test('set background image from PNG', () async {
    await testHelper.withViewer((viewer) async {
      await viewer.setBackgroundImage(
          "file://${testHelper.testDir}/assets/cube_texture_512x512.png");
      await testHelper.capture(viewer.view, "background_png_image");
    });
  });

  test('set background image from KTX', () async {
    await testHelper.withViewer((viewer) async {
      await viewer.setBackgroundImage(
          "file://${testHelper.testDir}/assets/background.ktx");
      await testHelper.capture(viewer.view, "background_ktx_image");
    });
  });
}

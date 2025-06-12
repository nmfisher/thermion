import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/interface/filament_app.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("images");
  await testHelper.setup();
  test('decode KTX', () async {
    await testHelper.withViewer((viewer) async {
      await FilamentApp.instance!.decodeKtx(
          File("${testHelper.testDir}/assets/default_env_skybox.ktx").readAsBytesSync());
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

  test('set background image', () async {
    await testHelper.withViewer((viewer) async {
      await viewer.setBackgroundImage(
          "file://${testHelper.testDir}/assets/cube_texture_512x512.png");
      await testHelper.capture(viewer.view, "background_image");
    });
  });
}

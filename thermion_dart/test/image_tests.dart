import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_ktx1_bundle.dart';
import 'package:thermion_dart/src/utils/src/geometry.dart';
import 'package:thermion_dart/src/viewer/viewer.dart';
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

  test('move textured quad from near plane to far plane', () async {
    await testHelper.withViewer((viewer) async {
      await viewer.setBackgroundImage(
          "file://${testHelper.testDir}/assets/background.ktx");
      final quad = await viewer.getBackgroundImage();
      // add a cube so we can check our depth parameters
      final asset = await viewer.createGeometry(GeometryHelper.cube());
      // render image at far plane
      await quad.setDepth(0.0);
      await testHelper.capture(viewer.view, "textured_quad_far_plane");
      // render the quad at the near plane
      await quad.setDepth(1.0);
      await testHelper.capture(viewer.view, "textured_quad_near_plane");

      // set the clear color so we can confirm it's definitely removed
      await FilamentApp.instance!.setClearOptions(0, 0, 1, 0);
      await viewer.clearBackgroundImage(destroy: true);

      await testHelper.capture(viewer.view, "textured_quad_removed");
    });
  });
}

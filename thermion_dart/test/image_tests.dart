import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_ktx1_bundle.dart';
import 'package:thermion_dart/src/utils/src/geometry/utils.dart';
import 'package:thermion_dart/src/viewer/viewer.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("images");
  await testHelper.setup();
  test('decode KTX and read spherical harmonics', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final ktx1Data = await loadResourceBytes("${testHelper.assetsDir}/default_env_ibl.ktx");
      final bundle = await FFIKtx1Bundle.create(FilamentApp.instance! as FFIFilamentApp, ktx1Data);
      final harmonics = bundle.getSphericalHarmonics();
      expect(harmonics, hasLength(27));
      expect(harmonics.every((value) => value.isFinite), isTrue);
      expect(harmonics.any((value) => value.abs() > 1e-6), isTrue);
      await bundle.destroy();
    });
  });

  test('set background color', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final scene = await result.viewer.view.getScene();
      final skybox = await FilamentApp.instance!.createColoredSkybox(r: 0, g: 1, b: 0, a: 1);
      await scene.setSkybox(skybox);
      await testHelper.capture(result.viewer.view, "background_green");
      await skybox.setColor(1, 0, 0, 1);
      await testHelper.capture(result.viewer.view, "background_red");
    });
  });

  test('set background image from PNG', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      await result.viewer.setBackgroundImage("file://${testHelper.assetsDir}/cube_texture_512x512.png");
      await testHelper.capture(result.viewer.view, "background_png_image");
    });
  });

  test('depth preview respects visibility and transformed texture bounds', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final viewer = result.viewer;
      await viewer.setBackgroundImage("file://${testHelper.assetsDir}/green_12x12.png");
      final quad = await viewer.getBackgroundImage();
      final instance = await quad.getMaterialInstanceAt();
      await instance.setParameterInt('isDepthTexture', 1);
      await quad.setBackgroundColor(0, 0, 1, 1);

      Future<List<double>> centerRgb() async {
        final buffer = (await testHelper.capture(viewer.view, null)).values.single;
        final viewport = await viewer.view.getViewport();
        final center = ((viewport.height ~/ 2) * viewport.width + viewport.width ~/ 2) * 4;
        final pixels = buffer.buffer.asFloat32List(buffer.offsetInBytes, buffer.lengthInBytes ~/ 4);
        return pixels.sublist(center, center + 3);
      }

      // The green texture has zero red depth, so it appears white.
      expect(await centerRgb(), everyElement(greaterThan(0.95)));
      await quad.setTransform(Matrix4.translationValues(2, 0, 0));
      final outside = await centerRgb();
      expect(outside[0], lessThan(0.05));
      expect(outside[1], lessThan(0.05));
      expect(outside[2], greaterThan(0.95));

      await quad.setTransform(Matrix4.identity());
      await quad.hideImage();
      expect(await centerRgb(), orderedEquals(outside));
    });
  });

  test('move textured quad from near plane to far plane', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      await result.viewer.setBackgroundImage("file://${testHelper.assetsDir}/background.ktx");
      final quad = await result.viewer.getBackgroundImage();
      // add a cube so we can check our depth parameters
      final asset = await result.viewer.createGeometry(GeometryUtils.cube());
      // render image at far plane
      await quad.setDepth(0.0);
      await testHelper.capture(result.viewer.view, "textured_quad_far_plane");
      // render the quad at the near plane
      await quad.setDepth(1.0);
      await testHelper.capture(result.viewer.view, "textured_quad_near_plane");

      // set the clear color so we can confirm it's definitely removed
      await FilamentApp.instance!.setClearOptions(0, 0, 1, 0);
      await result.viewer.clearBackgroundImage(destroy: true);

      await testHelper.capture(result.viewer.view, "textured_quad_removed");
    });
  });
}

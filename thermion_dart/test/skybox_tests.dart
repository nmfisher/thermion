@Timeout(const Duration(seconds: 600))
import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_viewer_ffi.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("skybox");
  await testHelper.setup();

  test('create colored skybox with opaque black', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      // Create a solid black skybox
      final skybox = await FilamentApp.instance!.createColoredSkybox(r: 0.0, g: 0.0, b: 0.0, a: 1.0);
      expect(skybox, isNotNull);

      final scene = (result.viewer as ThermionViewerFFI).scene;
      await scene.setSkybox(skybox);
      await testHelper.capture(result.viewer.view, "colored_skybox_black");

      await skybox.destroy();
    });
  });

  test('create colored skybox with transparent', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      // Create a fully transparent skybox (for overlay clearing)
      final skybox = await FilamentApp.instance!.createColoredSkybox(r: 0.0, g: 0.0, b: 0.0, a: 0.0);
      expect(skybox, isNotNull);

      final scene = (result.viewer as ThermionViewerFFI).scene;
      await scene.setSkybox(skybox);
      await testHelper.capture(result.viewer.view, "colored_skybox_transparent");

      await skybox.destroy();
    });
  });

  test('create colored skybox with solid color', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      // Create a solid red skybox
      final skybox = await FilamentApp.instance!.createColoredSkybox(r: 1.0, g: 0.0, b: 0.0, a: 1.0);
      expect(skybox, isNotNull);

      final scene = (result.viewer as ThermionViewerFFI).scene;
      await scene.setSkybox(skybox);
      await testHelper.capture(result.viewer.view, "colored_skybox_red");

      await skybox.destroy();
    });
  });
}

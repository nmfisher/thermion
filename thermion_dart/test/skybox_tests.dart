@Timeout(const Duration(seconds: 600))
import 'package:test/test.dart';
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

  test('colored skybox has no environment texture', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      final skybox = await FilamentApp.instance!.createColoredSkybox(r: 0.0, g: 0.0, b: 0.0, a: 1.0);
      expect(skybox.getTexture(), isNull);
      await skybox.destroy();
    });
  });

  test('skybox intensity defaults to Filament value and can be overridden', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      final defaultSkybox = await FilamentApp.instance!.createColoredSkybox(r: 0.0, g: 0.0, b: 0.0, a: 1.0);
      expect(defaultSkybox.getIntensity(), 30000.0);

      final dimSkybox = await FilamentApp.instance!.createColoredSkybox(
        r: 0.0, g: 0.0, b: 0.0, a: 1.0, intensity: 100.0,
      );
      expect(dimSkybox.getIntensity(), 100.0);

      await defaultSkybox.destroy();
      await dimSkybox.destroy();
    });
  });

  test('skybox layer mask can be set and read back', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      final skybox = await FilamentApp.instance!.createColoredSkybox(r: 0.0, g: 0.0, b: 0.0, a: 1.0);
      // Default visibility mask is bit 0 only.
      expect(skybox.getLayerMask(), 0x1);

      // Set bit 1, clear bit 0 (see filament Skybox::setLayerMask docs).
      await skybox.setLayerMask(7, 2);
      expect(skybox.getLayerMask(), 2);

      await skybox.destroy();
    });
  });

  test('loadSkybox returns the created skybox and its environment texture', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      final skybox = await result.viewer.loadSkybox("file://${testHelper.assetsDir}/default_env_skybox.ktx");
      expect(skybox, isNotNull);
      expect(skybox.getTexture(), isNotNull);
      expect(skybox.getLayerMask(), 0x1);
      await result.viewer.removeSkybox();
    });
  });

  test('setBackgroundColor returns the created skybox', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      final skybox = await result.viewer.setBackgroundColor(0.0, 0.0, 0.0, 1.0);
      expect(skybox, isNotNull);
      expect(skybox.getTexture(), isNull);
      await result.viewer.removeSkybox();
    });
  });
}

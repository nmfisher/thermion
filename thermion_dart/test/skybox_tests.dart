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
        r: 0.0,
        g: 0.0,
        b: 0.0,
        a: 1.0,
        intensity: 100.0,
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

  test('scene skybox can be set and read back', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      final scene = (result.viewer as ThermionViewerFFI).scene;
      expect(await scene.getSkybox(), isNull);

      final skybox = await FilamentApp.instance!.createColoredSkybox(r: 0.0, g: 0.0, b: 0.0, a: 1.0);
      await scene.setSkybox(skybox);
      final attached = await scene.getSkybox();
      expect(attached, isNotNull);
      // Same underlying skybox (no environment texture on a color skybox).
      expect(attached!.getTexture(), isNull);

      await scene.setSkybox(null);
      expect(await scene.getSkybox(), isNull);

      await skybox.destroy();
    });
  });

  test('builder options do not break skybox creation', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      final scene = (result.viewer as ThermionViewerFFI).scene;
      final skybox = await FilamentApp.instance!.createColoredSkybox(
        r: 0.0,
        g: 0.0,
        b: 0.0,
        a: 1.0,
        showSun: false,
        intensity: 2500.0,
        priority: 3,
      );
      expect(skybox.getIntensity(), 2500.0);
      await scene.setSkybox(skybox);
      await skybox.destroy();
    });
  });

  test('showSun renders the sun disc when a SUN light is in the scene', () async {
    await ViewerBuilder(
      testHelper,
    ).setRenderTargetEnabled(true).setCameraLookAt(Vector3(0, 0, 1), focus: Vector3.zero()).execute((result) async {
      final scene = (result.viewer as ThermionViewerFFI).scene;
      final lightManager = FilamentApp.instance!.lightManager;

      // Aim the light along +z so the sun disc sits at -z, dead ahead of the
      // camera (Filament's default SUN direction points straight down, which
      // puts the disc at the zenith, out of frame).
      final sunLight = lightManager.createLight(LightType.SUN);
      lightManager.setDirection(sunLight, 0.0, 0.0, 1.0);
      await scene.addEntity(sunLight);

      // Baseline: black color skybox with showSun disabled - the capture
      // should be uniformly black.
      final plain = await FilamentApp.instance!.createColoredSkybox(r: 0.0, g: 0.0, b: 0.0, a: 1.0);
      await scene.setSkybox(plain);
      final withoutSun = await testHelper.capture(result.viewer.view, "skybox_no_sun");
      final pixelsWithout = withoutSun[result.viewer.view]!;

      // showSun: the sun disc must appear as non-black pixels.
      final withSunSkybox = await FilamentApp.instance!.createColoredSkybox(
        r: 0.0,
        g: 0.0,
        b: 0.0,
        a: 1.0,
        showSun: true,
      );
      await scene.setSkybox(withSunSkybox);
      final withSun = await testHelper.capture(result.viewer.view, "skybox_show_sun");
      final pixelsWith = withSun[result.viewer.view]!;

      double maxLuminance(Uint8List pixels) {
        var maxLum = 0.0;
        final floats = Float32List.view(pixels.buffer, pixels.offsetInBytes);
        for (var i = 0; i < floats.length; i += 4) {
          final lum = floats[i] + floats[i + 1] + floats[i + 2];
          if (lum > maxLum) maxLum = lum;
        }
        return maxLum;
      }

      expect(maxLuminance(pixelsWithout), 0.0);
      expect(maxLuminance(pixelsWith), greaterThan(0.0));

      await scene.removeEntity(sunLight);
      lightManager.destroyLight(sunLight);
      await withSunSkybox.destroy();
      await plain.destroy();
    });
  });
}

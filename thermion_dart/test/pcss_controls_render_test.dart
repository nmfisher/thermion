import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper('pcss_controls');
  await testHelper.setup();

  test('render global and per-light PCSS controls', () async {
    final builder = ViewerBuilder(testHelper)
        .setRenderTargetEnabled(true)
        .setCameraLookAt(Vector3(4, 5, 7), focus: Vector3.zero())
        .setShadowsEnabled(true)
        .setShadowType(ShadowType.PCSS)
        .addSun(
          intensity: 100000,
          castShadows: true,
          direction: Vector3(-0.5, -1, -0.35).normalized(),
          sunAngularRadius: 5.0,
        )
        .addCube(position: Vector3.zero(), castShadows: true, createUbershader: true)
        .addPlane(
          position: Vector3(0, -1.1, 0),
          scale: Vector3.all(2),
          receiveShadows: true,
          castShadows: false,
          createUbershader: true,
          color: null,
        );

    await builder.execute((result) async {
      final lightManager = FilamentApp.instance!.lightManager;

      await result.viewer.view.setSoftShadowOptions(const SoftShadowOptions());
      await testHelper.capture(result.viewer.view, 'pcss_controls_default');

      await result.viewer.view.setSoftShadowOptions(
        const SoftShadowOptions(maxPenumbraRatio: 2.0, maxSearchRadius: 0.08),
      );
      await testHelper.capture(result.viewer.view, 'pcss_controls_global_clamped');

      final lightOptions = lightManager.getShadowOptions(result.sun!);
      await lightManager.setShadowOptions(
        result.sun!,
        lightOptions.copyWith(
          penumbraScale: 3.0,
          penumbraRatioScale: 4.0,
          maxPenumbraRatio: 6.0,
          maxSearchRadius: 0.75,
        ),
      );
      await testHelper.capture(result.viewer.view, 'pcss_controls_per_light_override');
    });
  });
}

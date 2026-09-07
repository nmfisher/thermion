import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Fractal electrical discharge with tapered forks, secondary leaders,
/// rounded channel segments, and timed return strokes.
Future<void> setupElectricity(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100,
    aspect: 1,
    focalLength: 38,
  );
  await camera.lookAt(Vector3(0, 0, 5.3), focus: Vector3(0, 0, 0));
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.32);
  await viewer.view.setFrustumCullingEnabled(false);
  const segments = 192;
  final electricity = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: 'electricity',
  );
  await electricity.setParameterFloat('time', 0.16);
  await electricity.setParameterFloat('segmentCount', segments.toDouble());
  await viewer.createGeometry(
    dummyBillboardQuads(segments),
    materialInstances: [electricity],
  );

  effectAnimators.add((t) async {
    await electricity.setParameterFloat('time', t);
  });
}

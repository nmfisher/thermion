import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// One-draw procedural lightning: coherent stepped trunk, seeded side forks,
/// sub-frame path regeneration, HDR core, and a soft ionized envelope.
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
  await camera.lookAt(Vector3(0, 0, 4.65), focus: Vector3(0, 0, 0));
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.68);
  const segments = 64;
  final electricity = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: 'electricity',
  );
  await electricity.setParameterFloat('time', 1.7);
  await electricity.setParameterFloat('segmentCount', segments.toDouble());
  await viewer.createGeometry(
    dummyBillboardQuads(segments),
    materialInstances: [electricity],
  );

  effectAnimators.add((t) async {
    await electricity.setParameterFloat('time', t);
  });
}

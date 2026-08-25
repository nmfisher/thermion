import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Deep-space portal with rotating tunnel parallax, opposing spiral flow,
/// star motes, a noisy high-energy rim, and a physically staged open/close.
Future<void> setupPortalRift(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100,
    aspect: 1,
    focalLength: 36,
  );
  await camera.lookAt(Vector3(0, 0, 3.15), focus: Vector3(0, 0, 0));
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.34);
  final portal = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: 'portal_rift',
  );
  await portal.setParameterFloat('time', 2.2);
  await portal.setParameterFloat('openAmount', 1.0);
  final rift = await viewer.createGeometry(
    GeometryUtils.plane(width: 3.1, height: 3.1),
    materialInstances: [portal],
  );
  await rift.setTransform(
    Matrix4.rotationX(1.5707963267948966) *
        Matrix4.diagonal3(Vector3(0.82, 1.0, 1.18)),
  );
  effectAnimators.add((t) async {
    final cycle = t % 5.0;
    final open = cycle < 0.8
        ? cycle / 0.8
        : cycle > 4.25
            ? (5.0 - cycle) / 0.75
            : 1.0;
    await portal.setParameterFloat('time', t);
    await portal.setParameterFloat('openAmount', open);
  });
}

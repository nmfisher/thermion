import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Layered impact decals: irregular holes, beveled hot rims, radial fracture
/// lines, soot falloff, and independent thermal decay for each strike.
Future<void> setupDamageDecals(
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
  await camera.lookAt(Vector3(0, 0.05, 4.0), focus: Vector3(0, 0, 0));
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.28);
  final decals = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: 'damage_decals',
  );
  await decals.setParameterFloat('time', 2.05);
  final wall = await viewer.createGeometry(
    subdividedPlane(
        width: 3.8, depth: 2.8, subdivisionsX: 32, subdivisionsZ: 24),
    materialInstances: [decals],
  );
  await wall.setTransform(Matrix4.rotationX(1.5707963267948966));
  effectAnimators.add((t) async {
    await decals.setParameterFloat('time', t % 3.2);
  });
}

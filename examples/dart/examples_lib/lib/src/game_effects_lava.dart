import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Lava field: a vertex-displaced crust of slow sine lumps over a molten
/// interior. The fragment shader drifts a domain-warped fbm crust field;
/// where it dips low, glowing cracks show through (an inverted dissolve)
/// with a fast-flowing interior texture and a red-orange-yellow ramp.
Future<void> setupLava(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100.0,
    aspect: 1.0,
    focalLength: 28.0,
  );
  await camera.lookAt(Vector3(0, 2.0, 4.6), focus: Vector3(0, -0.3, 0));

  await setDarkSkybox(viewer);

  final lava = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: "lava",
  );
  await lava.setParameterFloat("time", 3.0);
  await lava.setParameterFloat("glowIntensity", 1.5);
  await lava.setParameterFloat("crustScale", 1.0);
  await lava.setParameterFloat("flowSpeed", 0.5);
  await lava.setParameterFloat("swellHeight", 0.14);

  final surface = await viewer.createGeometry(
    subdividedPlane(width: 16.0, depth: 16.0, subdivisionsX: 176, subdivisionsZ: 176),
    materialInstances: [lava],
  );
  await surface.setTransform(Matrix4.translation(Vector3(0, 0, 0)));

  effectAnimators.add((t) async {
    await lava.setParameterFloat("time", t);
  });
}

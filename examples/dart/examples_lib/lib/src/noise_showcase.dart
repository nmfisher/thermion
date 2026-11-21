import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_shared.dart';

/// Noise texture generator zoo: a 4x3 wall of tiles, each a material
/// instance of the shared `noise_showcase` material with its own
/// `noiseType` selecting one of twelve procedural generators (white,
/// value, Perlin, simplex, fbm, billow, ridged, domain warp, Voronoi F1,
/// Worley crackle, curl flow, smooth Voronoi). The binary index dots in
/// each tile's bottom-left corner give the on-image legend; see
/// noise_showcase.mat for the full mapping and per-generator notes.
///
/// The generators double as a reference library: every function in the
/// material is standalone (modulo the two nzHash primitives), so an
/// effect material can lift the one it needs verbatim.
Future<void> setupNoiseShowcase(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  // The 4x3 wall is wider than tall, so this showcase renders as a 3:2
  // poster (1152x768): a square canvas with this grid clips the outer
  // columns (Filament derives a square FOV from focalLength at aspect 1).
  await camera.setLensProjection(
    near: 0.1,
    far: 100,
    aspect: 1.5,
    focalLength: 38,
  );
  await camera.lookAt(Vector3(0, 0, 4.9), focus: Vector3(0, 0, 0));

  await setDarkSkybox(viewer);
  // No bloom: these are reference textures, and bloom would smear the
  // finer lattices into mush.
  await viewer.setPostProcessing(true);
  await viewer.setBloom(false, 0.0);

  // Index -> lattice scale for the tile (pixels for white noise, cell
  // counts for everything else). Order matches the doc comment above.
  const tileScales = [
    150.0, // 0 white
    6.0, // 1 value
    5.0, // 2 perlin
    5.0, // 3 simplex
    3.2, // 4 fbm
    3.2, // 5 billow
    3.0, // 6 ridged
    2.2, // 7 domain warp
    4.5, // 8 voronoi F1
    4.5, // 9 crackle
    2.6, // 10 curl
    3.4, // 11 smooth voronoi
  ];

  const tile = 0.95;
  const pitch = 1.06;
  const columns = 4;

  // One compiled material, one instance per tile: the generator choice
  // is a per-instance uniform, so the whole wall costs a single matc
  // artifact.
  final bytes = await FilamentApp.instance!
      .loadResource("$assetsDir/noise_showcase.filamat");
  final material = await FilamentApp.instance!.createMaterial(bytes);

  final instances = <MaterialInstance>[];
  for (var i = 0; i < tileScales.length; i++) {
    final instance = await material.createInstance();
    await instance.setParameterFloat("noiseType", i.toDouble());
    await instance.setParameterFloat("scale", tileScales[i]);
    await instance.setParameterFloat("tileSize", tile);
    await instance.setParameterFloat("time", 2.6);

    final col = i % columns;
    final row = i ~/ columns;
    final plane = await viewer.createGeometry(
      subdividedPlane(
          width: tile, depth: tile, subdivisionsX: 1, subdivisionsZ: 1),
      materialInstances: [instance],
    );
    await plane.setTransform(
      Matrix4.translation(
            Vector3((col - 1.5) * pitch, (1 - row) * pitch, 0.0),
          ) *
          Matrix4.rotationX(1.5707963267948966),
    );
    instances.add(instance);
  }

  effectAnimators.add((t) async {
    for (final instance in instances) {
      await instance.setParameterFloat("time", t);
    }
  });
}

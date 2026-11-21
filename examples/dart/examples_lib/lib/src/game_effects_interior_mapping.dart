import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';

/// Spider-Man / Cyberpunk style 3D interior mapping: a flat architectural box
/// renders deep ray-intersected 3D office & apartment interiors (ceilings with
/// recessed troffers, hardwood/carpet floors, side walls, mid-room glowing
/// workstations, and Venetian blinds) behind reflective curtain-wall glass.
Future<void> setupInteriorMapping(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  final viewport = await viewer.view.getViewport();
  await camera.setLensProjection(
    near: 0.1,
    far: 120,
    aspect: viewport.height > 0 ? viewport.width / viewport.height : 1.0,
    focalLength: 34,
  );
  final focus = Vector3(0.4, 3.35, 0.4);
  await camera.lookAt(Vector3(5.6, 3.8, 7.6), focus: focus);
  effectCameraControls = EffectCameraControls(focus: focus);

  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 11000);
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.16);
  await viewer.setAntiAliasing(false, true, false);
  await viewer.setShadowsEnabled(true);

  await viewer.addDirectLight(
    DirectLight.sun(
      direction: Vector3(-0.55, -0.72, -0.42),
      color: const LinearColor(0.65, 0.78, 1.0),
      intensity: 11000,
      castShadows: true,
    ),
  );
  // Warm streetlamp bounce from below to catch the anodized mullions & lobby trim.
  await viewer.addDirectLight(
    DirectLight.point(
      position: Vector3(3.8, 1.1, 4.4),
      color: const LinearColor(1.0, 0.66, 0.32),
      intensity: 55000,
      falloffRadius: 12.0,
    ),
  );

  final facade = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: 'interior_mapping',
  );
  const halfX = 3.20, halfY = 3.24, halfZ = 2.56;
  await facade.setParameterFloat('time', 0.0);
  await facade.setParameterFloat('roomDepth', 1.15);
  await facade.setParameterFloat('occupancy', 0.76);
  await facade.setParameterFloat('blindClose', 0.42);
  await facade.setParameterFloat3('buildingHalf', halfX, halfY, halfZ);

  // Main high-rise tower block (6.40m x 6.48m x 5.12m = 5x6 front rooms, 4x6 side rooms).
  final tower = await effectBox(
    viewer,
    Vector3(0, halfY, 0),
    Vector3(halfX * 2, halfY * 2, halfZ * 2),
    facade,
  );
  await tower.setCastShadows(true);
  await tower.setReceiveShadows(true);

  // Architectural crown cornice, corner piers, sidewalk & wet night street plane.
  final trim = await viewer.app.createUbershaderMaterial();
  await trim.setBaseColorFactor(0.022, 0.026, 0.035, 1.0);
  await trim.setMetallicFactor(0.55);
  await trim.setRoughnessFactor(0.36);

  final asphalt = await viewer.app.createUbershaderMaterial();
  await asphalt.setBaseColorFactor(0.012, 0.015, 0.022, 1.0);
  await asphalt.setMetallicFactor(0.15);
  await asphalt.setRoughnessFactor(0.22);

  await effectBox(viewer, Vector3(0, -0.06, 0), Vector3(28, 0.12, 28),
      asphalt.materialInstance);
  await effectBox(viewer, Vector3(0, 0.06, 0),
      Vector3(halfX * 2 + 1.5, 0.12, halfZ * 2 + 1.5), trim.materialInstance);
  await effectBox(viewer, Vector3(0, halfY * 2 + 0.14, 0),
      Vector3(halfX * 2 + 0.28, 0.28, halfZ * 2 + 0.28), trim.materialInstance);

  // Rooftop mechanical penthouse silhouette.
  await effectBox(viewer, Vector3(-0.6, halfY * 2 + 0.62, -0.4),
      Vector3(2.4, 0.72, 1.9), trim.materialInstance);

  effectSliders.addAll([
    EffectSlider(
      'Room depth',
      min: 0.45,
      max: 2.2,
      initialValue: 1.15,
      setValue: (v) => facade.setParameterFloat('roomDepth', v),
    ),
    EffectSlider(
      'Lit occupancy',
      min: 0.1,
      max: 0.98,
      initialValue: 0.76,
      setValue: (v) => facade.setParameterFloat('occupancy', v),
    ),
    EffectSlider(
      'Venetian blinds',
      min: 0.0,
      max: 1.0,
      initialValue: 0.42,
      setValue: (v) => facade.setParameterFloat('blindClose', v),
    ),
  ]);

  effectAnimators.add((t) async {
    await facade.setParameterFloat('time', t);
    if (!effectCameraUserControlled) {
      // Smooth drone sweep around the 3D corner of the tower to showcase deep
      // parallax ceilings, side walls, mid-room workstations, and blinds!
      final sweep = 0.62 + 0.48 * math.sin(t * math.pi * 2 / 6.0);
      final elev = 3.75 + 0.95 * math.cos(t * math.pi * 2 / 6.0);
      const radius = 11.6;
      await camera.lookAt(
        Vector3(math.sin(sweep) * radius, elev, math.cos(sweep) * radius),
        focus: focus,
      );
    }
  });
}

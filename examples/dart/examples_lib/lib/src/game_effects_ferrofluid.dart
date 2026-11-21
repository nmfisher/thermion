import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';

/// Magnetic Rosensweig ferrofluid sculpture: a high-subdivision colloidal
/// liquid-chrome blob (`metallic: 0.90`, `clearCoat: 1.0`) erupts into sharp
/// conical spikes aligned with two counter-orbiting electromagnetic poles.
Future<void> setupFerrofluid(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  final viewport = await viewer.view.getViewport();
  await camera.setLensProjection(
    near: 0.1,
    far: 100,
    aspect: viewport.height > 0 ? viewport.width / viewport.height : 1.0,
    focalLength: 36,
  );
  final focus = Vector3(0, 0.35, 0);
  await camera.lookAt(Vector3(0.0, 1.65, 3.85), focus: focus);
  effectCameraControls = EffectCameraControls(focus: focus);

  await viewer.loadIbl('$assetsDir/default_env_ibl.ktx', intensity: 26000);
  await setDarkSkybox(viewer);
  await enableVfxPost(viewer, bloomStrength: 0.16);
  await viewer.setAntiAliasing(false, true, false);
  await viewer.setShadowsEnabled(true);

  await viewer.addDirectLight(
    DirectLight.sun(
      direction: Vector3(-0.48, -0.78, -0.40),
      color: const LinearColor(0.95, 0.98, 1.0),
      intensity: 68000,
      castShadows: true,
    ),
  );
  final coilLightA = await viewer.addDirectLight(
    DirectLight.point(
      position: Vector3(1.8, 0.8, 0.0),
      color: const LinearColor(0.20, 0.72, 1.0),
      intensity: 85000,
      falloffRadius: 6.5,
    ),
  );
  final coilLightB = await viewer.addDirectLight(
    DirectLight.point(
      position: Vector3(-1.8, 0.4, 0.0),
      color: const LinearColor(1.0, 0.48, 0.14),
      intensity: 75000,
      falloffRadius: 6.5,
    ),
  );

  // Dark anodized laboratory containment pedestal + glowing electromagnet orbs!
  final dishMat = await viewer.app.createUbershaderMaterial();
  await dishMat.setBaseColorFactor(0.016, 0.020, 0.028, 1.0);
  await dishMat.setMetallicFactor(0.65);
  await dishMat.setRoughnessFactor(0.22);

  await effectBox(
      viewer, Vector3(0, -0.78, 0), Vector3(7.0, 0.16, 7.0), dishMat.materialInstance);
  final base = await viewer.createGeometry(
    GeometryUtils.sphere(latitudeBands: 32, longitudeBands: 64),
    materialInstances: [dishMat.materialInstance],
  );
  await base.setTransform(
    Matrix4.translation(Vector3(0, -0.62, 0)) *
        Matrix4.diagonal3(Vector3(1.55, 0.14, 1.55)),
  );
  await base.setReceiveShadows(true);

  final ferro = await loadEffectMaterial(
    viewer,
    assetsDir: assetsDir,
    name: 'ferrofluid',
  );
  var viscosity = 0.35;
  await ferro.setParameterFloat('time', 0.0);
  await ferro.setParameterFloat('fieldStrength', 1.05);
  await ferro.setParameterFloat('spikeDensity', 5.2);
  await ferro.setParameterFloat('viscosity', viscosity);

  // High-resolution UV sphere (144 x 216 = 62k tris) so every Rosensweig cone tip
  // is needle-smooth without polygon faceting!
  final blob = await viewer.createGeometry(
    GeometryUtils.sphere(latitudeBands: 144, longitudeBands: 216),
    materialInstances: [ferro],
  );
  await blob.setTransform(
    Matrix4.translation(Vector3(0, 0.35, 0)) *
        Matrix4.diagonal3(Vector3.all(0.82)),
  );
  await blob.setCastShadows(true);
  await blob.setReceiveShadows(true);

  // Two visible glowing magnetic dipole probes orbiting the ferrofluid sphere!
  final probeCyanMat = await viewer.app.createUbershaderMaterial();
  await probeCyanMat.setBaseColorFactor(0.15, 0.75, 1.0, 1.0);
  await probeCyanMat.materialInstance
      .setParameterFloat4('emissiveFactor', 0.22, 0.82, 1.0, 0.95);
  final probeAmberMat = await viewer.app.createUbershaderMaterial();
  await probeAmberMat.setBaseColorFactor(1.0, 0.52, 0.14, 1.0);
  await probeAmberMat.materialInstance
      .setParameterFloat4('emissiveFactor', 1.0, 0.52, 0.14, 0.95);

  final probeSphere = GeometryUtils.sphere(latitudeBands: 20, longitudeBands: 28);
  final probeA = await viewer.createGeometry(probeSphere,
      materialInstances: [probeCyanMat.materialInstance]);
  final probeB = await viewer.createGeometry(probeSphere,
      materialInstances: [probeAmberMat.materialInstance]);
  await probeA.setCastShadows(false);
  await probeB.setCastShadows(false);

  effectSliders.addAll([
    EffectSlider(
      'Magnetic field',
      min: 0.0,
      max: 1.6,
      initialValue: 1.05,
      setValue: (v) => ferro.setParameterFloat('fieldStrength', v),
    ),
    EffectSlider(
      'Spike frequency',
      min: 2.8,
      max: 8.5,
      initialValue: 5.2,
      setValue: (v) => ferro.setParameterFloat('spikeDensity', v),
    ),
    EffectSlider(
      'Carrier viscosity',
      min: 0.0,
      max: 1.0,
      initialValue: 0.35,
      setValue: (v) async {
        viscosity = v;
        await ferro.setParameterFloat('viscosity', v);
      },
    ),
  ]);

  Future<void> animate(double t) async {
    await ferro.setParameterFloat('time', t);
    final speed = 1.45 + (0.55 - 1.45) * viscosity.clamp(0.0, 1.0);
    final a1 = t * speed;
    final a2 = -t * speed * 0.78 + 2.1;
    final p1 = Vector3(math.cos(a1), 0.36 * math.sin(a1 * 1.3), math.sin(a1))
      ..normalize()
      ..scale(1.52)
      ..add(Vector3(0, 0.35, 0));
    final p2 = Vector3(
        math.cos(a2) * 0.85, -0.32 * math.cos(a2), math.sin(a2) * 0.85)
      ..normalize()
      ..scale(1.52)
      ..add(Vector3(0, 0.35, 0));

    await probeA.setTransform(
        Matrix4.translation(p1) * Matrix4.diagonal3(Vector3.all(0.075)));
    await probeB.setTransform(
        Matrix4.translation(p2) * Matrix4.diagonal3(Vector3.all(0.068)));
    viewer.app.lightManager.setPosition(coilLightA, p1.x, p1.y, p1.z);
    viewer.app.lightManager.setPosition(coilLightB, p2.x, p2.y, p2.z);
  }

  await animate(0.0);
  effectAnimators.add(animate);
}

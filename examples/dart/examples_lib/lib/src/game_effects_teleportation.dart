import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';

/// A FlightHelmet bust dematerializes top-down on the source pad while
/// materializing bottom-up on the destination pad inside twin vertical energy
/// beams, linked by arcing velocity-streaked quantum plasma ribbons.
Future<void> setupTeleportation(ThermionViewer viewer,
    {required String assetsDir}) async {
  await setupInteractionStage(
      viewer, assetsDir, Vector3(0.35, 2.55, 6.6), Vector3(0, 0.95, 0),
      shadows: false);
  await viewer.view.setFrustumCullingEnabled(false);
  await viewer.view.setLayerVisibility(VisibilityLayers.LAYER_3, false);

  final ground = await viewer.app.createUbershaderMaterial();
  await ground.setBaseColorFactor(.014, .020, .030, 1);
  await ground.setMetallicFactor(.35);
  await ground.setRoughnessFactor(.32);
  await viewer.createGeometry(GeometryUtils.plane(width: 40, height: 40),
      materialInstances: [ground.materialInstance]);

  final source = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'teleport_surface');
  final target = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'teleport_surface');
  await source.setParameterFloat('origin', -1.45);
  await target.setParameterFloat('origin', 1.45);

  for (final (offset, material, yaw) in [
    (-1.45, source, 0.38),
    (1.45, target, -0.32),
  ]) {
    final helmet = await viewer.loadGltf('$assetsDir/FlightHelmet/FlightHelmet.gltf');
    await helmet.setMaterialInstanceForAll(material);
    // FlightHelmet native height is ~0.58m; scale 2.65x -> ~1.54m hero bust.
    await helmet.setTransform(
      Matrix4.translation(Vector3(offset, 0.12, 0)) *
          Matrix4.rotationY(yaw) *
          Matrix4.diagonal3(Vector3.all(2.65)),
    );
  }

  final random = math.Random(718);
  final vertices = <double>[];
  // Stratified shell samples matching the scaled FlightHelmet silhouette (y in 0.16..1.52).
  for (var i = 0; i < 380; i++) {
    final theta = random.nextDouble() * math.pi * 2;
    final h = random.nextDouble();
    final profileR = h < 0.35 ? 0.38 : (0.42 * math.sin((h - 0.1) * 2.6).clamp(0.25, 1.0));
    final r = profileR * (0.72 + 0.28 * random.nextDouble());
    final point = Vector3(
      math.cos(theta) * r,
      0.16 + h * 1.34,
      math.sin(theta) * r,
    );
    for (var k = 0; k < 6; k++) {
      vertices.addAll([point.x, point.y, point.z]);
    }
  }
  final particles = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'teleport_particles');
  final motes = await viewer.createGeometry(
      Geometry(Float32List.fromList(vertices),
          List<int>.generate(vertices.length ~/ 3, (i) => i)),
      materialInstances: [particles]);
  await motes.setCastShadows(false);

  // Open-ended vertical energy cylinder geometry for the two teleporter beams.
  Geometry beamCylinder({int segs = 40}) {
    final pos = <double>[];
    final idx = <int>[];
    for (var i = 0; i <= segs; i++) {
      final a = (i / segs) * math.pi * 2;
      final x = math.cos(a) * 0.68, z = math.sin(a) * 0.68;
      pos.addAll([x, -0.5, z, x, 0.5, z]);
      if (i < segs) {
        final b = i * 2;
        idx.addAll([b, b + 1, b + 2, b + 1, b + 3, b + 2]);
      }
    }
    return Geometry(Float32List.fromList(pos), idx);
  }

  final cylGeom = beamCylinder();
  final fields = <MaterialInstance>[];
  final beams = <MaterialInstance>[];
  for (final x in [-1.45, 1.45]) {
    final field = await loadEffectMaterial(viewer,
        assetsDir: assetsDir, name: 'teleport_field');
    await field.setParameterFloat('isBeam', 0.0);
    fields.add(field);
    final pad = await viewer.createGeometry(
        GeometryUtils.plane(width: 1.9, height: 1.9),
        materialInstances: [field]);
    await pad.setTransform(Matrix4.translation(Vector3(x, .018, 0)));
    await pad.setCastShadows(false);

    final beamMat = await loadEffectMaterial(viewer,
        assetsDir: assetsDir, name: 'teleport_field');
    await beamMat.setParameterFloat('isBeam', 1.0);
    beams.add(beamMat);
    final beam = await viewer.createGeometry(cylGeom, materialInstances: [beamMat]);
    await beam.setTransform(
      Matrix4.translation(Vector3(x, 1.22, 0)) *
          Matrix4.diagonal3(Vector3(1.0, 2.40, 1.0)),
    );
    await beam.setCastShadows(false);
  }
  final light = await viewer.addDirectLight(DirectLight.point(
      color: const LinearColor(.16, .58, 1),
      intensity: 0,
      position: Vector3(0, 1.5, .8),
      falloffRadius: 5.5));
  Future<void> animate(double t) async {
    // Phase-shifted so t=0 captures BOTH helmets mid-transfer (lower ~60% of source
    // helmet anchored on left pad dissolving top-down while lower ~55% of target
    // helmet builds bottom-up on right pad) with quantum ribbons arcing across!
    final cycle = (t + 1.48) % 6;
    final reset = effectEase(5.35, 5.95, cycle);
    final transfer = effectEase(.95, 2.85, cycle) * (1 - reset);
    await source.setParameterFloat('dissolve', -.06 + 1.16 * transfer);
    await target.setParameterFloat('dissolve', 1.08 - 1.16 * transfer);
    await particles.setParameterFloat(
        'travel', ((cycle - .85) / 2.15).clamp(0.0, 1.0));
    for (var i = 0; i < fields.length; i++) {
      await fields[i].setParameterFloat('time', t + 1.95);
      await beams[i].setParameterFloat('time', t + 1.95);
      final pulse =
          math.exp(-math.pow((cycle - (i == 0 ? 1.45 : 2.35)) / .75, 2));
      final s = .28 + pulse * .85;
      await fields[i].setParameterFloat('strength', s);
      await beams[i].setParameterFloat('strength', s);
    }
    viewer.app.lightManager.setIntensity(light,
        24000 * effectEase(.6, 1.3, cycle) * (1 - effectEase(2.9, 3.6, cycle)));
  }

  await animate(0);
  effectAnimators.add(animate);
}

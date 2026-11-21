import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

import 'game_effects_interaction_shared.dart';
import 'game_effects_shared.dart';
import 'meteor_impact_timeline.dart';

/// Irregular, flat-shaded rock; duplicate vertices for distinct facet normals.
Geometry _impactRock() {
  final sphere = GeometryUtils.sphere(latitudeBands: 7, longitudeBands: 11);
  final vertices = <double>[], normals = <double>[];
  final indices = <int>[];
  Vector3 point(int index) {
    final p = Vector3(sphere.vertices[index * 3],
        sphere.vertices[index * 3 + 1], sphere.vertices[index * 3 + 2]);
    return p *
        (.86 + .14 * math.sin(p.x * 7 + p.y * 4) * math.cos(p.z * 5 - p.y * 3));
  }

  for (var i = 0; i < sphere.indices.length; i += 3) {
    final a = point(sphere.indices[i]),
        b = point(sphere.indices[i + 1]),
        c = point(sphere.indices[i + 2]);
    final n = (b - a).cross(c - a);
    if (n.length2 < .000001) continue;
    n.normalize();
    final points = n.dot(a) < 0 ? [a, c, b] : [a, b, c];
    if (n.dot(a) < 0) n.negate();
    for (final p in points) {
      indices.add(indices.length);
      vertices.addAll([p.x, p.y, p.z]);
      normals.addAll([n.x, n.y, n.z]);
    }
  }
  return Geometry(Float32List.fromList(vertices), indices,
      normals: Float32List.fromList(normals));
}

/// Incoming molten rock, brief contact flash, ballistic ejecta, expanding
/// dust, and a cooling displaced crater. Six-second repeatable sequence.
Future<void> setupMeteorImpact(ThermionViewer viewer,
    {required String assetsDir}) async {
  await setupInteractionStage(
      viewer, assetsDir, Vector3(4.2, 3.8, 6.6), Vector3(0, .45, 0),
      shadows: false);
  final ground = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'impact_ground');
  await viewer.createGeometry(
      subdividedPlane(
          width: 18, depth: 18, subdivisionsX: 160, subdivisionsZ: 160),
      materialInstances: [ground]);
  final rock = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'meteor_rock');
  final rockGeometry = _impactRock();
  final meteor =
      await viewer.createGeometry(rockGeometry, materialInstances: [rock]);
  final trail = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'meteor_flare');
  await trail.setParameterFloat('mode', 0);
  final streak = await viewer.createGeometry(
      GeometryUtils.plane(width: 5, height: 1.5),
      materialInstances: [trail]);
  await streak.setCastShadows(false);
  final flash = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'meteor_flare');
  await flash.setParameterFloat('mode', 1);
  final burst = await viewer.createGeometry(
      GeometryUtils.plane(width: 6, height: 6),
      materialInstances: [flash]);
  await burst.setTransform(Matrix4.translation(Vector3(0, .3, .2)) *
      Matrix4.rotationY(.57) *
      Matrix4.rotationX(math.pi / 2));
  await burst.setCastShadows(false);
  final dust = await loadEffectMaterial(viewer,
      assetsDir: assetsDir, name: 'interaction_vapor');
  final updates = <Future<void> Function(double, double)>[];
  for (var i = 0; i < 26; i++) {
    final debris =
        await viewer.createGeometry(rockGeometry, materialInstances: [rock]);
    updates.add((age, fade) async {
      final localAge = math.max(0.0, age - (i % 7) * .027);
      final a = i * 2.39996, speed = .7 + (i % 5) * .19;
      final launch = .9 + ((i * 7) % 11) * .18;
      final landing = (launch + math.sqrt(launch * launch + .644)) / 2.8;
      final flightTime = math.min(localAge, landing);
      final settling = math.max(0.0, localAge - landing);
      final slide = .12 * (1 - math.exp(-settling * 8));
      final r = .1 + (flightTime + slide) * speed;
      final h =
          math.max(.035, .15 + localAge * launch - 1.4 * localAge * localAge);
      final size = math.max(
          .001, (.07 + (i % 4) * .025) * effectEase(0, .17, localAge) * fade);
      await debris.setTransform(
          Matrix4.translation(Vector3(math.cos(a) * r, h, math.sin(a) * r)) *
              Matrix4.rotationY(a + flightTime * 2) *
              Matrix4.rotationZ(flightTime * 3) *
              Matrix4.diagonal3(Vector3(size, size * .8, size * 1.15)));
    });
  }
  for (var i = 0; i < 9; i++) {
    final puff = await viewer.createGeometry(
        GeometryUtils.plane(width: 2.5, height: 2),
        materialInstances: [dust]);
    await puff.setCastShadows(false);
    updates.add((age, fade) async {
      final a = i * math.pi * 2 / 9;
      final expansion = age - .22 * (1 - math.exp(-age / .22));
      final r = .22 + expansion * .65;
      await puff.setTransform(Matrix4.translation(
              Vector3(math.cos(a) * r, .3 + age * .13, math.sin(a) * r)) *
          Matrix4.rotationY(.57) *
          Matrix4.rotationX(math.pi / 2) *
          Matrix4.diagonal3(Vector3.all(.6 + age * .2)));
    });
  }
  final light = await viewer.addDirectLight(DirectLight.point(
      color: const LinearColor(1, .28, .045),
      intensity: 0,
      falloffRadius: 5,
      position: Vector3(0, .6, 0)));
  Future<void> animate(double t) async {
    final frame = MeteorImpactFrame.at(t);
    final cycle = frame.cycle, age = frame.age;
    final travel = frame.flight + frame.penetration;
    final center = Vector3(-3.4 * (1 - travel), .24 + 4.2 * (1 - travel), 0);
    await meteor.setTransform(Matrix4.translation(center) *
        Matrix4.rotationZ(cycle * 3) *
        Matrix4.diagonal3(Vector3.all(.28 * frame.body + .001)));
    // Let residual flame dissipate at contact while the rock sinks.
    final trailCenter =
        Vector3(-3.4 * (1 - frame.flight), .24 + 4.2 * (1 - frame.flight), 0);
    await streak.setTransform(Matrix4.translation(trailCenter) *
        Matrix4.rotationZ(2.25) *
        Matrix4.rotationX(math.pi / 2));
    await trail.setParameterFloat('time', t);
    await trail.setParameterFloat('strength', frame.trail);
    await flash.setParameterFloat('time', age);
    await flash.setParameterFloat('strength', frame.flash);
    await ground.setParameterFloat('age', age);
    await ground.setParameterFloat('strength', frame.crater);
    await rock.setParameterFloat('heat', math.exp(-age * .7));
    await dust.setParameterFloat('time', t);
    await dust.setParameterFloat4('tint', .075, .055, .038, .65 * frame.dust);
    for (final update in updates) {
      await update(age, frame.fade);
    }
    viewer.app.lightManager.setIntensity(light, frame.light * 75000);
  }

  await animate(1.65);
  effectAnimators.add(animate);
}

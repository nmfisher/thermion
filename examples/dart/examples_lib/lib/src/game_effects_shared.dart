import 'dart:math';

import 'package:thermion_dart/thermion_dart.dart';

/// Flat XZ grid with (subdivisionsX+1)*(subdivisionsZ+1) vertices, normals
/// up, UVs across [0,1]. GeometryUtils.plane is only 4 vertices, far too
/// coarse for vertex-displaced surfaces like water.
Geometry subdividedPlane({
  double width = 10.0,
  double depth = 10.0,
  int subdivisionsX = 64,
  int subdivisionsZ = 64,
}) {
  final vertCount = (subdivisionsX + 1) * (subdivisionsZ + 1);
  final vertices = Float32List(vertCount * 3);
  final normals = Float32List(vertCount * 3);
  final uvs = Float32List(vertCount * 2);
  final indices = <int>[];

  for (int z = 0; z <= subdivisionsZ; z++) {
    for (int x = 0; x <= subdivisionsX; x++) {
      final i = z * (subdivisionsX + 1) + x;
      final u = x / subdivisionsX;
      final v = z / subdivisionsZ;
      vertices[i * 3] = (u - 0.5) * width;
      vertices[i * 3 + 1] = 0.0;
      vertices[i * 3 + 2] = (v - 0.5) * depth;
      normals[i * 3] = 0.0;
      normals[i * 3 + 1] = 1.0;
      normals[i * 3 + 2] = 0.0;
      uvs[i * 2] = u;
      uvs[i * 2 + 1] = v;
    }
  }

  for (int z = 0; z < subdivisionsZ; z++) {
    for (int x = 0; x < subdivisionsX; x++) {
      final tl = z * (subdivisionsX + 1) + x;
      final tr = tl + 1;
      final bl = tl + (subdivisionsX + 1);
      final br = bl + 1;
      indices.addAll([tl, bl, tr, tr, bl, br]);
    }
  }

  return Geometry(
    vertices,
    indices,
    normals: normals,
    uvs: uvs,
  );
}

/// Flat-shaded six-sided crystal with a long prismatic body and a pointed
/// crown. Vertices are duplicated per face so the facets stay hard under any
/// material, unlike a smooth cone whose silhouette reads as a stalagmite.
Geometry crystalShard({
  double radius = 0.32,
  double length = 1.0,
  double shoulder = 0.72,
}) {
  final vertices = <double>[];
  final normals = <double>[];
  final indices = <int>[];

  void face(List<Vector3> points) {
    final base = vertices.length ~/ 3;
    final edgeA = points[1] - points[0];
    final edgeB = points[2] - points[0];
    final normal = edgeA.cross(edgeB)..normalize();
    for (final point in points) {
      vertices.addAll([point.x, point.y, point.z]);
      normals.addAll([normal.x, normal.y, normal.z]);
    }
    if (points.length == 3) {
      indices.addAll([base, base + 1, base + 2]);
    } else {
      indices.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
    }
  }

  final bottom = <Vector3>[];
  final top = <Vector3>[];
  for (var i = 0; i < 6; i++) {
    final angle = i * 1.0471975511965976;
    bottom.add(Vector3(radius * cos(angle), 0, radius * sin(angle)));
    top.add(
      Vector3(
        radius * 0.82 * cos(angle),
        length * shoulder,
        radius * 0.82 * sin(angle),
      ),
    );
  }
  final tip = Vector3(0, length, 0);
  for (var i = 0; i < 6; i++) {
    final next = (i + 1) % 6;
    face([bottom[i], bottom[next], top[next], top[i]]);
    face([top[i], top[next], tip]);
  }
  face([bottom[0], bottom[2], bottom[1]]);
  face([bottom[0], bottom[3], bottom[2]]);
  face([bottom[0], bottom[4], bottom[3]]);
  face([bottom[0], bottom[5], bottom[4]]);
  return Geometry(
    Float32List.fromList(vertices),
    indices,
    normals: Float32List.fromList(normals),
  );
}

/// Degenerate geometry for [quadCount] billboards fully generated in the
/// vertex shader (see smoke.mat): 6 vertices per puff keep the POSITION
/// attribute bound and indexed, while the shader derives real positions
/// from getVertexIndex(). Index type must stay UINT even though indices
/// are sequential - they address the vertex buffer directly.
///
/// The vertices are NOT all-zero: a fully degenerate vertex buffer yields a
/// zero-size bounding box, which makes frustum culling of the renderable
/// unreliable. Each puff's 6 vertices therefore sit at a deterministic
/// point inside a small box around the origin - large enough for a valid
/// bounding volume, small enough that the vertex shader can treat its
/// displacement as purely additive (see the NOTE in smoke.mat: only
/// additive worldPosition displacements survive the pipeline).
Geometry dummyBillboardQuads(int quadCount) {
  final vertCount = quadCount * 6;
  final vertices = Float32List(vertCount * 3);

  double fract(double x) => x - x.floorToDouble();
  double hash(int n) {
    var v = 0.0;
    for (var i = 0; i < 8; i++) {
      v = fract(v * 61.7 + n * 0.1031);
    }
    return v;
  }

  for (var q = 0; q < quadCount; q++) {
    final x = (hash(q * 3 + 1) - 0.5) * 0.7;
    final y = hash(q * 3 + 2) * 0.5;
    final z = (hash(q * 3 + 3) - 0.5) * 0.7;
    for (var v = 0; v < 6; v++) {
      final i = (q * 6 + v) * 3;
      vertices[i] = x;
      vertices[i + 1] = y;
      vertices[i + 2] = z;
    }
  }
  return Geometry(
    vertices,
    List<int>.generate(vertCount, (i) => i),
  );
}

/// Clock for driving effect animation.
///
/// Two modes:
///  - [tick] from a `registerRequestFrameHook` callback in a live runner
///    (the headless runner's `capture()` bypasses hooks entirely).
///  - [setTime] to jump to a fixed "golden" time so still captures show the
///    effect at an interesting point in its animation.
class EffectClock {
  final Stopwatch _sw = Stopwatch()..start();

  double elapsedTime = 0.0;

  /// Call from a requestFrameHook to advance time from the wall clock.
  void tick() {
    elapsedTime = _sw.elapsedMilliseconds / 1000.0;
  }

  /// Jump to a fixed time (for deterministic still captures).
  void setTime(double t) {
    elapsedTime = t;
  }
}

/// Time-driven animators registered by the game-effect setups. The headless
/// runner's `--video` mode passes wall-clock seconds; each closure maps t to
/// uniform updates on its own instances. (capture() bypasses requestFrame
/// hooks, so animation for video/stills is driven through these instead.)
final List<Future<void> Function(double t)> effectAnimators = [];

/// Loads one of the game-effect materials from `examples/assets` and returns
/// a ready-to-use [MaterialInstance].
Future<MaterialInstance> loadEffectMaterial(
  ThermionViewer viewer, {
  required String assetsDir,
  required String name,
}) async {
  final Uint8List bytes =
      await FilamentApp.instance!.loadResource("$assetsDir/$name.filamat");
  final material = await FilamentApp.instance!.createMaterial(bytes);
  return await material.createInstance();
}

/// Near-black skybox for additive effects (smoke, force field, hit flash),
/// which wash out against a bright background. The engine's default exposure
/// lifts small linear values considerably, so these are deliberately tiny.
Future<void> setDarkSkybox(ThermionViewer viewer) async {
  await (await viewer.view.getScene()).setSkybox(
    await FilamentApp.instance!
        .createColoredSkybox(r: 0.004, g: 0.005, b: 0.012, a: 1.0),
  );
}

/// Enables the post stack used by the presentation renders. In particular,
/// emissive game VFX need bloom to turn shader radiance into a perceptual
/// glow; without it even correct HDR values read like flat cutouts.
Future<void> enableVfxPost(
  ThermionViewer viewer, {
  double bloomStrength = 0.3,
}) async {
  await viewer.setPostProcessing(true);
  await viewer.setBloom(true, bloomStrength);
}

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

/// Degenerate geometry for [quadCount] billboards fully generated in the
/// vertex shader (see smoke.mat): 6 zeroed vertices per puff keep the
/// POSITION attribute bound and indexed, while the shader derives real
/// positions from getVertexIndex(). Index type must stay UINT even though
/// indices are sequential - they address the vertex buffer directly.
Geometry dummyBillboardQuads(int quadCount) {
  final vertCount = quadCount * 6;
  return Geometry(
    Float32List(vertCount * 3),
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

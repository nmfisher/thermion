import 'dart:math' as math;

import 'package:thermion_dart/thermion_dart.dart';

/// Parallax occlusion mapping: three brick walls rendered with the same
/// material (`examples/assets/parallax.filamat`) at increasing effect
/// strength. The camera looks from +X, so the LEFT wall is the most oblique
/// and shows the strongest parallax:
///
///   left   - full POM + normal map (heightScale > 0)
///   middle - normal map only       (heightScale = 0)
///   right  - flat baseline         (no height, no normal)
///
/// All three textures (albedo/height/normal) are generated procedurally in
/// Dart - no binary assets, deterministic goldens. Set `debugView` on an
/// instance for shader introspection (1=height, 2=|uv offset|, 3=ts view).
Future<void> setupParallax(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final app = FilamentApp.instance!;

  // Lens aspect follows the actual viewport so the three-wall layout keeps
  // its proportions on any canvas (filament derives a square FOV from
  // focalLength; rendering a wide layout on a square canvas clips the outer
  // walls).
  var aspect = 1.0;
  try {
    final viewport = await viewer.view.getViewport();
    if (viewport.height > 0) {
      aspect = viewport.width / viewport.height;
    }
  } catch (_) {
    // headless before first resize - keep square
  }

  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100.0,
    aspect: aspect,
    focalLength: 32.0,
  );
  await camera.lookAt(Vector3(2.6, 0.75, 1.8), focus: Vector3(0.0, 0.5, 0.0));

  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.addDirectLight(
    DirectLight.sun(direction: Vector3(-0.35, -0.6, -0.75)),
  );

  final brick = _BrickTextures(size: 512);

  final sampler = await app.createTextureSampler(
    minFilter: TextureMinFilter.LINEAR_MIPMAP_LINEAR,
    magFilter: TextureMagFilter.LINEAR,
    wrapS: TextureWrapMode.REPEAT,
    wrapT: TextureWrapMode.REPEAT,
  );

  Future<Texture> upload(Uint8List rgba) async {
    final texture = await app.createTexture(
      brick.size,
      brick.size,
      levels: 10, // log2(512) + 1
      flags: const {
        TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
        TextureUsage.TEXTURE_USAGE_UPLOADABLE,
        TextureUsage.TEXTURE_USAGE_GEN_MIPMAPPABLE,
      },
      textureFormat: TextureFormat.RGBA8,
    );
    await texture.setImage(
      0,
      rgba,
      brick.size,
      brick.size,
      PixelDataFormat.RGBA,
      PixelDataType.UBYTE,
    );
    await texture.generateMipmaps();
    return texture;
  }

  final albedoTex = await upload(brick.albedo);
  final heightTex = await upload(brick.height);
  final normalTex = await upload(brick.normal);

  final material =
      await app.createMaterial(await app.loadResource("$assetsDir/parallax.filamat"));

  Future<void> wall(
    double centerX, {
    required double heightScale,
    required double normalStrength,
  }) async {
    final instance = await material.createInstance();
    await instance.setParameterTexture('albedoMap', albedoTex, sampler);
    await instance.setParameterTexture('heightMap', heightTex, sampler);
    await instance.setParameterTexture('normalMap', normalTex, sampler);
    await instance.setParameterFloat('heightScale', heightScale);
    await instance.setParameterFloat('minSteps', 16.0);
    await instance.setParameterFloat('maxSteps', 64.0);
    await instance.setParameterFloat('normalStrength', normalStrength);
    await instance.setParameterFloat4('tintColor', 1.0, 1.0, 1.0, 1.0);
    await instance.setParameterFloat('roughnessFactor', 0.8);
    await instance.setParameterFloat('metallicFactor', 0.0);
    await instance.setParameterInt('debugView', 0);
    await viewer.createGeometry(
      _wallGeometry(centerX),
      materialInstances: [instance],
    );
  }

  await wall(-1.05, heightScale: 0.07, normalStrength: 1.0);
  await wall(0.0, heightScale: 0.0, normalStrength: 1.0);
  await wall(1.05, heightScale: 0.0, normalStrength: 0.0);
}

/// A subdivided quad in the XY plane (facing +Z), bottom edge at y=0,
/// centered on [centerX]. Normals + UVs are included so createGeometry
/// auto-generates the tangent frame the parallax material requires.
Geometry _wallGeometry(
  double centerX, {
  int sub = 24,
  double width = 1.0,
  double height = 1.0,
}) {
  final vertCount = (sub + 1) * (sub + 1);
  final vertices = Float32List(vertCount * 3);
  final normals = Float32List(vertCount * 3);
  final uvs = Float32List(vertCount * 2);

  var vi = 0;
  var ui = 0;
  for (var iy = 0; iy <= sub; iy++) {
    for (var ix = 0; ix <= sub; ix++) {
      final u = ix / sub;
      final v = iy / sub;
      vertices[vi++] = centerX + (u - 0.5) * width;
      vertices[vi++] = v * height;
      vertices[vi++] = 0.0;
      normals[iy * (sub + 1) * 3 + ix * 3 + 2] = 1.0;
      uvs[ui++] = u;
      uvs[ui++] = v;
    }
  }

  final indices = <int>[];
  for (var iy = 0; iy < sub; iy++) {
    for (var ix = 0; ix < sub; ix++) {
      final v00 = iy * (sub + 1) + ix;
      final v10 = v00 + 1;
      final v11 = v00 + sub + 2;
      final v01 = v00 + sub + 1;
      // CCW seen from +Z
      indices.addAll([v00, v10, v11, v00, v11, v01]);
    }
  }

  return Geometry(vertices, indices, normals: normals, uvs: uvs);
}

/// ---------------------------------------------------------------------------
/// Procedural running-bond brick textures (albedo / height / tangent-space
/// normal), all generated from one height field so they stay registered.
/// Deterministic (sin-hash + value noise) - stable golden renders.
/// ---------------------------------------------------------------------------
class _BrickTextures {
  final int size;

  /// bricks per texture tile: 4 columns x 8 rows
  static const int _brickW = 128;
  static const int _brickH = 64;
  static const int _joint = 4; // joint half-width, in px (bricks share it)
  static const int _falloff = 20; // brick edge bevel, in px
  static const double _kNormal = 60.0; // height-gradient -> normal slope

  late final Float32List _heights;
  late final Uint8List height;
  late final Uint8List albedo;
  late final Uint8List normal;

  _BrickTextures({required this.size}) {
    assert(size % _brickW == 0 && size % _brickH == 0);
    _heights = Float32List(size * size);

    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        _heights[y * size + x] = _heightAt(x, y);
      }
    }

    height = Uint8List(size * size * 4);
    albedo = Uint8List(size * size * 4);
    normal = Uint8List(size * size * 4);

    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final i = y * size + x;
        final h = _heights[i];

        // height in R (redundant RGBA for a single, simple upload path)
        height[i * 4 + 0] = _toByte(h);
        height[i * 4 + 1] = _toByte(h);
        height[i * 4 + 2] = _toByte(h);
        height[i * 4 + 3] = 255;

        // albedo (linear space)
        final color = _albedoAt(x, y);
        albedo[i * 4 + 0] = _toByte(color[0]);
        albedo[i * 4 + 1] = _toByte(color[1]);
        albedo[i * 4 + 2] = _toByte(color[2]);
        albedo[i * 4 + 3] = 255;

        // tangent-space normal via wrapped central differences
        final hL = _heights[y * size + ((x - 1 + size) % size)];
        final hR = _heights[y * size + ((x + 1) % size)];
        final hD = _heights[((y - 1 + size) % size) * size + x];
        final hU = _heights[((y + 1) % size) * size + x];
        final gx = (hR - hL) * 0.5;
        final gy = (hU - hD) * 0.5;
        var nx = -gx * _kNormal;
        var ny = -gy * _kNormal;
        const nz = 1.0;
        final len = math.sqrt(nx * nx + ny * ny + nz * nz);
        nx /= len;
        ny /= len;
        normal[i * 4 + 0] = _toByte(nx * 0.5 + 0.5);
        normal[i * 4 + 1] = _toByte(ny * 0.5 + 0.5);
        normal[i * 4 + 2] = _toByte(0.5 / len + 0.5); // nz/len
        normal[i * 4 + 3] = 255;
      }
    }
  }

  static int _toByte(double v) {
    final b = (v * 255.0).round();
    return b < 0 ? 0 : (b > 255 ? 255 : b);
  }

  static double _hash(double x, double y) {
    final v = math.sin(x * 127.1 + y * 311.7) * 43758.5453;
    return v - v.floorToDouble();
  }

  static double _smoothstep(double t) {
    if (t <= 0.0) return 0.0;
    if (t >= 1.0) return 1.0;
    return t * t * (3.0 - 2.0 * t);
  }

  static double _noise(double x, double y) {
    final xf = x.floorToDouble();
    final yf = y.floorToDouble();
    final fx = x - xf;
    final fy = y - yf;
    final u = _smoothstep(fx);
    final v = _smoothstep(fy);
    final xi = xf.toInt();
    final yi = yf.toInt();
    final a = _hash(xi.toDouble(), yi.toDouble());
    final b = _hash((xi + 1).toDouble(), yi.toDouble());
    final c = _hash(xi.toDouble(), (yi + 1).toDouble());
    final d = _hash((xi + 1).toDouble(), (yi + 1).toDouble());
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
  }

  /// Brick-cell lookup for pixel (x, y): returns the local coords within the
  /// brick, whether the pixel is in the mortar joint, and a per-brick hash.
  ({int bx, int by, bool joint, double brickHash}) _cellAt(int x, int y) {
    final row = y ~/ _brickH;
    final offset = row.isOdd ? _brickW ~/ 2 : 0;
    final wrapped = x + offset;
    final col = wrapped ~/ _brickW;
    final bx = wrapped % _brickW;
    final by = y % _brickH;
    final joint = bx < _joint ||
        bx >= _brickW - _joint ||
        by < _joint ||
        by >= _brickH - _joint;
    return (
      bx: bx,
      by: by,
      joint: joint,
      brickHash: _hash(col.toDouble(), row.toDouble()),
    );
  }

  double _heightAt(int x, int y) {
    final cell = _cellAt(x, y);
    final n = _noise(x / 23.0, y / 23.0);
    if (cell.joint) {
      return 0.04 + 0.02 * n;
    }
    final fx = _smoothstep(((cell.bx < _brickW - cell.bx
                ? cell.bx
                : _brickW - 1 - cell.bx) -
            _joint) /
        _falloff);
    final fy = _smoothstep(((cell.by < _brickH - cell.by
                ? cell.by
                : _brickH - 1 - cell.by) -
            _joint) /
        _falloff);
    final bow = fx * fy;
    return 0.40 + 0.50 * bow + 0.05 * cell.brickHash + 0.04 * n;
  }

  List<double> _albedoAt(int x, int y) {
    final cell = _cellAt(x, y);
    final n = _noise(x / 31.0 + 7.0, y / 31.0 + 3.0);
    if (cell.joint) {
      final g = 0.22 + 0.02 * n;
      return [g, g * 0.99, g * 0.97];
    }
    final shade = 0.75 + 0.5 * cell.brickHash + 0.06 * (n - 0.5);
    return [0.40 * shade, 0.05 * shade, 0.03 * shade];
  }
}

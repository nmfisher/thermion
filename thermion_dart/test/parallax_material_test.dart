import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

/// Exercise the compiled example material on the active GPU backend. Compare
/// against the same lit surface with analytically shifted UVs and POM disabled,
/// so lighting and tone mapping do not need to be reproduced by the test.
void main() async {
  final helper = TestHelper('parallax');
  await helper.setup();

  test('POM reaches constant heights with large tiled UVs', () async {
    await helper.withViewer((viewer) async {
      final fixture = await _ParallaxFixture.create(helper, viewer);
      await fixture.setView(0.4);
      for (final height in [0, 128, 255]) {
        await fixture.setHeights(List.filled(512, height));
        for (final steps in [96.0, 512.0]) {
          for (final u in [0.5, 10.5]) {
            // u=10 exposes half-precision UV increments rounding to zero.
            final actual = await fixture.render(u, heightScale: 0.1, minSteps: steps, steps: steps);
            final offset = -0.4 * 0.1 * (1.0 - height / 255.0);
            final expected = await fixture.render(u + offset);
            _expectSameColor(actual, expected, 'height=$height, steps=$steps, u=$u');
          }
        }
      }
      await fixture.dispose();
    }, viewportDimensions: (width: 33, height: 33));
  });

  test('texture-aware sampling finds a narrow ridge before the bottom', () async {
    await helper.withViewer((viewer) async {
      final fixture = await _ParallaxFixture.create(helper, viewer);
      final viewSlope = math.tan(65.0 * math.pi / 180.0);
      await fixture.setView(viewSlope);
      // Two adjacent white texels form a ridge that fits between the old
      // angle-only march samples. Linear filtering makes its sides ramps.
      final heights = List<int>.filled(512, 0);
      heights[282] = heights[283] = 255;
      await fixture.setHeights(heights);
      const startU = 0.5575;
      final rayOffset = -viewSlope * 0.1;
      // On the right side, height(u) = 284.5 - 512*u. Solve
      // depth = 1 - height(startU + rayOffset*depth) analytically.
      final hitDepth = (512.0 * startU - 283.5) / (1.0 - 512.0 * rayOffset);
      final expected = await fixture.render(startU + rayOffset * hitDepth);
      final actual = await fixture.render(startU, heightScale: 0.1, steps: 512);
      _expectSameColor(actual, expected, 'first ridge intersection');
      // Guard against a vacuous comparison (e.g. an unlit/black render).
      final bottom = await fixture.render(startU + rayOffset);
      expect((bottom[0] - expected[0]).abs(), greaterThan(0.01));
      await fixture.dispose();
    }, viewportDimensions: (width: 33, height: 33));
  });

  test('POM shadows follow the light and preserve environment lighting', () async {
    await helper.withViewer((viewer) async {
      final fixture = await _ParallaxFixture.create(helper, viewer);
      await fixture.setView(0);
      final heights = List<int>.filled(512, 0)..fillRange(280, 305, 255);
      await fixture.setHeights(heights);
      final lights = FilamentApp.instance!.lightManager;
      lights.setDirection(fixture.light, -1, 0, -1); // light above and to +U

      await fixture.instance.setParameterFloat('shadowStrength', 0);
      final unshadowed = await fixture.render(0.5, heightScale: 0.1);
      await fixture.instance.setParameterFloat('shadowStrength', 1);
      final shadowed = await fixture.render(0.5, heightScale: 0.1);
      expect(unshadowed[0], greaterThan(0.01));
      expect(shadowed[0], lessThan(unshadowed[0] * 0.05));

      // Reversing the light removes the blocker; the view stays fixed.
      lights.setDirection(fixture.light, 1, 0, -1);
      final clear = await fixture.render(0.5, heightScale: 0.1);
      await fixture.instance.setParameterFloat('shadowStrength', 0);
      _expectSameColor(clear, await fixture.render(0.5, heightScale: 0.1), 'unblocked light');

      // No height means no height-field shadows, even with a nonuniform map.
      lights.setDirection(fixture.light, -1, 0, -1);
      final flat = await fixture.render(0.5);
      await fixture.instance.setParameterFloat('shadowStrength', 1);
      _expectSameColor(await fixture.render(0.5), flat, 'zero displacement');

      await viewer.loadIbl('file://${helper.assetsDir}/default_env_ibl.ktx', intensity: 30000);
      lights.setIntensity(fixture.light, 0);
      final ambientOnly = await fixture.render(0.5, heightScale: 0.1);
      lights.setIntensity(fixture.light, 100000);
      final ambientInShadow = await fixture.render(0.5, heightScale: 0.1);
      _expectSameColor(ambientInShadow, ambientOnly, 'environment light survives direct shadow');
      await fixture.dispose();
    }, viewportDimensions: (width: 33, height: 33));
  });

  test('POM shadows attenuate each light independently', () async {
    await helper.withViewer((viewer) async {
      final fixture = await _ParallaxFixture.create(helper, viewer);
      await fixture.setView(0);
      await fixture.setHeights(List<int>.filled(512, 0)..fillRange(280, 305, 255));
      final lights = FilamentApp.instance!.lightManager;
      lights.setDirection(fixture.light, -1, 0, -1);
      lights.setColor(fixture.light, 1, 0, 0);
      await viewer.addDirectLight(
        DirectLight.point(
          color: const LinearColor(0, 1, 0),
          position: Vector3(-1, 0, 1),
          intensity: 1000000,
          falloffRadius: 5,
          castShadows: false,
        ),
      );
      await fixture.instance.setParameterFloat('shadowStrength', 0);
      final unshadowed = await fixture.render(0.5, heightScale: 0.1);
      await fixture.instance.setParameterFloat('shadowStrength', 1);
      final shadowed = await fixture.render(0.5, heightScale: 0.1);
      expect(unshadowed[0], greaterThan(0.01));
      expect(unshadowed[1], greaterThan(0.01));
      expect(shadowed[0], lessThan(unshadowed[0] * 0.05), reason: 'red light blocked');
      expect(shadowed[1], closeTo(unshadowed[1], 0.002), reason: 'green point light unblocked');
      await fixture.dispose();
    }, viewportDimensions: (width: 33, height: 33));
  });

  test('constant height fields do not shadow themselves at grazing light angles', () async {
    await helper.withViewer((viewer) async {
      final fixture = await _ParallaxFixture.create(helper, viewer);
      await fixture.setView(0.4);
      final lights = FilamentApp.instance!.lightManager;
      for (final height in [0, 128, 255]) {
        await fixture.setHeights(List.filled(512, height));
        for (final slope in [-5.0, 5.0]) {
          lights.setDirection(fixture.light, -slope, 0, -1);
          await fixture.instance.setParameterFloat('shadowStrength', 0);
          final clear = await fixture.render(0.5, heightScale: 0.1);
          await fixture.instance.setParameterFloat('shadowStrength', 1);
          final shadowed = await fixture.render(0.5, heightScale: 0.1);
          _expectSameColor(shadowed, clear, 'height=$height, light slope=$slope');
        }
      }
      await fixture.dispose();
    }, viewportDimensions: (width: 33, height: 33));
  });
}

void _expectSameColor(List<double> actual, List<double> expected, String reason) {
  expect(expected[0], greaterThan(0.01), reason: 'surface must be visible: $reason');
  for (var channel = 0; channel < 3; channel++) {
    expect(actual[channel], closeTo(expected[channel], 0.002), reason: reason);
  }
}

class _ParallaxFixture {
  final TestHelper helper;
  final ThermionViewer viewer;
  final Material material;
  final MaterialInstance instance;
  final Texture albedo;
  final Texture height;
  final Texture normal;
  final TextureSampler sampler;
  final ThermionEntity light;

  _ParallaxFixture(
    this.helper,
    this.viewer,
    this.material,
    this.instance,
    this.albedo,
    this.height,
    this.normal,
    this.sampler,
    this.light,
  );

  static Future<_ParallaxFixture> create(TestHelper helper, ThermionViewer viewer) async {
    final app = FilamentApp.instance!;
    // Only explicit captures should drive this viewer. Background ticks share
    // the renderer and can clear the swapchain between render and readPixels.
    await app.renderManager.setRenderable(viewer.view, false);
    final material = await app.createMaterial(await loadResourceBytes('${helper.assetsDir}/parallax.filamat'));
    final instance = await material.createInstance();
    final sampler = await app.createTextureSampler(
      minFilter: TextureMinFilter.LINEAR,
      magFilter: TextureMagFilter.LINEAR,
      wrapS: TextureWrapMode.REPEAT,
      wrapT: TextureWrapMode.REPEAT,
    );
    Future<Texture> texture(int width, Uint8List pixels) async {
      final result = await app.createTexture(width, 1, textureFormat: TextureFormat.RGBA8);
      await result.setImage(0, pixels, width, 1, PixelDataFormat.RGBA, PixelDataType.UBYTE);
      return result;
    }

    final albedoPixels = Uint8List(256 * 4);
    for (var x = 0; x < 256; x++) {
      albedoPixels.setRange(x * 4, x * 4 + 4, [x, 64, 128, 255]);
    }
    final albedo = await texture(256, albedoPixels);
    final height = await texture(512, Uint8List(512 * 4));
    final normal = await texture(1, Uint8List.fromList([128, 128, 255, 255]));
    await instance.setParameterTexture('albedoMap', albedo, sampler);
    await instance.setParameterTexture('heightMap', height, sampler);
    await instance.setParameterTexture('normalMap', normal, sampler);
    await instance.setParameterFloat('normalStrength', 0);
    await instance.setParameterFloat('shadowStrength', 1);
    await instance.setParameterFloat('shadowSteps', 256);
    await instance.setParameterFloat('shadowBias', 0.005);
    await instance.setParameterFloat('roughnessFactor', 1);
    await instance.setParameterFloat('metallicFactor', 0);
    await instance.setParameterFloat4('tintColor', 1, 1, 1, 1);
    await instance.setParameterInt('debugView', 0);
    final light = await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, 0, -1), castShadows: false));
    return _ParallaxFixture(helper, viewer, material, instance, albedo, height, normal, sampler, light);
  }

  Future<void> setView(double slope) async {
    final camera = await viewer.getActiveCamera();
    await camera.lookAt(Vector3(slope, 0, 1), focus: Vector3.zero());
    // Magnify a tiny central patch so the center pixel probes the specified UV
    // and the height texture stays at its base mip even at grazing incidence.
    await camera.setProjection(Projection.Orthographic, -0.0001, 0.0001, -0.0001, 0.0001, 0.1, 100);
  }

  Future<void> setHeights(List<int> values) async {
    final pixels = Uint8List(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      pixels.setRange(i * 4, i * 4 + 4, [values[i], 0, 0, 255]);
    }
    await height.setImage(0, pixels, values.length, 1, PixelDataFormat.RGBA, PixelDataType.UBYTE);
  }

  Future<List<double>> render(double centerU, {double heightScale = 0, double minSteps = 16, double steps = 96}) async {
    await instance.setParameterFloat('heightScale', heightScale);
    await instance.setParameterFloat('minSteps', minSteps);
    await instance.setParameterFloat('maxSteps', steps);
    final asset = await viewer.createGeometry(
      Geometry(
        Float32List.fromList([-0.5, -0.5, 0, 0.5, -0.5, 0, 0.5, 0.5, 0, -0.5, 0.5, 0]),
        [0, 1, 2, 0, 2, 3],
        normals: Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]),
        uvs: Float32List.fromList([centerU - 0.5, 0, centerU + 0.5, 0, centerU + 0.5, 1, centerU - 0.5, 1]),
      ),
      materialInstances: [instance],
    );
    final buffers = await helper.capture(viewer.view, null);
    final bytes = buffers[viewer.view]!;
    final floats = bytes.buffer.asFloat32List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 4);
    final center = (16 * 33 + 16) * 4;
    final color = floats.sublist(center, center + 3);
    await viewer.destroyAsset(asset);
    return color;
  }

  Future<void> dispose() async {
    await instance.destroy();
    await material.destroy();
    await albedo.dispose();
    await height.dispose();
    await normal.dispose();
    await sampler.dispose();
  }
}

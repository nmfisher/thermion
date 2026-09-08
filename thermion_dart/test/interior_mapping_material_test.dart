import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

void main() async {
  final helper = TestHelper('interior_mapping');
  await helper.setup();

  test('room rays hit the back, side, floor and ceiling planes correctly', () async {
    await helper.withViewer((viewer) async {
      final fixture = await _InteriorFixture.create(helper, viewer);
      for (final probe in [
        (0.0, 0.0, [0.5, 0.5, 1.0]),
        (0.1, 0.0, [0.3, 0.5, 1.0]),
        (1.0, 0.0, [0.0, 0.5, 0.25]),
        (-1.0, 0.0, [1.0, 0.5, 0.25]),
        (0.0, 1.0, [0.5, 0.0, 0.25]),
        (0.0, -1.0, [0.5, 1.0, 0.25]),
        (2.0, 1.0, [0.0, 0.25, 0.125]),
        (100.0, 0.0, [0.0, 0.5, 0.0025]),
      ]) {
        await fixture.setView(probe.$1, probe.$2);
        await fixture.expectHit(probe.$3, reason: 'view slopes ${probe.$1}, ${probe.$2}');
      }
      await fixture.dispose();
    }, viewportDimensions: (width: 33, height: 33));
  });

  test('room dimensions, repeated UVs and flat mode preserve the expected projection', () async {
    await helper.withViewer((viewer) async {
      final fixture = await _InteriorFixture.create(helper, viewer);
      await fixture.setView(0.1, 0);
      for (final uv in [Vector2(10.5, 12.5), Vector2(-10.5, -12.5)]) {
        fixture.centerUV = uv;
        await fixture.expectHit([0.3, 0.5, 1], reason: 'repeated UV $uv');
      }
      await fixture.instance.setParameterFloat('parallaxStrength', 0);
      await fixture.expectHit([0.5, 0.5, 1], reason: 'flat reference mode');
      await fixture.instance.setParameterFloat('parallaxStrength', 1);
      await fixture.instance.setParameterFloat3('roomSize', 2, 3, 1);
      await fixture.setView(0.2, 0.3);
      await fixture.expectHit([0.4, 0.4, 1], reason: 'non-square room dimensions');
      await fixture.instance.setParameterFloat2('roomGrid', 4, 3);
      fixture.centerUV = Vector2(0.375, 0.5); // center of cell (1, 1)
      await fixture.expectHit([0.4, 0.4, 1], reason: 'room grid scaling');
      await fixture.dispose();
    }, viewportDimensions: (width: 33, height: 33));
  });

  test('rotating the facade and camera together preserves the room intersection', () async {
    await helper.withViewer((viewer) async {
      final fixture = await _InteriorFixture.create(helper, viewer);
      fixture.transform = Matrix4.rotationY(math.pi / 3);
      await fixture.setView(0.1, 0.1);
      await fixture.expectHit([0.3, 0.3, 1], reason: 'rotated tangent frame');
      await fixture.dispose();
    }, viewportDimensions: (width: 33, height: 33));
  });

  test('glass Fresnel strengthens toward grazing angles and blends the room energy', () async {
    await helper.withViewer((viewer) async {
      final fixture = await _InteriorFixture.create(helper, viewer);
      fixture.centerUV = Vector2(0.35, 0.5); // clear of the mullion and frame
      await fixture.instance.setParameterInt('debugView', 0);
      await fixture.instance.setParameterFloat('interiorBrightness', 0);
      await fixture.instance.setParameterFloat('glassStrength', 1);
      await fixture.setReflectionFaces(List.filled(6, [0.8, 0.4, 0.2]));
      for (final probe in [(0.0, 0.04), (math.sqrt(3), 0.07), (math.sqrt(99), 0.6068704)]) {
        await fixture.setView(probe.$1, 0);
        await fixture.expectColor([
          0.8 * probe.$2,
          0.4 * probe.$2,
          0.2 * probe.$2,
        ], reason: 'Fresnel at view slope ${probe.$1}');
      }
      await fixture.setView(0, 0);
      await fixture.instance.setParameterFloat('interiorBrightness', 1);
      await fixture.instance.setParameterFloat('glassStrength', 0);
      final open = await fixture.render(fixture.instance);
      await fixture.instance.setParameterFloat('glassReflectance', 0.25);
      await fixture.instance.setParameterFloat3('glassTint', 0.8, 0.9, 1);
      await fixture.instance.setParameterFloat('glassStrength', 1);
      await fixture.expectColor([
        open[0] * 0.8 * 0.75 + 0.8 * 0.25,
        open[1] * 0.9 * 0.75 + 0.4 * 0.25,
        open[2] * 0.75 + 0.2 * 0.25,
      ], reason: 'reflection replaces transmitted energy');
      await fixture.instance.setParameterFloat('glassStrength', 0);
      await fixture.expectColor(open.sublist(0, 3), reason: 'disabled glass restores the room');
      await fixture.dispose();
    }, viewportDimensions: (width: 33, height: 33));
  });

  test('glass samples the world reflection direction and leaves frames opaque', () async {
    await helper.withViewer((viewer) async {
      final fixture = await _InteriorFixture.create(helper, viewer);
      fixture.centerUV = Vector2(0.35, 0.5);
      await fixture.instance.setParameterInt('debugView', 0);
      await fixture.instance.setParameterFloat('glassStrength', 1);
      await fixture.instance.setParameterFloat('glassReflectance', 1);
      await fixture.setReflectionFaces([
        [1, 0, 0],
        [0, 1, 0],
        [0, 0, 1],
        [1, 1, 0],
        [1, 0, 1],
        [0, 1, 1],
      ]);
      await fixture.setView(0, 0);
      await fixture.expectColor([1, 0, 1], reason: '+Z environment head-on');
      await fixture.setView(2, 0);
      await fixture.expectColor([0, 1, 0], reason: '-X environment from the right');
      await fixture.setView(0, 2);
      await fixture.expectColor([1, 1, 0], reason: '-Y environment from above');
      fixture.transform = Matrix4.rotationY(math.pi / 2);
      await fixture.setView(0, 0);
      await fixture.expectColor([1, 0, 0], reason: 'rotated facade reflects world +X');
      for (final uv in [Vector2(0.02, 0.5), Vector2(0.5, 0.5)]) {
        fixture.centerUV = uv;
        await fixture.instance.setParameterFloat('glassStrength', 0);
        final opaque = await fixture.render(fixture.instance);
        await fixture.instance.setParameterFloat('glassStrength', 1);
        await fixture.expectColor(opaque.sublist(0, 3), reason: 'facade/mullion at $uv unchanged');
      }
      await fixture.dispose();
    }, viewportDimensions: (width: 33, height: 33));
  });
}

class _InteriorFixture {
  final TestHelper helper;
  final ThermionViewer viewer;
  final Material material;
  final MaterialInstance instance;
  final MaterialInstance reference;
  final Texture reflection;
  final TextureSampler reflectionSampler;
  Vector2 centerUV = Vector2(0.5, 0.5);
  Matrix4 transform = Matrix4.identity();

  _InteriorFixture(
    this.helper,
    this.viewer,
    this.material,
    this.instance,
    this.reference,
    this.reflection,
    this.reflectionSampler,
  );

  static Future<_InteriorFixture> create(TestHelper helper, ThermionViewer viewer) async {
    final app = FilamentApp.instance!;
    await app.renderManager.setRenderable(viewer.view, false);
    final material = await app.createMaterial(await loadResourceBytes('${helper.assetsDir}/interior_mapping.filamat'));
    final instance = await material.createInstance();
    await instance.setParameterFloat2('roomGrid', 1, 1);
    await instance.setParameterFloat3('roomSize', 1, 1, 2);
    await instance.setParameterFloat('parallaxStrength', 1);
    await instance.setParameterFloat('frameWidth', 0.08);
    await instance.setParameterFloat('interiorBrightness', 1);
    final reflection = await app.createTexture(
      1,
      1,
      textureSamplerType: TextureSamplerType.SAMPLER_CUBEMAP,
      textureFormat: TextureFormat.RGBA32F,
    );
    final reflectionSampler = await app.createTextureSampler(
      minFilter: TextureMinFilter.NEAREST,
      magFilter: TextureMagFilter.NEAREST,
    );
    await instance.setParameterTexture('reflectionMap', reflection, reflectionSampler);
    await instance.setParameterFloat('glassStrength', 0);
    await instance.setParameterFloat('glassReflectance', 0.04);
    await instance.setParameterFloat3('glassTint', 1, 1, 1);
    await instance.setParameterFloat('reflectionBrightness', 1);
    await instance.setParameterInt('debugView', 1);
    final reference = await app.createUnlitMaterialInstance();
    await reference.setParameterInt('baseColorIndex', -1);
    final fixture = _InteriorFixture(helper, viewer, material, instance, reference, reflection, reflectionSampler);
    await fixture.setReflectionFaces(List.filled(6, [0.0, 0.0, 0.0]));
    return fixture;
  }

  Future<void> setReflectionFaces(List<List<double>> colors) async {
    for (var face = 0; face < 6; face++) {
      await reflection.setImage(
        0,
        Float32List.fromList([...colors[face], 1]).asUint8List(),
        1,
        1,
        PixelDataFormat.RGBA,
        PixelDataType.FLOAT,
        zOffset: face,
      );
    }
  }

  Future<void> setView(double x, double y) async {
    final camera = await viewer.getActiveCamera();
    await camera.lookAt(transform.transformed3(Vector3(x, y, 1)), focus: Vector3.zero());
    await camera.setProjection(Projection.Orthographic, -0.0001, 0.0001, -0.0001, 0.0001, 0.1, 200);
  }

  Future<void> expectHit(List<double> hit, {required String reason}) async {
    await expectColor(hit, reason: reason);
  }

  Future<void> expectColor(List<double> color, {required String reason}) async {
    await reference.setParameterFloat4('baseColorFactor', color[0], color[1], color[2], 1);
    final actual = await render(instance);
    final expected = await render(reference);
    expect(actual[3], greaterThan(0.99), reason: 'visible facade: $reason');
    for (var c = 0; c < 3; c++) {
      expect(actual[c].isFinite, isTrue, reason: reason);
      // The swapchain quantizes to RGBA8; interpolation can round exact
      // half-byte values to the adjacent code compared with a uniform color.
      expect(actual[c], closeTo(expected[c], 1 / 255 + 1e-5), reason: '$reason, channel $c');
    }
  }

  Future<List<double>> render(MaterialInstance instance) async {
    final u = centerUV.x, v = centerUV.y;
    final asset = await viewer.createGeometry(
      Geometry(
        Float32List.fromList([-0.5, -0.5, 0, 0.5, -0.5, 0, 0.5, 0.5, 0, -0.5, 0.5, 0]),
        [0, 1, 2, 0, 2, 3],
        normals: Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]),
        uvs: Float32List.fromList([u - 0.5, v - 0.5, u + 0.5, v - 0.5, u + 0.5, v + 0.5, u - 0.5, v + 0.5]),
      ),
      materialInstances: [instance],
    );
    await asset.setTransform(transform);
    final bytes = (await helper.capture(viewer.view, null))[viewer.view]!;
    final pixels = bytes.buffer.asFloat32List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 4);
    final color = pixels.sublist((16 * 33 + 16) * 4, (16 * 33 + 16) * 4 + 4);
    await viewer.destroyAsset(asset);
    return color;
  }

  Future<void> dispose() async {
    await instance.destroy();
    await material.destroy();
    await reference.destroy();
    await reflection.dispose();
    await reflectionSampler.dispose();
  }
}

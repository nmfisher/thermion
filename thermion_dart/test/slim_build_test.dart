import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

/// Slim-build test (docs/feature-optout-proposal.md §5.7 criterion 4, review
/// decision D1).
///
/// On a `features.gltf: false` build the gltfio archives are not linked:
/// procedural geometry must still create, instance, render and destroy
/// through the shared TSceneAsset entry points (only the glTF branches are
/// stubbed), using the precompiled unlit fallback in place of the gltfio
/// ubershader, and the glTF-only Dart surface must fail with
/// [UnsupportedError] instead of returning garbage.
///
/// Every test is skipped on a default (gltf enabled) build. To run it, make
/// the package itself a slim consumer by rewriting the `hooks:` block of
/// pubspec.yaml to
///
/// ```yaml
/// hooks:
///   user_defines:
///     thermion_dart:
///       features:
///         gltf: false
/// ```
///
/// (the same technique the CI JS-callback job uses for `skip_native_build`)
/// and then `xvfb-run dart test test/slim_build_test.dart`.
void main() async {
  final testHelper = TestHelper("slim_build");
  await testHelper.setup();

  final app = FilamentApp.instance!;
  final slim = !app.supports(ThermionFeature.gltf);
  final skip = slim ? false : 'not a slim build: features.gltf is enabled';
  const viewportSize = 512;

  Float32List asFloats(Uint8List bytes) =>
      bytes.buffer.asFloat32List(bytes.offsetInBytes, viewportSize * viewportSize * 4);

  /// The clear colour (kBlue) as read back from a FLOAT RGBA capture.
  bool isBackground(Float32List pixels, int x, int y) {
    final i = (y * viewportSize + x) * 4;
    return pixels[i] < 0.1 && pixels[i + 1] < 0.1 && pixels[i + 2] > 0.9;
  }

  test('supports() reports the compile-time opt-outs', () {
    expect(app.supports(ThermionFeature.gltf), isFalse);
    // The other switches are independent of gltf; runtime materials keeps
    // its own probe and the two must agree.
    expect(app.supports(ThermionFeature.runtimeMaterials), app.runtimeMaterialsSupported);
    expect(ThermionFeature.values, hasLength(4));
  }, skip: skip);

  test('glTF-only Dart APIs throw UnsupportedError naming the key', () async {
    await testHelper.withViewer((viewer) async {
      await expectLater(
        viewer.loadGltf("file://${testHelper.assetsDir}/cube.glb"),
        throwsA(isA<UnsupportedError>().having((e) => e.message, 'message', contains('features.gltf'))),
      );
      await expectLater(app.loadGltfFromBuffer(Uint8List(16)), throwsA(isA<UnsupportedError>()));
      await expectLater(
        app.createUbershaderMaterialInstance(unlit: true),
        throwsA(
          isA<UnsupportedError>().having((e) => e.message, 'message', contains('createUbershaderMaterialInstance')),
        ),
      );
      await expectLater(app.createUbershaderMaterial(unlit: true), throwsA(isA<UnsupportedError>()));
      final geometry = await viewer.createGeometry(GeometryUtils.cube());
      // The synchronous animation getters throw before returning.
      expect(() => app.animationManager.getGltfAnimationCount(geometry), throwsA(isA<UnsupportedError>()));
      await expectLater(geometry.releaseSourceData(), throwsA(isA<UnsupportedError>()));
      await viewer.destroyAsset(geometry);
    }, bg: kBlue);
  }, skip: skip);

  test('procedural geometry creates, instances, renders and destroys', () async {
    await ViewerBuilder(
      testHelper,
    ).setBackgroundColor(kBlue).setCameraLookAt(Vector3(0, 0, 4), focus: Vector3.zero()).execute((result) async {
      final viewer = result.viewer;

      // 1. create — no explicit material: goes through the precompiled unlit
      //    fallback (createUnlitMaterialInstance) instead of the ubershader.
      final asset = await viewer.createGeometry(GeometryUtils.cube());
      expect(asset.type, SceneAssetType.geometry);
      expect(asset.isInstance, isFalse);
      expect(await asset.getInstanceCount(), 0);
      final materialInstance = await asset.getMaterialInstanceAt();
      expect(materialInstance, isNotNull);

      // Shared entity / bounding-box access stays live (Pattern B, D1).
      final entity = asset.entity;
      expect(entity, isNot(0));
      final bbox = await asset.getBoundingBox();
      expect(bbox.min.x, lessThan(bbox.max.x));
      expect(bbox.min.y, lessThan(bbox.max.y));
      expect(bbox.min.z, lessThan(bbox.max.z));
      expect((bbox.max.x - bbox.min.x).abs(), closeTo(2.0, 0.01), reason: 'GeometryUtils.cube is a 2x2x2 cube');

      // 2. render — the cube must be visible against the blue background.
      await viewer.addToScene(asset);
      final pixels = asFloats((await testHelper.capture(viewer.view, "slim_cube"))[viewer.view]!);
      final centre = (viewportSize ~/ 2, viewportSize ~/ 2);
      expect(isBackground(pixels, centre.$1, centre.$2), isFalse, reason: 'cube covers the centre pixel');
      expect(isBackground(pixels, 8, 8), isTrue, reason: 'corner stays background');
      expect(isBackground(pixels, viewportSize - 9, viewportSize - 9), isTrue);

      // 3. instance — the glTF-only instancing branches are stubbed, but
      //    SceneAsset_createInstance/getInstance are shared and stay live.
      final instance = await asset.createInstance();
      expect(instance.isInstance, isTrue);
      expect(instance.type, SceneAssetType.geometry);
      expect(await asset.getInstanceCount(), 1);
      final instances = await asset.getInstances();
      expect(instances, hasLength(1));
      expect(instances.single.entity, instance.entity);
      expect(instance.entity, isNot(asset.entity));
      expect(await instance.getBoundingBox(), isNotNull);
      final instanceBox = await instance.getBoundingBox();
      expect(instanceBox.max.x - instanceBox.min.x, closeTo(2.0, 0.01));
      await viewer.addToScene(instance);
      await instance.setTransform(Matrix4.translation(Vector3(2.5, 0, 0)));
      final withInstance = asFloats((await testHelper.capture(viewer.view, "slim_cube_instance"))[viewer.view]!);
      // Both the original (centre) and the translated instance (right of
      // centre) are drawn.
      expect(isBackground(withInstance, centre.$1, centre.$2), isFalse);
      expect(isBackground(withInstance, centre.$1 + 140, centre.$2), isFalse, reason: 'instance visible');

      // 4. destroy — the instance is removed through its owner, then the asset.
      await viewer.destroyAsset(instance);
      expect(await asset.getInstanceCount(), 0);
      await viewer.destroyAsset(asset);
      final destroyed = asFloats((await testHelper.capture(viewer.view, "slim_cube_destroyed"))[viewer.view]!);
      expect(isBackground(destroyed, centre.$1, centre.$2), isTrue, reason: 'nothing left on screen');
    });
  }, skip: skip);

  test('createUnlitMaterialInstance works for explicit procedural materials', () async {
    await testHelper.withViewer((viewer) async {
      final material = await app.createUnlitMaterialInstance();
      await material.setParameterFloat4("baseColorFactor", 1, 0, 0, 1);
      final asset = await viewer.createGeometry(GeometryUtils.cube(), materialInstances: [material]);
      expect(await asset.getMaterialInstanceAt(), isNotNull);
      await viewer.destroyAsset(asset);
      await material.destroy();
    }, bg: kBlue);
  }, skip: skip);
}

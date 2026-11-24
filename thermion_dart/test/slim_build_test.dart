import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

/// Slim-build test for the compile-time feature opt-outs.
///
/// On a `features.gltf: false` build the gltfio archives are not linked:
/// procedural geometry must still create, instance, render and destroy
/// through the shared TSceneAsset entry points (only the glTF branches are
/// stubbed), `createUnlitMaterialInstance` must serve the precompiled unlit
/// fallback with the ubershader's semantics, and the glTF-only Dart surface
/// must fail with [UnsupportedError] instead of returning garbage.
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
      // parseGltf is gltf-gated too: its cgltf parser ships inside gltfio and
      // GltfParser_parseBuffer is a plain failure stub in this build.
      await expectLater(
        app.parseGltf(Uint8List(16)),
        throwsA(isA<UnsupportedError>().having((e) => e.message, 'message', contains('parseGltf'))),
      );
      final geometry = await viewer.createGeometry(GeometryUtils.cube());
      // The synchronous animation getters throw before returning.
      expect(() => app.animationManager.getGltfAnimationCount(geometry), throwsA(isA<UnsupportedError>()));
      await expectLater(geometry.releaseSourceData(), throwsA(isA<UnsupportedError>()));
      // Asset-level glTF surfaces report the disabled feature first, even on
      // a procedural asset (which would otherwise look like "no animations").
      await expectLater(
        geometry.getGltfAnimationNames(),
        throwsA(isA<UnsupportedError>().having((e) => e.message, 'message', contains('features.gltf'))),
      );
      await expectLater(
        geometry.getGltfAnimationDuration(0),
        throwsA(isA<UnsupportedError>().having((e) => e.message, 'message', contains('features.gltf'))),
      );
      await expectLater(
        geometry.getBones(),
        throwsA(isA<UnsupportedError>().having((e) => e.message, 'message', contains('features.gltf'))),
      );
      await expectLater(
        geometry.getBoneNames(),
        throwsA(isA<UnsupportedError>().having((e) => e.message, 'message', contains('getBoneNames'))),
      );
      await viewer.destroyAsset(geometry);
    }, bg: kBlue);
  }, skip: skip);

  test('procedural geometry creates, instances, renders and destroys', () async {
    await ViewerBuilder(
      testHelper,
    ).setBackgroundColor(kBlue).setCameraLookAt(Vector3(0, 0, 4), focus: Vector3.zero()).execute((result) async {
      final viewer = result.viewer;

      // 1. create — no explicit material. GeometrySceneAsset passes
      //    materialInstanceCount = 0 to RenderableManager, so Filament's
      //    engine default material (80% white, lit) is used; the precompiled
      //    unlit fallback is only reached through createUnlitMaterialInstance
      //    (next test).
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

  test('createUnlitMaterialInstance has the ubershader unlit semantics', () async {
    // createUnlitMaterialInstance() requests (unlit: true, hasVertexColors:
    // false) and the gltfio UbershaderProvider that serves it in a default
    // build starts baseColorFactor at opaque white. The precompiled fallback
    // must behave the same: a .mat uniform parameter is zero-initialised, so
    // the Dart built-in branch sets baseColorFactor to white on every
    // instance, and the material neither requires nor multiplies vertex
    // colours (a Geometry built with createDummyColors: false leaves the
    // COLOR buffer at zero).
    await ViewerBuilder(testHelper)
        .setBackgroundColor(kBlue)
        .setCameraLookAt(Vector3(0, 0, 4), focus: Vector3.zero())
        .setToneMapping(await ToneMapper.linear(app))
        .execute((result) async {
          final viewer = result.viewer;
          const centre = (viewportSize ~/ 2, viewportSize ~/ 2);

          (double, double, double) rgb(Float32List pixels, int x, int y) {
            final i = (y * viewportSize + x) * 4;
            return (pixels[i], pixels[i + 1], pixels[i + 2]);
          }

          bool isWhite((double, double, double) c) => c.$1 > 0.9 && c.$2 > 0.9 && c.$3 > 0.9;
          bool isRed((double, double, double) c) => c.$1 > 0.9 && c.$2 < 0.1 && c.$3 < 0.1;

          /// Adds a cube with [material] and returns its centre pixel colour.
          Future<(double, double, double)> renderCentre(
            Geometry geometry,
            MaterialInstance material,
            String name,
          ) async {
            final asset = await viewer.createGeometry(geometry, materialInstances: [material]);
            await viewer.addToScene(asset);
            try {
              final pixels = asFloats((await testHelper.capture(viewer.view, name))[viewer.view]!);
              expect(isBackground(pixels, 8, 8), isTrue, reason: 'corner stays background');
              return rgb(pixels, centre.$1, centre.$2);
            } finally {
              await viewer.destroyAsset(asset);
            }
          }

          // 1. Default baseColorFactor: opaque white, not transparent black.
          final material = await app.createUnlitMaterialInstance();
          expect(
            await renderCentre(GeometryUtils.cube(), material, "slim_unlit_default"),
            predicate(isWhite),
            reason: 'default baseColorFactor is opaque white',
          );
          await material.destroy();

          // 2. Geometry without vertex colours (COLOR declared, never
          //    uploaded): still white — the fallback must not read it.
          final cube = GeometryUtils.cube();
          final uncoloured = Geometry(
            cube.vertices,
            cube.indices,
            normals: cube.normals,
            uvs: cube.uvs,
            createDummyColors: false,
          );
          expect(uncoloured.colors, isEmpty);
          final material2 = await app.createUnlitMaterialInstance();
          expect(
            await renderCentre(uncoloured, material2, "slim_unlit_no_colors"),
            predicate(isWhite),
            reason: 'a zero-filled colour buffer must not tint the material',
          );
          await material2.destroy();

          // 3. Geometry WITH non-white vertex colours: ignored as well
          //    (hasVertexColors: false), so the result is still white.
          // One green RGBA colour per vertex.
          final green = Float32List(cube.vertices.length ~/ 3 * 4);
          for (var v = 0; v < green.length; v += 4) {
            green.setRange(v, v + 4, [0, 1, 0, 1]);
          }
          final tinted = Geometry(cube.vertices, cube.indices, normals: cube.normals, uvs: cube.uvs, colors: green);
          final material3 = await app.createUnlitMaterialInstance();
          expect(
            await renderCentre(tinted, material3, "slim_unlit_tinted_vertices"),
            predicate(isWhite),
            reason: 'vertex colours are ignored',
          );
          await material3.destroy();

          // 4. An explicit baseColorFactor on the instance is applied.
          final red = await app.createUnlitMaterialInstance();
          await red.setParameterFloat4("baseColorFactor", 1, 0, 0, 1);
          expect(
            await renderCentre(GeometryUtils.cube(), red, "slim_unlit_red"),
            predicate(isRed),
            reason: 'baseColorFactor set by the caller is used',
          );
          await red.destroy();
        });
  }, skip: skip);

  test('entity-keyed morph animation works without gltf', () async {
    // Custom morph animation without glTF goes through
    // AnimationManager.setMorphAnimation/clearMorphAnimation: the entity-keyed
    // morph buffer is gltfio-free and compiled into every build. The
    // asset-level setMorphAnimationData is NOT the slim-build API — it
    // matches morph targets by their glTF names (getMorphTargetName*), which
    // need features.gltf.
    await testHelper.withViewer((viewer) async {
      final geometry = await viewer.createGeometry(GeometryUtils.cube());
      final entity = geometry.entity;
      final animationManager = app.animationManager;

      // The buffer APIs accept an entity directly, without any glTF asset
      // or morph target names. setMorphAnimation installs the morph
      // component itself.
      expect(animationManager.setMorphAnimation(entity, [0.0, 1.0], [0], 1, 2, 1000.0), isTrue);
      await animationManager.update(1);
      await animationManager.update(500_000_000);
      expect(animationManager.clearMorphAnimation(entity), isTrue);
      animationManager.removeMorphAnimationComponent(entity);

      await viewer.destroyAsset(geometry);
    }, bg: kBlue);
  }, skip: skip);

  test('createBuiltInMaterial(unlitFallback) points at createUnlitMaterialInstance', () async {
    // unlit_fallback is hook-managed, not a materials.* key: even in this
    // slim build (where the package IS linked) it must not be requested
    // directly. The error names the public API, not a materials setting
    // that does not exist.
    await expectLater(
      app.createBuiltInMaterial(BuiltInMaterial.unlitFallback),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('createUnlitMaterialInstance'))),
    );
  }, skip: skip);
}

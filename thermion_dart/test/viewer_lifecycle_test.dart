@Timeout(const Duration(seconds: 600))
import 'dart:async';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

// Minimal isolation repro: does PURE viewer create/destroy (no loadGltf,
// loadIbl, loadSkybox, no captures) accumulate stack depth across iterations
// so it eventually overflows? If yes, the per-test leak is in
// ViewerBuilder.execute() / createViewer / destroySwapChain. If no, the leak
// is upstream (assets/materials/IBL/skybox/etc.).
void main() async {
  final testHelper = TestHelper("viewer_lifecycle");

  await testHelper.setup();
  final app = FilamentApp.instance!;
  final gltfData = await app.loadResource('file://${testHelper.assetsDir}/cube.glb');

  Future<ThermionAsset> showBoundingBox(ThermionViewer viewer, ThermionAsset asset) async {
    final box = await viewer.showBoundingBox(asset) as ThermionAsset;
    final material = await box.getMaterialInstanceAt();
    addTearDown(() async {
      if (!box.isDestroyed) {
        await app.destroyAsset(box);
      }
      // The viewer does not destroy this material yet (tpf-kx2v).
      // Release it after the box.
      await material.destroy();
    });
    return box;
  }

  test('10 viewer lifecycles with capture', () async {
    for (var i = 0; i < 10; i++) {
      print('[iter] $i start');
      await ViewerBuilder(testHelper).execute((result) async {
        await testHelper.capture(result.viewer.view, null);
      });
      print('[iter] $i done');
    }
  });

  test('viewer disposal releases loaded scene resources and is idempotent', () async {
    await ViewerBuilder(testHelper)
        .setRenderTargetEnabled(true)
        .addDirectLight(DirectLight.sun(direction: Vector3(0.7, -1, -0.8).normalized()))
        .execute((result) async {
          await result.viewer.loadGltf('file://${testHelper.assetsDir}/cube.glb');
          await result.viewer.loadSkybox('file://${testHelper.assetsDir}/default_env_skybox.ktx');
          await result.viewer.loadIbl('file://${testHelper.assetsDir}/default_env_ibl.ktx');
          await result.viewer.createCamera();

          expect(result.viewer.getCameraCount(), 2);

          await result.viewer.dispose();
          await result.viewer.dispose();

          expect(result.viewer.getCameraCount(), 0);
        });
  });

  test('destroyAsset while destroyAssets is running', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final assets = [for (var i = 0; i < 3; i++) await result.viewer.createGeometry(GeometryUtils.cube())];

      // destroyAssets suspends inside its loop, so these calls run while it
      // is still iterating. Each asset must only be destroyed once.
      final destroyAll = result.viewer.destroyAssets();
      await Future.wait([destroyAll, for (final asset in assets) result.viewer.destroyAsset(asset)]);

      // Destroying an asset that was already destroyed is a no-op.
      await result.viewer.destroyAsset(assets.first);
    });
  });

  for (final destroyAll in [true, false]) {
    final operation = destroyAll ? 'destroyAssets' : 'destroyAsset(owner)';
    test('$operation before queued instance cleanup is safe', () async {
      await ViewerBuilder(testHelper).execute((result) async {
        final viewer = result.viewer;
        final asset = await viewer.createGeometry(GeometryUtils.cube());
        final instance = await asset.createInstance();
        final alias = (await asset.getInstances()).single;
        await viewer.addToScene(instance);
        final entities = [asset.entity, instance.entity];

        // The queued instance wrappers refer to native memory freed by the
        // owning asset's destruction. Neither wrapper may reach native code.
        final destroyOwner = destroyAll ? viewer.destroyAssets() : viewer.destroyAsset(asset);
        await Future.wait([destroyOwner, viewer.destroyAsset(instance), viewer.destroyAsset(alias)]);
        await viewer.destroyAsset(instance);

        for (final entity in entities) {
          expect(FilamentApp.instance!.renderableManager.hasComponent(entity), isFalse);
        }
      });
    });
  }

  test('app-created geometry stays app-owned when added to the viewer', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final app = FilamentApp.instance!;
      final asset = await app.createGeometry(GeometryUtils.cube());
      final instance = await asset.createInstance();
      final entity = asset.entity;
      final instanceEntity = instance.entity;
      await result.viewer.addToScene(asset);
      await result.viewer.addToScene(instance);
      final box = await showBoundingBox(result.viewer, asset);
      try {
        await result.viewer.destroyAsset(asset);
        await result.viewer.destroyAsset(instance);
        await result.viewer.destroyAssets();
        expect(app.renderableManager.hasComponent(entity), isTrue);
        expect(app.renderableManager.hasComponent(instanceEntity), isTrue);

        await result.viewer.removeFromScene(instance);
        await result.viewer.removeFromScene(asset);
        await result.viewer.dispose();
        expect(box.isDestroyed, isTrue);
        expect(app.renderableManager.hasComponent(box.entity), isFalse);

        // Viewer cleanup after teardown cannot act on app-owned resources.
        await result.viewer.destroyAsset(asset);
        await result.viewer.destroyAsset(instance);
        await result.viewer.removeFromScene(asset);
        expect(app.renderableManager.hasComponent(entity), isTrue);
        expect(app.renderableManager.hasComponent(instanceEntity), isTrue);
      } finally {
        await app.destroyAsset(asset);
      }
      expect(app.renderableManager.hasComponent(entity), isFalse);
      expect(app.renderableManager.hasComponent(instanceEntity), isFalse);
    });
  });

  test('remove and destroy assets and lights while the viewer is disposed', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final viewer = result.viewer;
      final assets = [for (var i = 0; i < 3; i++) await viewer.createGeometry(GeometryUtils.cube())];
      final light = await viewer.addDirectLight(DirectLight.point());
      final entities = assets.map((asset) => asset.entity).toList();

      // App code often releases its own assets and lights while the viewer is
      // being disposed (e.g. in a parent widget's dispose()), or after.
      Future release() => Future.wait([
        for (final asset in assets) viewer.removeFromScene(asset).then((_) => viewer.destroyAsset(asset)),
        viewer.removeLight(light),
      ]);
      await Future.wait([viewer.dispose(), release()]);
      await release();
      for (final entity in entities) {
        expect(FilamentApp.instance!.renderableManager.hasComponent(entity), isFalse);
      }
      expect(FilamentApp.instance!.lightManager.hasComponent(light), isFalse);
    });
  });

  for (final gltf in [false, true]) {
    final kind = gltf ? 'glTF' : 'geometry';
    Future<ThermionAsset> createAsset(ThermionViewer viewer) =>
        gltf ? viewer.loadGltfFromBuffer(gltfData) : viewer.createGeometry(GeometryUtils.cube());

    for (final dispose in [false, true]) {
      final cleanup = dispose ? 'disposal' : 'asset cleanup';
      test('$kind $cleanup destroys bounding boxes after external owner destruction', () async {
        await ViewerBuilder(testHelper).execute((result) async {
          final viewer = result.viewer;
          final owner = await createAsset(viewer);
          final instance = await owner.createInstance();
          final boxes = [await showBoundingBox(viewer, owner), await showBoundingBox(viewer, instance)];

          await app.destroyAsset(owner);
          if (dispose) {
            await viewer.dispose();
          } else {
            await viewer.destroyAsset(owner);
          }

          for (final box in boxes) {
            expect(box.isDestroyed, isTrue);
            expect(app.renderableManager.hasComponent(box.entity), isFalse);
            expect(app.transformManager.hasComponent(box.entity), isFalse);
          }
        });
      });
    }

    test('$kind viewer cleanup skips an owner destroyed through FilamentApp', () async {
      await ViewerBuilder(testHelper).execute((result) async {
        final viewer = result.viewer;
        final owner = await createAsset(viewer);
        final instance = await owner.createInstance();
        final alias = (await owner.getInstances()).last;
        await viewer.addToScene(instance);

        final destruction = app.destroyAsset(owner);
        expect(owner.isDestroyed, isTrue);
        expect(instance.isDestroyed, isTrue);
        await Future.wait([
          destruction,
          viewer.removeFromScene(instance),
          viewer.removeFromScene(owner),
          viewer.destroyAsset(alias),
          viewer.destroyAsset(owner),
          viewer.destroyAssets(),
        ]);
        await viewer.dispose();

        expect(app.transformManager.hasComponent(owner.entity), isFalse);
        expect(app.transformManager.hasComponent(instance.entity), isFalse);
      });
    });

    test('$kind viewer cleanup skips an instance destroyed through FilamentApp', () async {
      await ViewerBuilder(testHelper).execute((result) async {
        final viewer = result.viewer;
        final owner = await createAsset(viewer);
        final instance = await owner.createInstance();
        final alias = (await owner.getInstances()).last;
        await viewer.addToScene(instance);
        final ownerBox = await showBoundingBox(viewer, owner);
        final instanceBox = await showBoundingBox(viewer, instance);

        final destruction = app.destroyAsset(instance);
        expect(instance.isDestroyed, isTrue);
        expect(owner.isDestroyed, isFalse);
        await Future.wait([destruction, viewer.removeFromScene(instance), viewer.destroyAsset(alias)]);
        expect(instanceBox.isDestroyed, isTrue);
        expect(ownerBox.isDestroyed, isFalse);
        await viewer.destroyAssets();
        expect(ownerBox.isDestroyed, isTrue);
        await viewer.dispose();

        expect(owner.isDestroyed, isTrue);
        expect(app.transformManager.hasComponent(owner.entity), isFalse);
        expect(app.transformManager.hasComponent(instance.entity), isFalse);
      });
    });
  }

  test('disposal waits for accepted asset and light creation', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final viewer = result.viewer;
      final app = FilamentApp.instance!;
      final gltfData = await app.loadResource('file://${testHelper.assetsDir}/cube.glb');

      // None of these operations has completed when disposal starts. Their
      // resources must still be registered and released before teardown ends.
      final geometryCreated = viewer.createGeometry(GeometryUtils.cube());
      final gltfLoaded = viewer.loadGltfFromBuffer(gltfData);
      final lightAdded = viewer.addDirectLight(DirectLight.point());
      final disposal = viewer.dispose();

      final geometry = await geometryCreated;
      final gltf = await gltfLoaded;
      final light = await lightAdded;
      await disposal.timeout(const Duration(seconds: 10));

      expect(app.renderableManager.hasComponent(geometry.entity), isFalse);
      expect(app.transformManager.hasComponent(gltf.entity), isFalse);
      expect(app.lightManager.hasComponent(light), isFalse);
    });
  });

  test('public cleanup is a no-op during teardown and after disposal', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final viewer = result.viewer;
      final asset = await viewer.createGeometry(GeometryUtils.cube());
      final instance = await asset.createInstance();
      final light = await viewer.addDirectLight(DirectLight.point());
      final teardownReached = Completer<void>();
      final continueTeardown = Completer<void>();

      Future<void> release() async {
        await viewer.removeFromScene(instance);
        await viewer.destroyAsset(instance);
        await viewer.destroyAsset(asset);
        await viewer.destroyAssets();
        await viewer.removeLight(light);
        await viewer.destroyLights();
        await viewer.clearBackgroundImage(destroy: true);
      }

      viewer.onDispose(() async {
        // Awaiting public cleanup inside teardown must not enqueue work behind
        // the operation that is currently waiting for this callback.
        await release().timeout(const Duration(seconds: 10));
        teardownReached.complete();
        await continueTeardown.future.timeout(const Duration(seconds: 10));
      });

      final disposal = viewer.dispose();
      try {
        await teardownReached.future.timeout(const Duration(seconds: 10));
        await release().timeout(const Duration(seconds: 10));
        expect(() => viewer.createGeometry(GeometryUtils.cube()), throwsA(isA<ViewerDisposedException>()));
        expect(() => viewer.loadGltfFromBuffer(Uint8List(0)), throwsA(isA<ViewerDisposedException>()));
        expect(() => viewer.addDirectLight(DirectLight.point()), throwsA(isA<ViewerDisposedException>()));
        expect(() => viewer.addToScene(asset), throwsA(isA<ViewerDisposedException>()));
      } finally {
        continueTeardown.complete();
      }

      await disposal.timeout(const Duration(seconds: 10));
      await release().timeout(const Duration(seconds: 10));
      expect(identical(viewer.dispose(), disposal), isTrue);
      expect(() => viewer.createGeometry(GeometryUtils.cube()), throwsA(isA<ViewerDisposedException>()));
      expect(FilamentApp.instance!.renderableManager.hasComponent(asset.entity), isFalse);
      expect(FilamentApp.instance!.lightManager.hasComponent(light), isFalse);
    });
  });
}

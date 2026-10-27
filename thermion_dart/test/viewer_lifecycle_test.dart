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

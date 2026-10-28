@Timeout(const Duration(seconds: 600))
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_camera.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_light_manager.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/interface/render_manager.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
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

  for (final asynchronous in [false, true]) {
    test(
      'viewer releases native resources after a ${asynchronous ? 'future' : 'synchronous'} callback error',
      () async {
        final viewer = ThermionViewerFFI(app: app as FFIFilamentApp);
        await viewer.initialized;
        final asset = await viewer.createGeometry(GeometryUtils.cube());
        final light = await viewer.addDirectLight(DirectLight.point());
        final error = StateError('callback failed');
        var laterCallbackRan = false;
        viewer.onDispose(() {
          if (asynchronous) return Future<void>.error(error);
          throw error;
        });
        viewer.onDispose(() async => laterCallbackRan = true);

        final disposal = viewer.dispose();
        expect(identical(viewer.dispose(), disposal), isTrue);
        await expectLater(disposal, throwsA(same(error)));

        expect(laterCallbackRan, isTrue);
        expect(asset.isDestroyed, isTrue);
        expect(app.lightManager.hasComponent(light), isFalse);
        expect(viewer.getCameraCount(), 0);
        expect(identical(viewer.dispose(), disposal), isTrue);
        await expectLater(viewer.dispose(), throwsA(same(error)));
      },
    );
  }

  group('disposal errors', () {
    test('reports the first callback error after cleanup and logs later errors', () async {
      final app = _DisposalApp();
      final viewer = ThermionViewerFFI(app: app);
      await viewer.initialized;
      final first = StateError('first callback');
      final firstStack = StackTrace.fromString('first callback stack');
      final second = StateError('second callback');
      final secondStack = StackTrace.fromString('second callback stack');
      final records = <LogRecord>[];
      final logLevel = Logger.root.level;
      Logger.root.level = Level.WARNING;
      addTearDown(() => Logger.root.level = logLevel);
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(subscription.cancel);
      final callbackReached = Completer<void>();
      final finishCallback = Completer<void>();
      viewer.onDispose(() => Error.throwWithStackTrace(first, firstStack));
      viewer.onDispose(() => Future<void>.error(second, secondStack));
      viewer.onDispose(() async {
        callbackReached.complete();
        await finishCallback.future;
      });

      final disposal = viewer.dispose();
      Object? reportedError;
      StackTrace? reportedStack;
      var completed = false;
      final handled = disposal.then<void>(
        (_) => fail('disposal should fail'),
        onError: (Object error, StackTrace stack) {
          reportedError = error;
          reportedStack = stack;
          completed = true;
        },
      );
      try {
        await callbackReached.future.timeout(const Duration(seconds: 10));
        expect(completed, isFalse);
        expect(app.calls, isNot(contains('destroy view')));
        expect(identical(viewer.dispose(), disposal), isTrue);
        expect(() => viewer.onDispose(() async {}), throwsA(isA<ViewerDisposedException>()));
      } finally {
        finishCallback.complete();
      }
      await handled;

      expect(reportedError, same(first));
      expect(reportedStack.toString(), firstStack.toString());
      final logged = records.where((record) => identical(record.error, second)).single;
      expect(logged.stackTrace.toString(), secondStack.toString());
      expect(app.calls, containsAll(['destroy camera 0', 'destroy scene', 'destroy view']));
      expect(() => viewer.onDispose(() async {}), throwsA(isA<ViewerDisposedException>()));
      final calls = app.calls.toList();
      await expectLater(viewer.dispose(), throwsA(same(first)));
      expect(app.calls, calls);
    });

    test('one failed asset, light or camera does not skip other resources', () async {
      final app = _DisposalApp();
      final viewer = ThermionViewerFFI(app: app);
      await viewer.initialized;
      await viewer.createGeometry(GeometryUtils.cube());
      final secondAsset = await viewer.createGeometry(GeometryUtils.cube());
      await viewer.addDirectLight(DirectLight.point());
      await viewer.addDirectLight(DirectLight.point());
      await viewer.createCamera();
      final first = StateError('asset destruction failed');
      final stack = StackTrace.current;
      app.failures.addAll({
        'destroy asset 0': (first, stack),
        'remove light 0': (StateError('light removal failed'), stack),
        'destroy camera 0': (StateError('camera destruction failed'), stack),
        'destroy scene': (StateError('scene destruction failed'), stack),
      });
      var callbackRan = false;
      viewer.onDispose(() async => callbackRan = true);

      await expectLater(viewer.dispose(), throwsA(same(first)));

      expect(secondAsset.isDestroyed, isTrue);
      expect(app.calls, isNot(contains('destroy light 0')));
      expect(app.calls, containsAll(['destroy light 1', 'destroy camera 1', 'destroy view']));
      expect(callbackRan, isTrue);
      expect(() => viewer.createGeometry(GeometryUtils.cube()), throwsA(isA<ViewerDisposedException>()));
    });

    for (final (failure, skipped) in [
      ('stop rendering', ['detach skybox', 'destroy asset 0', 'destroy scene', 'destroy view']),
      ('remove asset 0', ['destroy asset 0']),
      ('disable overlay', ['detach camera', 'destroy camera 0', 'destroy scene', 'destroy view']),
      ('detach camera', ['destroy camera 0']),
      ('detach scene', ['destroy scene']),
    ]) {
      test('does not destroy dependent resources after $failure fails', () async {
        final app = _DisposalApp();
        final viewer = ThermionViewerFFI(app: app);
        await viewer.initialized;
        await viewer.createGeometry(GeometryUtils.cube());
        final error = StateError(failure);
        app.failures[failure] = (error, StackTrace.current);

        final disposal = viewer.dispose();
        await expectLater(disposal, throwsA(same(error)));

        for (final operation in skipped) {
          expect(app.calls, isNot(contains(operation)));
        }
        if (failure != 'stop rendering' && failure != 'disable overlay') {
          expect(app.calls, contains('destroy view'));
        }
        final calls = app.calls.toList();
        expect(identical(viewer.dispose(), disposal), isTrue);
        await expectLater(viewer.dispose(), throwsA(same(error)));
        expect(app.calls, calls);
      });
    }
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

// These fakes fail individual native operations without passing invalid
// pointers to Filament. The tests above also exercise real native cleanup.
class _DisposalApp implements FFIFilamentApp {
  final calls = <String>[];
  final failures = <String, (Object, StackTrace)>{};
  late final scene = _DisposalScene(this);
  late final view = _DisposalView(this);
  @override
  late final RenderManager renderManager = _DisposalRenderManager(this);
  @override
  late final FFILightManager lightManager = _DisposalLightManager(this);
  int _assets = 0;
  int _lights = 0;
  int _cameras = 0;

  void record(String operation) {
    calls.add(operation);
    final failure = failures[operation];
    if (failure != null) Error.throwWithStackTrace(failure.$1, failure.$2);
  }

  @override
  Future<View> createView({bool createScene = false}) async => view;
  @override
  Future<Camera> createCamera({ThermionEntity? targetEntity}) async => _DisposalCamera(this, _cameras++);
  @override
  Future<void> setClearOptions(
    double r,
    double g,
    double b,
    double a, {
    int clearStencil = 0,
    bool discard = false,
    bool clear = true,
  }) async {}
  @override
  Future<ThermionAsset> createGeometry(
    Geometry geometry, {
    List<MaterialInstance>? materialInstances,
    bool addToScene = true,
  }) async => _DisposalAsset(_assets++);
  @override
  Future<ThermionEntity> createDirectLight(DirectLight light) async => _lights++;
  @override
  Future<void> destroyAsset(covariant _DisposalAsset asset) async {
    record('destroy asset ${asset.entity}');
    asset.isDestroyed = true;
  }

  @override
  Future<void> destroyScene(covariant FFIScene scene) async => record('destroy scene');
  @override
  Future<void> destroyView(View view) async => record('destroy view');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DisposalView implements View {
  final _DisposalApp app;
  _DisposalView(this.app);
  @override
  Future<void> setName(String name) async {}
  @override
  Future<Scene> getScene() async => app.scene;
  @override
  Future<void> setScene(Scene? scene) async {
    if (scene == null) app.record('detach scene');
  }

  @override
  Future<void> setCamera(Camera? camera) async {
    if (camera == null) app.record('detach camera');
  }

  @override
  Future<void> setHighlightOverlayEnabled(bool enabled) async => app.record('disable overlay');
  @override
  Future<void> removeStencilHighlight(ThermionAsset asset) async {}
  @override
  Future<Viewport> getViewport() async => Viewport(0, 0, 1, 1);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DisposalScene implements FFIScene {
  final _DisposalApp app;
  _DisposalScene(this.app);
  @override
  Future<Skybox?> getSkybox() async => null;
  @override
  Future<void> setSkybox(Skybox? skybox) async => app.record('detach skybox');
  @override
  Future<IndirectLight?> getIndirectLight() async => null;
  @override
  Future<void> setIndirectLight(IndirectLight? light) async => app.record('detach IBL');
  @override
  Future<void> add(ThermionAsset asset) async {}
  @override
  Future<void> addEntity(ThermionEntity entity) async {}
  @override
  Future<void> remove(ThermionAsset asset) async => app.record('remove asset ${asset.entity}');
  @override
  Future<void> removeEntity(ThermionEntity entity) async => app.record('remove light $entity');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DisposalAsset implements FFIAsset {
  @override
  final ThermionEntity entity;
  _DisposalAsset(this.entity);
  @override
  bool isDestroyed = false;
  @override
  FFIAsset? get instanceOwner => null;
  @override
  FFIAsset? get owner => null;
  @override
  bool get isInstance => false;
  @override
  Future<List<FFIAsset>> getInstances() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DisposalCamera implements FFICamera {
  final _DisposalApp app;
  final int id;
  _DisposalCamera(this.app, this.id);
  @override
  Future<void> setLensProjection({
    double near = 0.1,
    double far = 1000,
    double aspect = 1,
    double focalLength = 28,
  }) async {}
  @override
  Future<void> destroy() async => app.record('destroy camera $id');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DisposalRenderManager implements RenderManager {
  final _DisposalApp app;
  _DisposalRenderManager(this.app);
  @override
  Future<void> setRenderable(View view, bool renderable) async => app.record('stop rendering');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DisposalLightManager implements FFILightManager {
  final _DisposalApp app;
  _DisposalLightManager(this.app);
  @override
  void destroyLight(ThermionEntity entity) => app.record('destroy light $entity');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

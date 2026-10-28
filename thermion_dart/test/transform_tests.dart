// ignore_for_file: unused_local_variable

import 'dart:async';

import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_transform_manager.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("transforms");
  await testHelper.setup();

  test('FilamentApp.setParent waits for the transform manager', () async {
    final nativeApp = FilamentApp.instance! as FFIFilamentApp;
    final manager = _ControlledParentingManager(nativeApp);
    final FilamentApp app = _ParentingTestApp(nativeApp, manager);
    var completed = false;
    final parenting = app.setParent(1, 2).then<void>((_) => completed = true);

    try {
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
    } finally {
      manager.completion.complete();
      await parenting.timeout(const Duration(seconds: 5));
    }
    expect(completed, isTrue);
  });

  test('FilamentApp.setParent propagates transform manager errors', () async {
    final nativeApp = FilamentApp.instance! as FFIFilamentApp;
    final manager = _ControlledParentingManager(nativeApp);
    final FilamentApp app = _ParentingTestApp(nativeApp, manager);
    final error = StateError('parenting failed');
    // Also handle the manager error if the app incorrectly discards its future.
    manager.completion.future.ignore();
    final failure = expectLater(app.setParent(1, null), throwsA(same(error)));
    manager.completion.completeError(error);
    await failure;
  });

  test('create entity and set as parent', () async {
    await testHelper.withViewer((viewer) async {
      final cube = await viewer.createGeometry(GeometryUtils.cube(normals: false, uvs: false));

      await testHelper.capture(viewer.view, "create_entity_before_parent");

      final entity = await FilamentApp.instance!.createEntity();

      await FilamentApp.instance!.setParent(cube.entity, entity);

      await FilamentApp.instance!.setTransform(entity, Matrix4.translation(Vector3.all(-1)));

      await testHelper.capture(viewer.view, "create_entity_after_parent");
    });
  });

  test('set/unset parent geometry', () async {
    await testHelper.withViewer((viewer) async {
      var blueMaterialInstance = await FilamentApp.instance!.createUnlitMaterialInstance();
      final blueCube = await viewer.createGeometry(
        GeometryUtils.cube(normals: false, uvs: false),
        materialInstances: [blueMaterialInstance],
      );
      await blueMaterialInstance.setParameterFloat4("baseColorFactor", 0.0, 0.0, 1.0, 1.0);

      // Position blue cube slightly behind and to the right
      await blueCube.setTransform(Matrix4.translation(Vector3(1.0, 0.0, -1.0)));

      var greenMaterialInstance = await FilamentApp.instance!.createUnlitMaterialInstance();
      final greenCube = await viewer.createGeometry(
        GeometryUtils.cube(normals: false, uvs: false),
        materialInstances: [greenMaterialInstance],
      );
      await greenMaterialInstance.setParameterFloat4("baseColorFactor", 0.0, 1.0, 0.0, 1.0);

      await viewer.addToScene(blueCube);
      await viewer.addToScene(greenCube);

      await testHelper.capture(viewer.view, "before_parent");

      await FilamentApp.instance!.setParent(blueCube.entity, greenCube.entity);

      await greenCube.setTransform(Matrix4.translation(Vector3.all(-1)));

      await testHelper.capture(viewer.view, "after_parent");

      await FilamentApp.instance!.setParent(blueCube.entity, null);

      await testHelper.capture(viewer.view, "unparent");
    });
  });

  test('transform children management', () async {
    await testHelper.withViewer((viewer) async {
      final transformManager = FilamentApp.instance!.transformManager;

      // Create a parent entity
      final parent = await FilamentApp.instance!.createEntity();
      await transformManager.createComponent(parent);

      // Create several child entities
      final children = <ThermionEntity>[];
      for (int i = 0; i < 3; i++) {
        final child = await FilamentApp.instance!.createEntity();
        children.add(child);
        await transformManager.createComponent(child);

        // Set parent relationship
        await FilamentApp.instance!.setParent(child, parent);
      }

      // Test getChildCount
      final childCount = transformManager.getChildCount(parent);
      expect(childCount, equals(3));

      // Test getChildren
      final retrievedChildren = transformManager.getChildren(parent);
      expect(retrievedChildren.length, equals(3));
      expect(retrievedChildren, containsAll(children));

      // Test that an entity with no children returns empty results
      final emptyCount = transformManager.getChildCount(children[0]);
      expect(emptyCount, equals(0));

      final emptyChildren = transformManager.getChildren(children[0]);
      expect(emptyChildren, isEmpty);
    });
  });

  test('transform transaction bulk updates', () async {
    await testHelper.withViewer((viewer) async {
      final transformManager = FilamentApp.instance!.transformManager;

      // Note: Transform transactions require FFI bindings to be regenerated after
      // adding the C API functions. Until then, the transaction methods are no-ops,
      // but the test will still verify the basic transform functionality.

      // Create multiple entities for bulk transform updates
      final entities = <ThermionEntity>[];
      final assets = <ThermionAsset>[];

      for (int i = 0; i < 5; i++) {
        final entity = await FilamentApp.instance!.createEntity();
        entities.add(entity);

        var materialInstance = await FilamentApp.instance!.createUnlitMaterialInstance();
        final cube = await viewer.createGeometry(
          GeometryUtils.cube(normals: false, uvs: false),
          materialInstances: [materialInstance],
        );

        // Set different colors for each cube
        await materialInstance.setParameterFloat4(
          "baseColorFactor",
          (i % 2 == 0) ? 1.0 : 0.0, // Red channel
          (i % 3 == 0) ? 1.0 : 0.0, // Green channel
          (i % 5 == 0) ? 1.0 : 0.0, // Blue channel
          1.0,
        );

        // Associate the geometry with our entity
        await transformManager.createComponent(entity);
        assets.add(cube);
        await viewer.addToScene(cube);
      }

      await testHelper.capture(viewer.view, "before_transaction");

      // Open transaction for bulk updates
      transformManager.openLocalTransformTransaction();

      // Update transforms in bulk - this should be faster with transaction
      for (int i = 0; i < entities.length; i++) {
        final entity = entities[i];
        final transform =
            Matrix4.translation(
              Vector3(
                (i - 2) * 2.0, // Spread cubes horizontally
                0.0,
                0.0,
              ),
            ) *
            Matrix4.rotationY(i * 0.5); // Rotate each cube differently

        transformManager.setTransform(entity, transform);
      }

      // Commit the transaction to apply all changes
      transformManager.commitLocalTransformTransaction();

      await testHelper.capture(viewer.view, "after_transaction");

      // Verify transforms were applied correctly by checking local transforms
      for (int i = 0; i < entities.length; i++) {
        final entity = entities[i];
        final localTransform = transformManager.getLocalTransform(entity);

        // Verify the translation component
        final translation = localTransform.getTranslation();
        expect(translation.x, closeTo((i - 2) * 2.0, 0.001));
        expect(translation.y, closeTo(0.0, 0.001));
        expect(translation.z, closeTo(0.0, 0.001));
      }
    });
  });
}

class _ControlledParentingManager extends FFITransformManager {
  final completion = Completer<void>();

  _ControlledParentingManager(FFIFilamentApp app) : super(app.transformManager.getNativeHandle(), app);

  @override
  Future<void> setParent(ThermionEntity child, ThermionEntity? parent, {bool preserveScaling = false}) {
    return completion.future;
  }
}

// Shares the existing engine and replaces only the transform manager.
class _ParentingTestApp extends FFIFilamentApp {
  final FFITransformManager _parentingManager;

  @override
  FFITransformManager get transformManager => _parentingManager;

  _ParentingTestApp(FFIFilamentApp app, this._parentingManager)
    : super(
        app.engine,
        app.gltfAssetLoader,
        app.renderer,
        app.transformManager.getNativeHandle(),
        app.ubershaderMaterialProvider,
        app.renderManager.getNativeHandle(),
        app.renderThreadHandle,
        app.nameComponentManager,
        app.loadResource,
        app.lightManager.getNativeHandle(),
        app.renderableManager.getNativeHandle(),
        app.animationManager.getNativeHandle(),
      );
}

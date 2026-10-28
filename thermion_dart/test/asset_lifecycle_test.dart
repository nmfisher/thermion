import 'dart:async';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'helpers.dart';

void main() async {
  final helper = TestHelper('asset_lifecycle');
  await helper.setup();
  final app = FilamentApp.instance!;
  final gltfData = await app.loadResource('file://${helper.assetsDir}/cube.glb');
  tearDownAll(app.destroy);

  for (final gltf in [false, true]) {
    final kind = gltf ? 'glTF' : 'geometry';

    Future<ThermionAsset> createOwner() =>
        gltf ? app.loadGltfFromBuffer(gltfData) : app.createGeometry(GeometryUtils.cube());

    test('$kind bounding box is cached and can be discarded independently', () async {
      final owner = await createOwner();
      try {
        final boxes = await Future.wait([owner.getBoundingBoxAsset(), owner.getBoundingBoxAsset()]);
        final box = boxes.first;
        expect(identical(box, boxes.last), isTrue);
        expect(identical(box.owner, owner), isTrue);
        expect(box.isInstance, isFalse);
        // ignore: deprecated_member_use_from_same_package
        expect(box.instanceOwner, isNull);
        expect(app.transformManager.getParent(box.entity), owner.entity);

        await owner.destroyBoundingBox();
        expect(owner.isDestroyed, isFalse);
        expect(box.isDestroyed, isTrue);
        expect(app.renderableManager.hasComponent(box.entity), isFalse);
        await owner.destroyBoundingBox();

        final replacement = await owner.getBoundingBoxAsset();
        expect(identical(replacement, box), isFalse);
        expect(replacement.isDestroyed, isFalse);
        expect(app.transformManager.getParent(replacement.entity), owner.entity);
      } finally {
        await app.destroyAsset(owner);
      }
    });

    for (final concurrentOwnerDestruction in [false, true]) {
      final cleanup = concurrentOwnerDestruction ? 'with target destruction' : 'independently';
      test('$kind bounding-box asset can be destroyed $cleanup', () async {
        final owner = await createOwner();
        try {
          final box = await owner.getBoundingBoxAsset();
          final instance = await box.createInstance();
          final boxDestruction = app.destroyAsset(box);
          if (concurrentOwnerDestruction) {
            await Future.wait([boxDestruction, app.destroyAsset(owner)]).timeout(const Duration(seconds: 10));
          } else {
            await boxDestruction;
            expect(owner.isDestroyed, isFalse);
            final replacement = await owner.getBoundingBoxAsset();
            expect(identical(replacement, box), isFalse);
            expect(replacement.isDestroyed, isFalse);
          }
          expect(box.isDestroyed, isTrue);
          expect(instance.isDestroyed, isTrue);
          expect(app.renderableManager.hasComponent(box.entity), isFalse);
          expect(app.renderableManager.hasComponent(instance.entity), isFalse);
        } finally {
          if (!owner.isDestroyed) await app.destroyAsset(owner);
        }
      });
    }

    test('$kind owner destruction also destroys owner and instance bounding boxes', () async {
      final owner = await createOwner();
      final instance = await owner.createInstance();
      final boxes = [await owner.getBoundingBoxAsset(), await instance.getBoundingBoxAsset()];

      final destruction = app.destroyAsset(owner);
      for (final box in boxes) {
        expect(box.isDestroyed, isTrue);
        expect(() => box.getNativeHandle(), throwsStateError);
      }
      await destruction;

      for (final box in boxes) {
        expect(app.renderableManager.hasComponent(box.entity), isFalse);
        expect(app.transformManager.hasComponent(box.entity), isFalse);
      }
      expect(() => owner.getBoundingBoxAsset(), throwsStateError);
    });

    test('$kind instance destruction keeps the owner bounding box alive', () async {
      final owner = await createOwner();
      try {
        final instance = await owner.createInstance();
        final ownerBox = await owner.getBoundingBoxAsset();
        final instanceBox = await instance.getBoundingBoxAsset();
        expect(owner.owner, isNull);
        expect(identical(instance.owner, owner), isTrue);
        expect(identical(ownerBox.owner, owner), isTrue);
        expect(identical(instanceBox.owner, instance), isTrue);
        expect(instanceBox.isInstance, isFalse);

        await app.destroyAsset(instance);
        expect(instanceBox.isDestroyed, isTrue);
        expect(identical(instanceBox.owner, instance), isTrue);
        expect(app.renderableManager.hasComponent(instanceBox.entity), isFalse);
        expect(ownerBox.isDestroyed, isFalse);
        expect(app.renderableManager.hasComponent(ownerBox.entity), isTrue);
      } finally {
        await app.destroyAsset(owner);
      }
    });

    for (final onInstance in [false, true]) {
      final targetKind = onInstance ? 'instance' : 'owner';
      test('$kind destruction waits for accepted $targetKind bounding box creation', () async {
        final owner = await createOwner();
        final target = onInstance ? await owner.createInstance() : owner;
        final created = target.getBoundingBoxAsset();
        final destruction = app.destroyAsset(owner);

        final box = await created;
        await destruction;

        expect(box.isDestroyed, isTrue);
        expect(app.renderableManager.hasComponent(box.entity), isFalse);
        expect(app.transformManager.hasComponent(box.entity), isFalse);
      });
    }

    test('$kind destruction waits for accepted operations on its bounding box', () async {
      final owner = await createOwner();
      final box = await owner.getBoundingBoxAsset();
      final created = box.createInstance();
      final destruction = app.destroyAsset(owner);

      final instance = await created;
      await destruction;

      expect(box.isDestroyed, isTrue);
      expect(instance.isDestroyed, isTrue);
      expect(app.renderableManager.hasComponent(instance.entity), isFalse);
      expect(app.transformManager.hasComponent(instance.entity), isFalse);
    });

    test('$kind owner destroys nested bounding boxes and their instances', () async {
      final owner = await createOwner() as FFIAsset;
      final child = await owner.getBoundingBoxAsset();
      final grandchild = await child.getBoundingBoxAsset();
      final instance = await child.createInstance();
      expect(owner.owner, isNull);
      expect(identical(child.owner, owner), isTrue);
      expect(identical(grandchild.owner, child), isTrue);
      expect(child.isInstance, isFalse);
      // ignore: deprecated_member_use_from_same_package
      expect(child.instanceOwner, isNull);
      expect(instance.isInstance, isTrue);
      expect(identical(instance.owner, child), isTrue);
      // ignore: deprecated_member_use_from_same_package
      expect(identical(instance.instanceOwner, child), isTrue);

      final destruction = app.destroyAsset(owner);
      for (final asset in [child, grandchild, instance]) {
        expect(asset.isDestroyed, isTrue);
        expect(() => asset.getNativeHandle(), throwsStateError);
      }
      await destruction.timeout(const Duration(seconds: 10));
      for (final asset in [child, grandchild, instance]) {
        expect(app.renderableManager.hasComponent(asset.entity), isFalse);
        expect(app.transformManager.hasComponent(asset.entity), isFalse);
      }
      expect(identical(child.owner, owner), isTrue);
      expect(identical(instance.owner, child), isTrue);
    });

    test('$kind nested ownership finishes pending operations before root destruction', () async {
      final owner = await createOwner();
      try {
        final instance = await owner.createInstance();
        final box = await instance.getBoundingBoxAsset();
        final boxInstance = await box.createInstance();
        final nestedBox = await boxInstance.getBoundingBoxAsset();
        final assets = [owner, instance, box, boxInstance, nestedBox];
        final entities = <ThermionEntity>{};
        for (final asset in assets) {
          entities.add(asset.entity);
          entities.addAll(await asset.getChildEntities());
        }

        // Instances share their source asset's queue. Each box has its own queue.
        final boxLookup = instance.getBoundingBoxAsset();
        final boxInstanceCreation = boxInstance.createInstance();
        final nestedBoxLookup = boxInstance.getBoundingBoxAsset();
        final nestedInstanceCreation = nestedBox.createInstance();
        final destruction = app.destroyAsset(owner);

        await Future.wait([
          boxLookup,
          boxInstanceCreation,
          nestedBoxLookup,
          nestedInstanceCreation,
          destruction,
        ]).timeout(const Duration(seconds: 10));

        expect(identical(await boxLookup, box), isTrue);
        expect(identical(await nestedBoxLookup, nestedBox), isTrue);
        assets.addAll([await boxInstanceCreation, await nestedInstanceCreation]);
        for (final asset in assets) {
          expect(asset.isDestroyed, isTrue);
          expect(() => asset.getNativeHandle(), throwsStateError);
          entities.add(asset.entity);
        }
        for (final entity in entities) {
          expect(app.renderableManager.hasComponent(entity), isFalse);
          expect(app.transformManager.hasComponent(entity), isFalse);
        }
      } finally {
        if (!owner.isDestroyed) await app.destroyAsset(owner).timeout(const Duration(seconds: 10));
      }
    });

    test('$kind parent waits for bounding box destruction already releasing its material', () async {
      final owner = await createOwner() as FFIAsset;
      final allocated = await app.createUbershaderMaterialInstance(unlit: true) as FFIMaterialInstance;
      final material = _TrackedMaterialInstance(allocated, app);
      final child = await owner.getBoundingBoxAsset();
      await child.setMaterialInstanceAt(material);
      material.entities.add(child.entity);
      material.allowDestruction = Completer<void>();
      child.ownMaterialInstance(material);
      final childDestruction = app.destroyAsset(child);
      await material.destructionStarted.future.timeout(const Duration(seconds: 10));
      final ownerDestruction = app.destroyAsset(owner);
      var ownerFinished = false;
      final ownerHandled = ownerDestruction.then((_) => ownerFinished = true);
      try {
        await Future<void>.delayed(Duration.zero);
        expect(ownerFinished, isFalse);
        expect(app.transformManager.hasComponent(owner.entity), isTrue);
        expect(material.destroyCalls, 1);
      } finally {
        material.allowDestruction!.complete();
      }
      await Future.wait([childDestruction, ownerHandled]).timeout(const Duration(seconds: 10));
      expect(material.destroyCalls, 1);
      expect(material.destroyed, isTrue);
    });

    test('$kind instance materials are retained until the native owner is destroyed', () async {
      final owner = await createOwner() as FFIAsset;
      final instance = await owner.createInstance();
      final allocated = await app.createUbershaderMaterialInstance(unlit: true) as FFIMaterialInstance;
      final material = _TrackedMaterialInstance(allocated, app);
      instance.ownMaterialInstance(material);
      for (final entity in [instance.entity, ...await instance.getChildEntities()]) {
        if (app.renderableManager.hasComponent(entity)) {
          await instance.setMaterialInstanceAt(material, entity: entity);
          material.entities.add(entity);
        }
      }

      await app.destroyAsset(instance);
      expect(material.destroyCalls, 0);
      await material.setParameterFloat4('baseColorFactor', 0, 1, 0, 1);
      await app.destroyAsset(owner);
      expect(material.destroyCalls, 1);
      expect(material.destroyed, isTrue);
    });

    test('$kind repeated destruction throws once cleanup starts', () async {
      final owner = await createOwner();
      final entities = [owner.entity, ...await owner.getChildEntities()];
      expect(owner.isDestroyed, isFalse);

      final destruction = app.destroyAsset(owner);
      expect(owner.isDestroyed, isTrue);
      expect(() => app.destroyAsset(owner), throwsStateError);
      expect(() => owner.getNativeHandle(), throwsStateError);
      await destruction;
      expect(() => app.destroyAsset(owner), throwsStateError);

      expect(owner.isDestroyed, isTrue);
      await expectLater(owner.getChildEntities(), throwsStateError);
      await expectLater(owner.getInstances(), throwsStateError);
      await expectLater(owner.createInstance(), throwsStateError);
      for (final entity in entities) {
        expect(app.transformManager.hasComponent(entity), isFalse);
      }
    });

    test('$kind owner destruction invalidates every instance alias', () async {
      final owner = await createOwner();
      final instance = await owner.createInstance();
      expect(owner.owner, isNull);
      expect(identical(instance.owner, owner), isTrue);
      // ignore: deprecated_member_use_from_same_package
      expect(owner.instanceOwner, isNull);
      // ignore: deprecated_member_use_from_same_package
      expect(identical(instance.instanceOwner, owner), isTrue);
      final instances = await owner.getInstances();
      final index = instances.indexWhere((asset) => asset.entity == instance.entity);
      final alias = instances[index];
      final indexedAlias = await owner.getInstance(index);
      expect(identical(instance, alias), isTrue);
      expect(identical(instance, indexedAlias), isTrue);
      expect(identical((await owner.getInstances())[index], instance), isTrue);
      // Populate the child cache before native destruction.
      await instance.getChildEntities();
      await alias.getChildEntities();

      final destruction = app.destroyAsset(owner);
      for (final wrapper in [instance, alias, indexedAlias]) {
        expect(wrapper.isDestroyed, isTrue);
        expect(() => app.destroyAsset(wrapper), throwsStateError);
      }
      await destruction;

      for (final wrapper in [instance, alias, indexedAlias]) {
        expect(wrapper.isDestroyed, isTrue);
        expect(() => wrapper.getNativeHandle(), throwsStateError);
        expect(identical(wrapper.owner, owner), isTrue);
        await expectLater(wrapper.getChildEntities(), throwsStateError);
        expect(() => app.destroyAsset(wrapper), throwsStateError);
      }
    });

    test('$kind instance destruction immediately invalidates all aliases', () async {
      final owner = await createOwner();
      try {
        final instance = await owner.createInstance();
        final alias = (await owner.getInstances()).firstWhere((asset) => asset.entity == instance.entity);
        final destruction = app.destroyAsset(instance);

        expect(instance.isDestroyed, isTrue);
        expect(alias.isDestroyed, isTrue);
        expect(owner.isDestroyed, isFalse);
        expect(() => app.destroyAsset(instance), throwsStateError);
        expect(() => app.destroyAsset(alias), throwsStateError);
        await destruction;
        expect(() => app.destroyAsset(alias), throwsStateError);

        if (gltf) {
          final pooledAlias = (await owner.getInstances()).firstWhere((asset) => asset.entity == instance.entity);
          expect(identical(pooledAlias, instance), isTrue);
          expect(pooledAlias.isDestroyed, isTrue);
          expect(() => app.destroyAsset(pooledAlias), throwsStateError);
        }

        expect(owner.isDestroyed, isFalse);
        expect(() => alias.getNativeHandle(), throwsStateError);
        await expectLater(alias.getChildEntities(), throwsStateError);
        await expectLater(alias.createInstance(), throwsStateError);
      } finally {
        await app.destroyAsset(owner);
      }
    });

    test('$kind new instances do not revive destroyed wrappers', () async {
      final owner = await createOwner();
      try {
        final old = await owner.createInstance();
        final oldAlias = (await owner.getInstances()).firstWhere((asset) => asset.entity == old.entity);
        final oldHandle = old.getNativeHandle();
        await app.destroyAsset(old);

        final current = await owner.createInstance();
        if (gltf) {
          // The native glTF pool reuses this exact address.
          expect(current.getNativeHandle(), oldHandle);
        }
        final currentAlias = (await owner.getInstances()).firstWhere((asset) => asset.entity == current.entity);
        expect(identical(current, old), isFalse);
        expect(identical(currentAlias, current), isTrue);
        expect(current.isDestroyed, isFalse);
        expect(currentAlias.isDestroyed, isFalse);
        expect(old.isDestroyed, isTrue);
        expect(oldAlias.isDestroyed, isTrue);

        expect(() => app.destroyAsset(oldAlias), throwsStateError);
        expect(current.isDestroyed, isFalse);
        expect(app.transformManager.hasComponent(current.entity), isTrue);

        await app.destroyAsset(currentAlias);
        expect(current.isDestroyed, isTrue);
      } finally {
        await app.destroyAsset(owner);
      }
    });

    test('$kind replacement creation waits for pending instance destruction', () async {
      final owner = await createOwner();
      try {
        final old = await owner.createInstance();
        final oldAlias = (await owner.getInstances()).firstWhere((asset) => asset.entity == old.entity);
        final oldHandle = old.getNativeHandle();
        final destruction = app.destroyAsset(old);
        final creation = owner.createInstance();

        await Future.wait([destruction, creation]).timeout(const Duration(seconds: 10));
        final replacement = await creation;
        if (gltf) {
          expect(replacement.getNativeHandle(), oldHandle);
        }
        final replacementAlias = (await owner.getInstances()).firstWhere((asset) => asset.entity == replacement.entity);
        expect(identical(replacement, old), isFalse);
        expect(identical(replacementAlias, replacement), isTrue);
        expect(old.isDestroyed, isTrue);
        expect(oldAlias.isDestroyed, isTrue);
        expect(() => oldAlias.getNativeHandle(), throwsStateError);
        expect(() => app.destroyAsset(oldAlias), throwsStateError);
        expect(replacement.isDestroyed, isFalse);
        expect(app.transformManager.hasComponent(replacement.entity), isTrue);

        await app.destroyAsset(replacement).timeout(const Duration(seconds: 10));
        expect(replacementAlias.isDestroyed, isTrue);
      } finally {
        await app.destroyAsset(owner).timeout(const Duration(seconds: 10));
      }
    });

    test('$kind parent destruction waits for accepted instance creation', () async {
      final owner = await createOwner();
      final created = owner.createInstance();
      final destruction = app.destroyAsset(owner);

      final instance = await created;
      await destruction;
      expect(instance.isDestroyed, isTrue);
      expect(() => instance.getNativeHandle(), throwsStateError);
      await expectLater(owner.createInstance(), throwsStateError);
    });

    test('$kind parent destruction waits for pending instance destruction', () async {
      final owner = await createOwner();
      final instance = await owner.createInstance();
      final instanceDestroyed = app.destroyAsset(instance);
      final ownerDestroyed = app.destroyAsset(owner);

      await Future.wait([instanceDestroyed, ownerDestroyed]);
      expect(owner.isDestroyed, isTrue);
      expect(instance.isDestroyed, isTrue);
      expect(() => instance.getNativeHandle(), throwsStateError);
      expect(() => app.destroyAsset(instance), throwsStateError);
    });
  }

  test('owned materials outlive geometry instances and are destroyed once', () async {
    final allocated = await app.createUbershaderMaterialInstance(unlit: true) as FFIMaterialInstance;
    final material = _TrackedMaterialInstance(allocated, app);
    final owner = await app.createGeometry(GeometryUtils.cube(), materialInstances: [material]) as FFIAsset;
    owner.ownMaterialInstance(material);
    // Two wrappers for the same pointer still transfer one native resource.
    owner.ownMaterialInstance(FFIMaterialInstance(material.pointer, app));
    final first = await owner.createInstance();
    final second = await owner.createInstance();
    material.entities.addAll([owner.entity, first.entity, second.entity]);

    await app.destroyAsset(first);
    expect(material.destroyCalls, 0);
    await material.setParameterFloat4('baseColorFactor', 0, 1, 0, 1);
    await app.destroyAsset(owner);
    expect(material.destroyCalls, 1);
    expect(material.destroyed, isTrue);
  });

  test('supplied materials remain borrowed across asset and instance destruction', () async {
    final allocated = await app.createUbershaderMaterialInstance(unlit: true) as FFIMaterialInstance;
    final material = _TrackedMaterialInstance(allocated, app);
    final first = await app.createGeometry(GeometryUtils.cube(), materialInstances: [material]);
    final second = await app.createGeometry(GeometryUtils.cube(), materialInstances: [material]);
    final instance = await first.createInstance();
    await app.destroyAsset(first);
    expect(instance.isDestroyed, isTrue);
    expect(material.destroyCalls, 0);
    await material.setParameterFloat4('baseColorFactor', 1, 0, 0, 1);
    await app.destroyAsset(second);
    expect(material.destroyCalls, 0);
    await material.destroy();
    expect(material.destroyCalls, 1);
  });

  test('box cleanup failures do not skip sibling instances or destroy their native owner', () async {
    final owner = await app.createGeometry(GeometryUtils.cube()) as FFIAsset;
    final ownerHandle = owner.getNativeHandle();
    final children = <FFIAsset>[];
    final handles = <Pointer<TSceneAsset>>[];
    final materials = <_TrackedMaterialInstance>[];
    final sources = <FFIAsset>[];
    final sourceHandles = <Pointer<TSceneAsset>>[];
    final generatedMaterials = <MaterialInstance>[];
    for (var i = 0; i < 3; i++) {
      final allocated = await app.createUbershaderMaterialInstance(unlit: true) as FFIMaterialInstance;
      final material = _TrackedMaterialInstance(allocated, app);
      final source = await owner.createInstance();
      final child = await source.getBoundingBoxAsset();
      generatedMaterials.add(await child.getMaterialInstanceAt());
      await child.setMaterialInstanceAt(material);
      sources.add(source);
      sourceHandles.add(source.getNativeHandle());
      expect(identical(child.owner, source), isTrue);
      material.entities.add(child.entity);
      child.ownMaterialInstance(material);
      children.add(child);
      handles.add(child.getNativeHandle());
      materials.add(material);
    }
    final instance = await children.last.createInstance();
    final instanceHandle = instance.getNativeHandle();
    materials.last.entities.add(instance.entity);
    final firstError = StateError('first child material destruction failed');
    final firstStack = StackTrace.fromString('first child material destruction stack');
    final secondError = StateError('second child material destruction failed');
    materials[0].destructionError = firstError;
    materials[0].destructionStack = firstStack;
    materials[1].destructionError = secondError;
    final records = <LogRecord>[];
    final logLevel = Logger.root.level;
    Logger.root.level = Level.WARNING;
    addTearDown(() => Logger.root.level = logLevel);
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(subscription.cancel);
    try {
      Object? reportedError;
      StackTrace? reportedStack;
      await app
          .destroyAsset(owner)
          .then<void>(
            (_) => fail('destruction should report the child failure'),
            onError: (Object error, StackTrace stack) {
              reportedError = error;
              reportedStack = stack;
            },
          );
      expect(reportedError, same(firstError));
      expect(reportedStack.toString(), firstStack.toString());
      expect(owner.isDestroyed, isTrue);
      expect(app.renderableManager.hasComponent(owner.entity), isTrue);
      for (final child in children) {
        expect(child.isDestroyed, isTrue);
        expect(app.renderableManager.hasComponent(child.entity), isFalse);
      }
      expect(app.renderableManager.hasComponent(instance.entity), isFalse);
      expect(app.renderableManager.hasComponent(sources[0].entity), isTrue);
      expect(app.renderableManager.hasComponent(sources[1].entity), isTrue);
      expect(app.renderableManager.hasComponent(sources[2].entity), isFalse);
      expect(materials.map((material) => material.destroyCalls), [1, 1, 1]);
      expect(materials.last.destroyed, isTrue);
      expect(records.where((record) => identical(record.error, secondError)), hasLength(1));
      expect(() => app.destroyAsset(owner), throwsStateError);
    } finally {
      // The public API cannot retry partial destruction. Release the remaining
      // native resources directly so this intentional failure does not leak.
      if (app.renderableManager.hasComponent(instance.entity)) {
        await withVoidCallback((requestId, cb) => SceneAsset_destroyRenderThread(instanceHandle, requestId, cb));
      }
      for (var i = 0; i < children.length; i++) {
        if (app.renderableManager.hasComponent(children[i].entity)) {
          await withVoidCallback((requestId, cb) => SceneAsset_destroyRenderThread(handles[i], requestId, cb));
          await generatedMaterials[i].destroy();
        }
        materials[i].destructionError = null;
        if (!materials[i].destroyed) await materials[i].destroy();
        if (app.renderableManager.hasComponent(sources[i].entity)) {
          await withVoidCallback((requestId, cb) => SceneAsset_destroyRenderThread(sourceHandles[i], requestId, cb));
        }
      }
      if (app.renderableManager.hasComponent(owner.entity)) {
        await withVoidCallback((requestId, cb) => SceneAsset_destroyRenderThread(ownerHandle, requestId, cb));
      }
    }
  });

  test('material failure does not skip the asset remaining owned materials', () async {
    final materials = <_TrackedMaterialInstance>[];
    for (var i = 0; i < 2; i++) {
      final allocated = await app.createUbershaderMaterialInstance(unlit: true) as FFIMaterialInstance;
      materials.add(_TrackedMaterialInstance(allocated, app));
    }
    final owner = await app.createGeometry(GeometryUtils.cube(), materialInstances: [materials.first]) as FFIAsset;
    final instance = await owner.createInstance(materialInstances: [materials.last]);
    materials.first.entities.add(owner.entity);
    materials.last.entities.add(instance.entity);
    for (final material in materials) {
      owner.ownMaterialInstance(material);
    }
    final error = StateError('first material destruction failed');
    materials.first.destructionError = error;
    try {
      await expectLater(app.destroyAsset(owner), throwsA(same(error)));
      expect(app.renderableManager.hasComponent(owner.entity), isFalse);
      expect(app.renderableManager.hasComponent(instance.entity), isFalse);
      expect(materials.map((material) => material.destroyCalls), [1, 1]);
      expect(materials.last.destroyed, isTrue);
    } finally {
      for (final material in materials) {
        material.destructionError = null;
        if (!material.destroyed) await material.destroy();
      }
    }
  });

  test('owner supports legacy subclasses that only implement instanceOwner', () {
    final root = _LegacyAsset(null);
    final instance = _LegacyAsset(root);
    expect(root.owner, isNull);
    expect(identical(instance.owner, root), isTrue);
  });

  Future<ThermionAsset> createGltfOwner({int initialInstances = 1}) async {
    final owner = await app.loadGltfFromBuffer(gltfData, initialInstances: initialInstances);
    addTearDown(() async {
      if (!owner.isDestroyed) {
        await app.destroyAsset(owner);
      }
    });
    return owner;
  }

  for (final dynamicInstances in [false, true]) {
    final kind = dynamicInstances ? 'dynamically created' : 'preallocated';
    test('owner destruction removes transforms for $kind glTF instances', () async {
      final owner = await createGltfOwner(initialInstances: dynamicInstances ? 1 : 3);
      if (dynamicInstances) {
        await owner.createInstance();
        await owner.createInstance();
      }

      final instances = await owner.getInstances();
      expect(instances, hasLength(3));
      final roots = instances.map((instance) => instance.entity).toList();
      final children = List<ThermionEntity>.of(await owner.getChildEntities());
      final entities = [owner.entity, ...roots, ...children];
      for (final entity in entities) {
        expect(app.transformManager.hasComponent(entity), isTrue);
      }

      await app.destroyAsset(owner);

      for (final entity in entities) {
        expect(app.transformManager.hasComponent(entity), isFalse, reason: 'Entity $entity still has a transform');
      }
    });
  }

  test('pooled glTF instance keeps its transforms until owner destruction', () async {
    final owner = await createGltfOwner();
    final instance = await owner.createInstance();
    final entities = [instance.entity, ...await instance.getChildEntities()];

    await app.destroyAsset(instance);
    for (final entity in entities) {
      expect(app.transformManager.hasComponent(entity), isTrue);
    }

    final reused = await owner.createInstance();
    expect(reused.entity, instance.entity);
    await app.destroyAsset(reused);
    for (final entity in entities) {
      expect(app.transformManager.hasComponent(entity), isTrue);
    }

    await owner.releaseSourceData();
    await app.destroyAsset(owner);

    for (final entity in entities) {
      expect(app.transformManager.hasComponent(entity), isFalse, reason: 'Entity $entity still has a transform');
    }
  });

  test('textured quad exposes its underlying asset destruction state', () async {
    final quad = await app.createTexturedQuad();
    expect(quad.owner, isNull);
    expect(quad.isDestroyed, isFalse);
    await quad.destroy();
    expect(quad.owner, isNull);
    expect(quad.isDestroyed, isTrue);
  });
}

class _LegacyAsset extends ThermionAsset {
  final ThermionAsset? _source;
  _LegacyAsset(this._source);

  @override
  ThermionAsset? get instanceOwner => _source;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TrackedMaterialInstance extends FFIMaterialInstance {
  final FilamentApp app;
  final entities = <ThermionEntity>[];
  final destructionStarted = Completer<void>();
  Completer<void>? allowDestruction;
  int destroyCalls = 0;
  bool destroyed = false;
  Object? destructionError;
  StackTrace? destructionStack;

  _TrackedMaterialInstance(FFIMaterialInstance material, this.app) : super(material.pointer, app);

  @override
  Future<void> destroy() async {
    destroyCalls++;
    for (final entity in entities) {
      expect(
        app.renderableManager.hasComponent(entity),
        isFalse,
        reason: 'The material must outlive every renderable using it.',
      );
    }
    if (!destructionStarted.isCompleted) destructionStarted.complete();
    if (destructionError != null) {
      Error.throwWithStackTrace(destructionError!, destructionStack ?? StackTrace.current);
    }
    await allowDestruction?.future;
    await super.destroy();
    destroyed = true;
  }
}

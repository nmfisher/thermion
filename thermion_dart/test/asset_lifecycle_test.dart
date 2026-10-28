import 'dart:async';
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

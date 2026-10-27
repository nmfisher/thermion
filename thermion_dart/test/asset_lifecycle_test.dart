import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
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
      final instances = await owner.getInstances();
      final index = instances.indexWhere((asset) => asset.entity == instance.entity);
      final alias = instances[index];
      final indexedAlias = await owner.getInstance(index);
      // Populate the shared child cache before native destruction.
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

  test('textured quad exposes its underlying asset destruction state', () async {
    final quad = await app.createTexturedQuad();
    expect(quad.isDestroyed, isFalse);
    await quad.destroy();
    expect(quad.isDestroyed, isTrue);
  });
}

import 'package:test/test.dart';
import 'package:thermion_dart/src/utils/src/geometry/utils.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("instancing");
  await testHelper.setup();

  test('create/destroy instance for geometry asset', () async {
    await testHelper.withViewer((viewer) async {
      var asset = await viewer.createGeometry(GeometryUtils.cube());

      expect(asset.isInstance, false);
      expect(await asset.getInstanceCount(), 0);

      var instance = await asset.createInstance();
      expect(instance.type, SceneAssetType.geometry);
      expect(await asset.getInstanceCount(), 1);
      expect(instance.isInstance, true);

      await viewer.addToScene(instance);
      await instance.setTransform(Matrix4.translation(Vector3(1, 0, 0)));
      await testHelper.capture(viewer.view, "geometry_with_one_instance");

      var instance2 = await asset.createInstance();
      await viewer.addToScene(instance2);
      await instance2.setTransform(Matrix4.translation(Vector3(-1, 0, 0)));
      expect(await asset.getInstanceCount(), 2);
      await testHelper.capture(viewer.view, "geometry_with_two_instances");

      await viewer.destroyAsset(instance2);
      await viewer.destroyAsset(instance);
      await testHelper.capture(viewer.view, "geometry_instance_destroyed");

      await viewer.destroyAssets();
      await testHelper.capture(viewer.view, "geometry_asset_destroyed");
    }, bg: kRed);
  });

  test("loadGltf throws an Exception when initialInstances is 0", () async {
    await testHelper.withViewer((viewer) async {
      await expectLater(
        viewer.loadGltf(
          "file://${testHelper.assetsDir}/cube.glb",
          initialInstances: 0,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  test(
    "loadGltf creates the number of instances passed via initialInstances",
    () async {
      await testHelper.withViewer((viewer) async {
        var asset = await viewer.loadGltf(
          "file://${testHelper.assetsDir}/cube.glb",
          initialInstances: 1,
        );

        expect(await asset.getInstanceCount(), 1);
        expect(asset.isInstance, false);

        final instances = await asset.getInstances();
        expect(instances[0] == asset, false);
        expect(instances[0].isInstance, true);

        asset = await viewer.loadGltf(
          "file://${testHelper.assetsDir}/cube.glb",
          initialInstances: 2,
        );
        expect(await asset.getInstanceCount(), 2);
      });
    },
  );

  test("When loadGltf is called with releaseSourceData=true, only the "
      "pre-allocated instances can be created", () async {
    await testHelper.withViewer((viewer) async {
      var asset = await viewer.loadGltf(
        "file://${testHelper.assetsDir}/cube.glb",
        releaseSourceData: true,
        initialInstances: 2,
      );
      expect(await asset.getInstanceCount(), 2);

      await expectLater(asset.createInstance(), throwsA(isA<Exception>()));
    });
  });

  test("releaseSourceData() frees the glTF source copy while keeping "
      "existing instances usable", () async {
    await testHelper.withViewer((viewer) async {
      var asset = await viewer.loadGltf(
        "file://${testHelper.assetsDir}/cube.glb",
        addToScene: false,
        initialInstances: 1,
      );
      var defaultInstance = await asset.getInstance(0);
      var instance = await asset.createInstance();
      await viewer.addToScene(defaultInstance);
      await viewer.addToScene(instance);
      await testHelper.capture(viewer.view, "gltf_before_source_release");

      // releasing via an instance wrapper is a misuse: it must throw, and
      // only the owning asset may release the source data
      await expectLater(
        instance.releaseSourceData(),
        throwsA(isA<StateError>()),
      );

      await asset.releaseSourceData();
      await testHelper.capture(viewer.view, "gltf_after_source_release");

      // existing instances are unaffected
      expect(await asset.getInstanceCount(), 2);
      expect(instance.isInstance, true);

      // no further instances can be created, on the asset or its instances
      await expectLater(asset.createInstance(), throwsA(isA<Exception>()));
      await expectLater(instance.createInstance(), throwsA(isA<Exception>()));
    }, addSkybox: true);
  });

  test(
    "releaseSourceData() throws for non-glTF assets and double release",
    () async {
      await testHelper.withViewer((viewer) async {
        var asset = await viewer.loadGltf(
          "file://${testHelper.assetsDir}/cube.glb",
          addToScene: false,
        );
        await asset.releaseSourceData();
        await expectLater(
          asset.releaseSourceData(),
          throwsA(isA<StateError>()),
        );

        var geometry = await viewer.createGeometry(GeometryUtils.cube());
        await expectLater(
          geometry.releaseSourceData(),
          throwsA(isA<StateError>()),
        );
      });
    },
  );

  test('create pre-allocated gltf instance', () async {
    await testHelper.withViewer((viewer) async {
      // Loading a glTF asset always creates a single instance behind the scenes,
      // but the entities exposed by the asset are used to manipulate all
      // instances as a group, not the singular "default" instance.
      // If you are only creating a single instance (the default behaviour),
      // then you don't need to worry about the difference.
      //
      // When creating multiple instances, however,you usually want to work
      // with each instance individually, rather than the owning asset.
      var asset = await viewer.loadGltf(
        "file://${testHelper.assetsDir}/cube.glb",
        addToScene: false,
        initialInstances: 2,
      );
      var defaultInstance = await asset.getInstance(0);
      await viewer.addToScene(defaultInstance);
      await testHelper.capture(viewer.view, "gltf_without_instance");

      var instance = await asset.createInstance();
      await instance.setTransform(Matrix4.translation(Vector3(1, 0, 0)));
      await testHelper.capture(viewer.view, "gltf_instance_created");
      await viewer.addToScene(instance);
      await testHelper.capture(viewer.view, "gltf_instance_add_to_scene");
      await viewer.removeFromScene(instance);
      await testHelper.capture(viewer.view, "gltf_instance_remove_from_scene");

      // above, we pre-allocated two instances and have used all of them
      // calling createInstance now will still create another instance, but
      // will be slower than specifying initialInstances on load.
      var instance2 = await asset.createInstance();
      await instance2.setTransform(Matrix4.translation(Vector3(-1, 0, 0)));
      await viewer.addToScene(instance2);
      await testHelper.capture(viewer.view, "gltf_instance2_add_to_scene");
    }, addSkybox: true);
  });
}

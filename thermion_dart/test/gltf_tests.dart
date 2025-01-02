// ignore_for_file: unused_local_variable

import 'dart:io';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';

import 'package:vector_math/vector_math_64.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("gltf");
  group("gltf", () {
    test('load glb from file', () async {
      await testHelper.withViewer((viewer) async {
        var model = await viewer
            .loadGlb("file://${testHelper.testDir}/assets/cube.glb");
        await testHelper.capture(viewer, "load_glb_from_file");
        await viewer.removeAsset(model);
      });
    });

    test('load glb from buffer', () async {
      await testHelper.withViewer((viewer) async {
        var buffer =
            File("${testHelper.testDir}/assets/cube.glb").readAsBytesSync();
        var model = await viewer.loadGlbFromBuffer(buffer);
        await testHelper.capture(viewer, "load_glb_from_buffer");
      });
    });

    test('load glb from buffer with instances', () async {
      await testHelper.withViewer((viewer) async {
        var buffer =
            File("${testHelper.testDir}/assets/cube.glb").readAsBytesSync();
        var model = await viewer.loadGlbFromBuffer(buffer, numInstances: 2);
        var instance = await model.createInstance();
        await instance.addToScene();
        await viewer.setTransform(
            instance.entity, Matrix4.translation(Vector3(1, 0, 0)));

        await testHelper.capture(viewer, "load_glb_from_buffer_with_instances");

        await viewer.removeAsset(instance);

        await testHelper.capture(viewer, "load_glb_from_buffer_instance_removed");

        await viewer.removeAsset(model);

        await testHelper.capture(viewer, "load_glb_from_buffer_original_removed");
      }, bg: kRed);
    });

    test('load glb from buffer with priority', () async {
      await testHelper.withViewer((viewer) async {
        viewer.addDirectLight(DirectLight.sun());
        var buffer =
            File("${testHelper.testDir}/assets/cube.glb").readAsBytesSync();

        // priority 0 gets drawn first
        var greenModel = await viewer.loadGlbFromBuffer(buffer, priority: 0);
        for (final entity in await viewer.getChildEntities(greenModel)) {
          final material = await viewer.getMaterialInstanceAt(entity, 0);
          await material!.setParameterFloat4("baseColorFactor", 0, 1, 0.0, 1.0);
        }

        // priority 7 gets drawn last
        var blueModel = await viewer.loadGlbFromBuffer(buffer, priority: 7);
        for (final entity in await viewer.getChildEntities(blueModel)) {
          final material = await viewer.getMaterialInstanceAt(entity, 0);
          await material!.setParameterFloat4("baseColorFactor", 0, 0, 1.0, 1.0);
        }

        // blue model rendered in front
        await testHelper.capture(viewer, "load_glb_from_buffer_with_priority");
      });
    });

    test('create instance from gltf', () async {
      await testHelper.withViewer((viewer) async {
        var model = await viewer.loadGlb(
            "file://${testHelper.testDir}/assets/cube.glb",
            numInstances: 32);
        await testHelper.capture(viewer, "gltf_create_instance_0");
        var instance = await model.createInstance();
        await instance.addToScene();
        await viewer.setRendering(true);

        await viewer.setTransform(
            instance.entity, Matrix4.translation(Vector3.all(1)));
        await testHelper.capture(viewer, "gltf_create_instance_1");
      });
    });

    test('create instance from gltf with new material', () async {
      await testHelper.withViewer((viewer) async {
        var model = await viewer.loadGlb(
            "file://${testHelper.testDir}/assets/cube.glb",
            numInstances: 2);
        await testHelper.capture(
            viewer, "gltf_create_instance_with_material_0");

        final materialInstance = await viewer.createUnlitMaterialInstance();
        await materialInstance.setParameterFloat4(
            "baseColorFactor", 1.0, 0.0, 0.0, 1.0);
        var instance =
            await model.createInstance(materialInstances: [materialInstance]);
        await instance.addToScene();

        await viewer.setTransform(
            instance.entity, Matrix4.translation(Vector3.all(1)));
        await testHelper.capture(
            viewer, "gltf_create_instance_with_material_1");
        await viewer.destroyMaterialInstance(materialInstance);
      });
    });

    test('replace material instance for gltf', () async {
      await testHelper.withViewer((viewer) async {
        var model = await viewer
            .loadGlb("file://${testHelper.testDir}/assets/cube.glb");
        await testHelper.capture(viewer, "gltf_default_material_instance");
        var materialInstance = await viewer.createUnlitMaterialInstance();
        await materialInstance.setParameterFloat4(
            "baseColorFactor", 1.0, 1.0, 0.0, 1.0);
        await model.setMaterialInstanceAt(materialInstance);
        await testHelper.capture(viewer, "gltf_set_material_instance");
        await viewer.removeAsset(model);
        await viewer.destroyMaterialInstance(materialInstance);
      });
    });
  });
}

import 'dart:io';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';

import 'package:vector_math/vector_math_64.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("gltf");
  group("gltf", () {
    test('load glb from file', () async {
      var viewer = await testHelper.createViewer(bg: kRed, cameraPosition: Vector3(0, 1, 5));
      var model = await viewer.loadGlb("file://${testHelper.testDir}/assets/cube.glb");
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
      await testHelper.capture(viewer, "load_glb_from_file");
      await viewer.dispose();
    });

    test('load glb from buffer', () async {
      var viewer = await testHelper.createViewer();
      var buffer = File("${testHelper.testDir}/assets/cube.glb").readAsBytesSync();
      var model = await viewer.loadGlbFromBuffer(buffer);
      await viewer.transformToUnitCube(model);
      await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
      await viewer.setCameraPosition(0, 1, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
      await testHelper.capture(viewer, "load_glb_from_buffer");
      await viewer.dispose();
    });

    test('load glb from buffer with priority', () async {
      var viewer = await testHelper.createViewer();
      await viewer.addDirectLight(DirectLight.sun());
      await viewer.setBackgroundColor(1.0, 1.0, 1.0, 1.0);
      await viewer.setCameraPosition(0, 3, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));

      var buffer = File("${testHelper.testDir}/assets/cube.glb").readAsBytesSync();
      var model1 = await viewer.loadGlbFromBuffer(buffer, priority: 7);
      var model2 = await viewer.loadGlbFromBuffer(buffer, priority: 0);

      for (final entity in await viewer.getChildEntities(model1, true)) {
        await viewer.setMaterialPropertyFloat4(
            entity, "baseColorFactor", 0, 0, 0, 1.0, 1.0);
      }
      for (final entity in await viewer.getChildEntities(model2, true)) {
        await viewer.setMaterialPropertyFloat4(
            entity, "baseColorFactor", 0, 0, 1.0, 0.0, 1.0);
      }
      await testHelper.capture(viewer, "load_glb_from_buffer_with_priority");

      await viewer.dispose();
    });
  });
}

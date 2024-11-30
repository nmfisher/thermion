// ignore_for_file: unused_local_variable

import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';

import 'package:vector_math/vector_math_64.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("transforms");
  group("transforms", () {
    test('set/unset parent geometry', () async {
      await testHelper.withViewer((viewer) async {
        var blueMaterialInstance = await viewer.createUnlitMaterialInstance();
        final blueCube = await viewer.createGeometry(GeometryHelper.cube(normals: false, uvs: false),
            materialInstances: [blueMaterialInstance]);
        await blueMaterialInstance.setParameterFloat4(
            "baseColorFactor", 0.0, 0.0, 1.0, 1.0);

        // Position blue cube slightly behind and to the right
        await viewer.setTransform(
            blueCube.entity, Matrix4.translation(Vector3(1.0, 0.0, -1.0)));

        var greenMaterialInstance = await viewer.createUnlitMaterialInstance();
        final greenCube = await viewer.createGeometry(GeometryHelper.cube(normals: false, uvs: false),
            materialInstances: [greenMaterialInstance]);
        await greenMaterialInstance.setParameterFloat4(
            "baseColorFactor", 0.0, 1.0, 0.0, 1.0);

        await testHelper.capture(viewer, "before_parent");
        await viewer.setParent(blueCube.entity, greenCube.entity);

        await viewer.setTransform(
            greenCube.entity, Matrix4.translation(Vector3.all(-1)));

        await testHelper.capture(viewer, "after_parent");

        await viewer.setParent(blueCube.entity, null);

        await testHelper.capture(viewer, "unparent");
      });
    });
  });
}

// ignore_for_file: unused_local_variable

import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("transforms");
  await testHelper.setup();

  test('create entity and set as parent', () async {
    await testHelper.withViewer((viewer) async {
      final cube = await viewer
          .createGeometry(GeometryHelper.cube(normals: false, uvs: false));

      await testHelper.capture(viewer.view, "create_entity_before_parent");
      
      final entity = await FilamentApp.instance!.createEntity();

      await FilamentApp.instance!.setParent(cube.entity, entity);

      await FilamentApp.instance!.setTransform(entity, Matrix4.translation(Vector3.all(-1)));

      await testHelper.capture(viewer.view, "create_entity_after_parent");

    });
  });

  test('set/unset parent geometry', () async {
    await testHelper.withViewer((viewer) async {
      var blueMaterialInstance =
          await FilamentApp.instance!.createUnlitMaterialInstance();
      final blueCube = await viewer.createGeometry(
          GeometryHelper.cube(normals: false, uvs: false),
          materialInstances: [blueMaterialInstance]);
      await blueMaterialInstance.setParameterFloat4(
          "baseColorFactor", 0.0, 0.0, 1.0, 1.0);

      // Position blue cube slightly behind and to the right
      await blueCube.setTransform(Matrix4.translation(Vector3(1.0, 0.0, -1.0)));

      var greenMaterialInstance =
          await FilamentApp.instance!.createUnlitMaterialInstance();
      final greenCube = await viewer.createGeometry(
          GeometryHelper.cube(normals: false, uvs: false),
          materialInstances: [greenMaterialInstance]);
      await greenMaterialInstance.setParameterFloat4(
          "baseColorFactor", 0.0, 1.0, 0.0, 1.0);

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
}

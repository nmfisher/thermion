import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("all_axes");
  await testHelper.setup();

  test('show all three axes simultaneously', () async {
    await testHelper.withViewer((viewer) async {
      await viewer.setGridOverlayVisibility(true);

      // Create a cube at origin
      final cube = await viewer.createGeometry(GeometryUtils.cube());
      await FilamentApp.instance!.setTransform(cube.entity, Matrix4.translation(Vector3(0, 3, 0)));
      await viewer.addToScene(cube);

      final camera = await viewer.getActiveCamera();
      await camera.lookAt(Vector3(10, 8, 10), focus: Vector3(0, 3, 0));

      // Create three separate axis entities (one for each axis)
      final xAxis = await viewer.createGeometry(GeometryUtils.plane(width: 100, height: 100));
      final xAxisMaterial = await TranslationAxisMaterial.createMaterialInstance(
        originX: 0.0,
        originY: 0.0,
        originZ: 0.0,
        axis: 0, // X
        lineWidth: 1.0,
        lineLength: 50.0,
      );
      await xAxis.setMaterialInstanceAt(xAxisMaterial);
      await FilamentApp.instance!.setTransform(xAxis.entity, Matrix4.translation(Vector3(0, 3, 0)));
      await viewer.addToScene(xAxis);

      final yAxis = await viewer.createGeometry(GeometryUtils.plane(width: 100, height: 100));
      final yAxisMaterial = await TranslationAxisMaterial.createMaterialInstance(
        originX: 0.0,
        originY: 0.0,
        originZ: 0.0,
        axis: 1, // Y
        lineWidth: 1.0,
        lineLength: 50.0,
      );
      await yAxis.setMaterialInstanceAt(yAxisMaterial);
      final rotation = Quaternion.axisAngle(Vector3(1, 0, 0), 3.14159265359 / 2);
      await FilamentApp.instance!.setTransform(
        yAxis.entity,
        Matrix4.compose(Vector3(0, 3, 0), rotation, Vector3.all(1.0)),
      );
      await viewer.addToScene(yAxis);

      final zAxis = await viewer.createGeometry(GeometryUtils.plane(width: 100, height: 100));
      final zAxisMaterial = await TranslationAxisMaterial.createMaterialInstance(
        originX: 0.0,
        originY: 0.0,
        originZ: 0.0,
        axis: 2, // Z
        lineWidth: 1.0,
        lineLength: 50.0,
      );
      await zAxis.setMaterialInstanceAt(zAxisMaterial);
      await FilamentApp.instance!.setTransform(zAxis.entity, Matrix4.translation(Vector3(0, 3, 0)));
      await viewer.addToScene(zAxis);

      await testHelper.capture(viewer.view, "all_three_axes");

      await viewer.removeFromScene(cube);
      await viewer.removeFromScene(xAxis);
      await viewer.removeFromScene(yAxis);
      await viewer.removeFromScene(zAxis);
    }, postProcessing: true);
  });
}

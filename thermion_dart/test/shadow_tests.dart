import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("material");

  group("shadow tests", () {
    test('enable/disable shadows', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setPostProcessing(true);
        await viewer.setShadowsEnabled(true);
        await viewer.setShadowType(ShadowType.PCF);
        var materialInsance = await viewer.createUbershaderMaterialInstance();
        await materialInsance.setParameterFloat4(
            "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
        await viewer.addDirectLight(DirectLight.sun(
            intensity: 50000,
            castShadows: true,
            direction: Vector3(1, -0.5, 0).normalized()));

        final plane = await viewer.createGeometry(
            GeometryHelper.plane(
                normals: true, uvs: true, width: 10, height: 10),
            materialInstances: [materialInsance]);
        expect(await viewer.isCastShadowsEnabled(plane.entity), true);
        expect(await viewer.isReceiveShadowsEnabled(plane.entity), true);
        await viewer.createGeometry(
            GeometryHelper.cube(
              normals: true,
              uvs: true,
            ),
            materialInstances: [materialInsance]);

        await testHelper.capture(viewer, "shadows_enabled");

        await viewer.setShadowsEnabled(false);

        await testHelper.capture(viewer, "shadows_disabled");
      }, bg: kRed);
    });

    test('enable/disable cast shadows', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setPostProcessing(true);
        await viewer.setShadowsEnabled(true);
        await viewer.setShadowType(ShadowType.PCF);
        var materialInsance = await viewer.createUbershaderMaterialInstance();
        await materialInsance.setParameterFloat4(
            "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
        await viewer.addDirectLight(DirectLight.sun(
            intensity: 50000,
            castShadows: true,
            direction: Vector3(1, -0.5, 0).normalized()));

        final plane = await viewer.createGeometry(
            GeometryHelper.plane(
                normals: true, uvs: true, width: 10, height: 10),
            materialInstances: [materialInsance]);

        final cube = await viewer.createGeometry(
            GeometryHelper.cube(
              normals: true,
              uvs: true,
            ),
            materialInstances: [materialInsance]);

        expect(await viewer.isCastShadowsEnabled(cube.entity), true);
        await testHelper.capture(viewer, "cast_shadows_enabled");

        await viewer.setCastShadows(cube.entity, false);
        expect(await viewer.isCastShadowsEnabled(cube.entity), false);
        await testHelper.capture(viewer, "cast_shadows_disabled");
      }, bg: kRed);
    });

    test('enable/disable receive shadows', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setPostProcessing(true);
        await viewer.setShadowsEnabled(true);
        await viewer.setShadowType(ShadowType.PCF);
        var materialInsance = await viewer.createUbershaderMaterialInstance();
        await materialInsance.setParameterFloat4(
            "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
        await viewer.addDirectLight(DirectLight.sun(
            intensity: 50000,
            castShadows: true,
            direction: Vector3(1, -0.5, 0).normalized()));

        final plane = await viewer.createGeometry(
            GeometryHelper.plane(
                normals: true, uvs: true, width: 10, height: 10),
            materialInstances: [materialInsance]);

        final cube = await viewer.createGeometry(
            GeometryHelper.cube(
              normals: true,
              uvs: true,
            ),
            materialInstances: [materialInsance]);

        expect(await viewer.isReceiveShadowsEnabled(plane.entity), true);
        await testHelper.capture(viewer, "receive_shadows_enabled");

        await viewer.setReceiveShadows(plane.entity, false);
        expect(await viewer.isReceiveShadowsEnabled(plane.entity), false);
        await testHelper.capture(viewer, "receive_shadows_disabled");
      }, bg: kRed);
    });
  });
}

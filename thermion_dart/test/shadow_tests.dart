import 'dart:math';

import 'package:thermion_dart/src/filament/src/light_options.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("material");
  await testHelper.setup();

  group("shadow tests", () {
    test('enable/disable shadows', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setShadowsEnabled(false);
        await viewer.setShadowType(ShadowType.PCF);
        var materialInstance =
            await FilamentApp.instance!.createUbershaderMaterialInstance();
        await materialInstance.setCullingMode(CullingMode.NONE);
        await materialInstance.setParameterFloat4(
            "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
        await viewer.addDirectLight(DirectLight.sun(
            intensity: 50000,
            castShadows: true,
            direction: Vector3(1, -0.5, 0).normalized()));

        final plane = await viewer.createGeometry(
            GeometryHelper.plane(
                normals: true, uvs: true, width: 10, height: 10),
            materialInstances: [materialInstance]);
        // await plane.setTransform(Matrix4.rotationX(pi));
        // await viewer.addToScene(plane);
        expect(await plane.isCastShadowsEnabled(), true);
        expect(await plane.isReceiveShadowsEnabled(), true);
        final cube = await viewer.createGeometry(
            GeometryHelper.cube(
              normals: true,
              uvs: true,
            ),
            materialInstances: [materialInstance]);
        await viewer.setShadowsEnabled(true);

        await testHelper.capture(viewer.view, "shadows_enabled");

        await viewer.setShadowsEnabled(false);

        await testHelper.capture(viewer.view, "shadows_disabled");
      }, bg: kRed, createRenderTarget: true, postProcessing: true);
    });

    test('enable/disable cast shadows', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setPostProcessing(true);
        await viewer.setShadowsEnabled(true);
        await viewer.setShadowType(ShadowType.PCF);
        var materialInstance =
            await FilamentApp.instance!.createUbershaderMaterialInstance();
        await materialInstance.setCullingMode(CullingMode.NONE);

        await materialInstance.setParameterFloat4(
            "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
        await viewer.addDirectLight(DirectLight.sun(
            intensity: 50000,
            castShadows: true,
            direction: Vector3(1, -0.5, 0).normalized()));

        final plane = await viewer.createGeometry(
            GeometryHelper.plane(
                normals: true, uvs: true, width: 10, height: 10),
            materialInstances: [materialInstance]);

        final cube = await viewer.createGeometry(
            GeometryHelper.cube(
              normals: true,
              uvs: true,
            ),
            materialInstances: [materialInstance]);

        expect(await cube.isCastShadowsEnabled(), true);
        await testHelper.capture(viewer.view, "cast_shadows_enabled");

        await cube.setCastShadows(false);
        expect(await cube.isCastShadowsEnabled(), false);
        await testHelper.capture(viewer.view, "cast_shadows_disabled");
      }, bg: kRed, createRenderTarget: true, postProcessing: true);
    });

    test('enable/disable receive shadows', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setPostProcessing(true);
        await viewer.setShadowsEnabled(true);
        await viewer.setShadowType(ShadowType.PCF);
        var materialInstance =
            await FilamentApp.instance!.createUbershaderMaterialInstance();
        await materialInstance.setParameterFloat4(
            "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
        await materialInstance.setCullingMode(CullingMode.NONE);

        await viewer.addDirectLight(DirectLight.sun(
            intensity: 50000,
            castShadows: true,
            direction: Vector3(1, -0.5, 0).normalized()));

        final plane = await viewer.createGeometry(
            GeometryHelper.plane(
                normals: true, uvs: true, width: 10, height: 10),
            materialInstances: [materialInstance]);

        final cube = await viewer.createGeometry(
            GeometryHelper.cube(
              normals: true,
              uvs: true,
            ),
            materialInstances: [materialInstance]);

        expect(await plane.isReceiveShadowsEnabled(), true);
        await testHelper.capture(viewer.view, "receive_shadows_enabled");

        await plane.setReceiveShadows(false);
        expect(await plane.isReceiveShadowsEnabled(), false);
        await testHelper.capture(viewer.view, "receive_shadows_disabled");
      }, bg: kRed, createRenderTarget: true, postProcessing: true);
    });
  });
}

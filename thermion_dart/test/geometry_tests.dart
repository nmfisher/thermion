// ignore_for_file: unused_local_variable

import 'dart:io';
import 'dart:math';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_viewer_ffi.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';

import 'package:vector_math/vector_math_64.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("geometry");
  group("custom geometry", () {
    test('create cube (no uvs/normals)', () async {
      var viewer = await testHelper.createViewer();
      await viewer.addLight(LightType.SUN, 6500, 1000000, 0, 0, 0, 0, 0, -1);
      await viewer.setCameraPosition(0, 2, 6);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      await viewer.setBackgroundColor(1.0, 1.0, 1.0, 1.0);
      final cube = await viewer
          .createGeometry(GeometryHelper.cube(normals: false, uvs: false));

      await testHelper.capture(viewer, "geometry_cube_no_uv_no_normal");
      await viewer.removeEntity(cube);
      await testHelper.capture(viewer, "geometry_cube_removed");
      await viewer.dispose();
    });

    test('create cube (no normals)', () async {
      var viewer = await testHelper.createViewer();
      var light = await viewer.addLight(
          LightType.POINT, 6500, 10000000, 0, 2, 0, 0, 0, 0,
          falloffRadius: 100.0);
      await viewer.setCameraPosition(0, 2, 6);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      await viewer.setBackgroundColor(1.0, 0.0, 1.0, 1.0);
      await viewer
          .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
      await testHelper.capture(viewer, "geometry_cube_no_normals");
    });

    test('create cube (with normals)', () async {
      var viewer = await testHelper.createViewer();

      var light = await viewer.addLight(
          LightType.POINT, 6500, 10000000, 0, 2, 0, 0, 0, 0,
          falloffRadius: 100.0);
      await viewer.setCameraPosition(0, 2, 6);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      await viewer.setBackgroundColor(1.0, 1.0, 1.0, 1.0);
      await viewer
          .createGeometry(GeometryHelper.cube(normals: true, uvs: false));
      await testHelper.capture(viewer, "geometry_cube_with_normals");
    });

    test('create cube with custom ubershader material instance (color)',
        () async {
      var viewer = await testHelper.createViewer();
      await viewer.addLight(LightType.SUN, 6500, 1000000, 0, 0, 0, 0, 0, -1);
      await viewer.setCameraPosition(0, 2, 6);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      await viewer.setBackgroundColor(1.0, 0.0, 1.0, 1.0);

      var materialInstance =
          await viewer.createUbershaderMaterialInstance(unlit: true);
      final cube = await viewer.createGeometry(
          GeometryHelper.cube(uvs: false, normals: true),
          materialInstance: materialInstance);
      await viewer.setMaterialPropertyFloat4(
          cube, "baseColorFactor", 0, 0.0, 1.0, 0.0, 0.0);
      await testHelper.capture(
          viewer, "geometry_cube_with_custom_material_ubershader");
      await viewer.removeEntity(cube);
      await viewer.destroyMaterialInstance(materialInstance);
    });

    test('create cube with custom ubershader material instance (texture)',
        () async {
      var viewer = await testHelper.createViewer();
      await viewer.addLight(LightType.SUN, 6500, 1000000, 0, 0, 0, 0, 0, -1);
      await viewer.setCameraPosition(0, 2, 6);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);

      var materialInstance = await viewer.createUbershaderMaterialInstance();
      final cube = await viewer.createGeometry(
          GeometryHelper.cube(uvs: true, normals: true),
          materialInstance: materialInstance);
      var textureData =
          File("${testHelper.testDir}/assets/cube_texture_512x512.png")
              .readAsBytesSync();
      var texture = await viewer.createTexture(textureData);
      await viewer.applyTexture(texture as ThermionFFITexture, cube);
      await testHelper.capture(
          viewer, "geometry_cube_with_custom_material_ubershader_texture");
      await viewer.removeEntity(cube);
      await viewer.destroyMaterialInstance(materialInstance);
      await viewer.destroyTexture(texture);
    });

    test('unlit material with color only', () async {
      var viewer = await testHelper.createViewer();
      await viewer.setCameraPosition(0, 0, 6);
      await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);
      await viewer.setPostProcessing(true);
      await viewer.setToneMapping(ToneMapper.LINEAR);

      var materialInstance = await viewer.createUnlitMaterialInstance();
      var cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstance: materialInstance);

      await viewer.setMaterialPropertyFloat4(
          cube, "baseColorFactor", 0, 0.0, 1.0, 0.0, 1.0);

      await testHelper.capture(viewer, "unlit_material_base_color");

      await viewer.dispose();
    });

    test('create cube with custom material instance (unlit)', () async {
      var viewer = await testHelper.createViewer();
      await viewer.setCameraPosition(0, 2, 6);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);
      await viewer.setPostProcessing(true);
      await viewer.setToneMapping(ToneMapper.LINEAR);

      var materialInstance = await viewer.createUnlitMaterialInstance();
      var cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstance: materialInstance);

      var textureData =
          File("${testHelper.testDir}/assets/cube_texture_512x512.png")
              .readAsBytesSync();
      var texture = await viewer.createTexture(textureData);
      await viewer.applyTexture(texture, cube);
      await testHelper.capture(
          viewer, "geometry_cube_with_custom_material_unlit_texture_only");
      await viewer.removeEntity(cube);

      cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstance: materialInstance);
      // reusing same material instance, so set baseColorIndex to -1 to disable the texture
      await viewer.setMaterialPropertyInt(cube, "baseColorIndex", 0, -1);
      await viewer.setMaterialPropertyFloat4(
          cube, "baseColorFactor", 0, 0.0, 1.0, 0.0, 1.0);
      await testHelper.capture(
          viewer, "geometry_cube_with_custom_material_unlit_color_only");
      await viewer.removeEntity(cube);

      cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstance: materialInstance);
      // now set baseColorIndex to 0 to enable the texture and the base color
      await viewer.setMaterialPropertyInt(cube, "baseColorIndex", 0, 0);
      await viewer.setMaterialPropertyFloat4(
          cube, "baseColorFactor", 0, 0.0, 1.0, 0.0, 0.5);
      await viewer.applyTexture(texture, cube);

      await testHelper.capture(
          viewer, "geometry_cube_with_custom_material_unlit_color_and_texture");

      await viewer.removeEntity(cube);

      await viewer.destroyTexture(texture);
      await viewer.destroyMaterialInstance(materialInstance);
      await viewer.dispose();
    });

    test('create sphere (no normals)', () async {
      var viewer = await testHelper.createViewer();
      await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
      await viewer.setCameraPosition(0, 0, 6);
      await viewer
          .createGeometry(GeometryHelper.sphere(normals: false, uvs: false));
      await testHelper.capture(viewer, "geometry_sphere_no_normals");
    });

    test('create geometry instance', () async {
      var viewer = await testHelper.createViewer(
          cameraPosition: Vector3(0, 0, 6), bg: kRed);
      final cube = await viewer
          .createGeometry(GeometryHelper.sphere(normals: false, uvs: false));
      await viewer.setTransform(cube, Matrix4.translation(Vector3(2, 1, 1)));
      final cube2 = await viewer.createInstance(cube);
      await viewer.setTransform(cube2, Matrix4.translation(Vector3(-2, 1, 1)));
      await testHelper.capture(viewer, "geometry_instance");
    });
  });
}

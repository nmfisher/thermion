import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:path/path.dart' as p;
import 'package:thermion_dart/thermion_dart/utils/geometry.dart';
import 'package:thermion_dart/thermion_dart/viewer/events.dart';
import 'package:vector_math/vector_math_64.dart';

import 'helpers.dart';

void main() async {
  final packageUri = findPackageRoot('thermion_dart');
  testDir = Directory("${packageUri.toFilePath()}/test").path;

  var outDir = Directory("$testDir/output");

  // outDir.deleteSync(recursive: true);
  outDir.createSync();

  Future _capture(ThermionViewer viewer, String outputFilename) async {
    var outPath = p.join(outDir.path, "$outputFilename.bmp");
    var pixelBuffer = await viewer.capture();
    await pixelBufferToBmp(pixelBuffer, viewportDimensions.width,
        viewportDimensions.height, outPath);
  }

  group('camera', () {
    test('getCameraModelMatrix, getCameraPosition, rotation', () async {
      var viewer = await createViewer();
      var matrix = await viewer.getCameraModelMatrix();
      expect(matrix.trace(), 4);
      await viewer.setCameraPosition(2.0, 2.0, 2.0);
      matrix = await viewer.getCameraModelMatrix();
      var position = matrix.getColumn(3).xyz;
      expect(position.x, 2.0);
      expect(position.y, 2.0);
      expect(position.z, 2.0);

      position = await viewer.getCameraPosition();
      expect(position.x, 2.0);
      expect(position.y, 2.0);
      expect(position.z, 2.0);
    });

    test('getCameraViewMatrix', () async {
      var viewer = await createViewer();

      var modelMatrix = await viewer.getCameraModelMatrix();
      var viewMatrix = await viewer.getCameraViewMatrix();

      // The view matrix should be the inverse of the model matrix
      var identity = modelMatrix * viewMatrix;
      expect(identity.isIdentity(), isTrue);

      // Check that moving the camera affects the view matrix
      await viewer.setCameraPosition(3.0, 4.0, 5.0);
      viewMatrix = await viewer.getCameraViewMatrix();
      var invertedView = viewMatrix.clone()..invert();
      var position = invertedView.getColumn(3).xyz;
      expect(position.x, closeTo(3.0, 1e-6));
      expect(position.y, closeTo(4.0, 1e-6));
      expect(position.z, closeTo(5.0, 1e-6));
    });

    test('getCameraProjectionMatrix', () async {
      var viewer = await createViewer();
      var projectionMatrix = await viewer.getCameraProjectionMatrix();
      print(projectionMatrix);
    });

    test('getCameraCullingProjectionMatrix', () async {
      var viewer = await createViewer();
      var matrix = await viewer.getCameraCullingProjectionMatrix();
      print(matrix);
      throw Exception("TODO");
    });

    test('getCameraFrustum', () async {
      var viewer = await createViewer();
      var frustum = await viewer.getCameraFrustum();
      print(frustum.plane5.normal);
      print(frustum.plane5.constant);

      await viewer.setCameraLensProjection(10.0, 1000.0, 1.0, 28.0);
      frustum = await viewer.getCameraFrustum();
      print(frustum.plane5.normal);
      print(frustum.plane5.constant);
    });
  });

  group('background', () {
    test('set background color to solid green', () async {
      var viewer = await createViewer();
      await viewer.setBackgroundColor(0.0, 1.0, 0.0, 1.0);
      await _capture(viewer, "bgcolor");
      await viewer.dispose();
    });

    test('load skybox', () async {
      var viewer = await createViewer();
      await viewer.loadSkybox(
          "file:///$testDir/../../examples/assets/default_env/default_env_skybox.ktx");
      await Future.delayed(Duration(seconds: 1));
      await _capture(viewer, "skybox");
    });
  });

  group("gltf", () {
    test('load glb', () async {
      var viewer = await createViewer();
      var model = await viewer.loadGlb("$testDir/cube.glb");
      await viewer.transformToUnitCube(model);
      await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
      await viewer.setCameraPosition(0, 1, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
      await _capture(viewer, "load_glb");
    });
  });

  group("scene update events", () {
    test('add light fires SceneUpdateEvent', () async {
      var viewer = await createViewer();

      final success = Completer<bool>();
      var light = DirectLight(
          type: LightType.POINT,
          color: 6500,
          intensity: 1000000,
          position: Vector3(0, 0.6, 0.6),
          direction: Vector3(0, 0, 0),
          falloffRadius: 2.0);

      late StreamSubscription listener;
      listener = viewer.sceneUpdated.listen((updateEvent) {
        var wasSuccess = updateEvent.eventType == EventType.EntityAdded &&
            updateEvent.addedEntityType == EntityType.DirectLight &&
            updateEvent.getDirectLight() == light;
        success.complete(wasSuccess);
        listener.cancel();
      });
      await viewer.addDirectLight(light);
      expect(await success.future, true);
    });

    test('remove light fires SceneUpdateEvent', () async {
      var viewer = await createViewer();

      final success = Completer<bool>();
      var light = await viewer.addDirectLight(DirectLight.point());

      late StreamSubscription listener;
      listener = viewer.sceneUpdated.listen((updateEvent) {
        var wasSuccess = updateEvent.eventType == EventType.EntityRemoved &&
            updateEvent.entity == light;
        success.complete(wasSuccess);
        listener.cancel();
      });

      await viewer.removeLight(light);

      expect(await success.future, true);
    });

    test('add geometry fires SceneUpdateEvent', () async {
      var viewer = await createViewer();

      final success = Completer<bool>();
      var geometry = GeometryHelper.cube();

      late StreamSubscription listener;
      listener = viewer.sceneUpdated.listen((updateEvent) {
        var wasSuccess = updateEvent.eventType == EventType.EntityAdded &&
            updateEvent.addedEntityType == EntityType.Geometry &&
            updateEvent.getAsGeometry() == geometry;
        success.complete(wasSuccess);
        listener.cancel();
      });
      await viewer.createGeometry(geometry);
      expect(await success.future, true);
    });

    test('remove geometry fires SceneUpdateEvent', () async {
      var viewer = await createViewer();
      var geometry = await viewer.createGeometry(GeometryHelper.cube());
      final success = Completer<bool>();

      late StreamSubscription listener;
      listener = viewer.sceneUpdated.listen((updateEvent) {
        var wasSuccess = updateEvent.eventType == EventType.EntityRemoved &&
            updateEvent.entity == geometry;
        success.complete(wasSuccess);
        listener.cancel();
      });

      await viewer.removeEntity(geometry);

      expect(await success.future, true);
    });

    test('loadGlb fires SceneUpdateEvent', () async {
      var viewer = await createViewer();

      final success = Completer<bool>();

      late StreamSubscription listener;

      final uri = "$testDir/cube.glb";

      listener = viewer.sceneUpdated.listen((updateEvent) {
        var wasSuccess = updateEvent.eventType == EventType.EntityAdded &&
            updateEvent.addedEntityType == EntityType.Gltf &&
            updateEvent.getAsGLTF().uri == uri;
        success.complete(wasSuccess);
        listener.cancel();
      });
      await viewer.loadGlb(uri, keepData: false);
      expect(await success.future, true);
    });

    test('remove glb fires SceneUpdateEvent', () async {
      var viewer = await createViewer();
      final uri = "$testDir/cube.glb";
      var entity = await viewer.loadGlb(uri, keepData: false);

      final success = Completer<bool>();

      late StreamSubscription listener;
      listener = viewer.sceneUpdated.listen((updateEvent) {
        var wasSuccess = updateEvent.eventType == EventType.EntityRemoved &&
            updateEvent.entity == entity;
        success.complete(wasSuccess);
        listener.cancel();
      });
      await viewer.removeEntity(entity);
      expect(await success.future, true);
    });
  });

  group("custom geometry", () {
    test('create cube (no normals)', () async {
      var viewer = await createViewer();
      var light = await viewer.addLight(
          LightType.POINT, 6500, 1000000, 0, 0.6, 0.6, 0, 0, 0,
          falloffRadius: 2.0);
      await viewer.setCameraPosition(0, 0, 6);
      await viewer.setBackgroundColor(1.0, 0.0, 1.0, 1.0);
      await viewer
          .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
      await _capture(viewer, "geometry_cube_no_normals");
    });

    test('create cube (with normals)', () async {
      var viewer = await createViewer();

      var light = await viewer.addLight(
          LightType.POINT, 6500, 1000000, 0, 0.5, 1, 0, 0, 0,
          falloffRadius: 100.0);
      await viewer.setCameraPosition(0, 0, 6);
      await viewer.setBackgroundColor(1.0, 0.0, 1.0, 1.0);
      await viewer
          .createGeometry(GeometryHelper.cube(normals: true, uvs: false));
      await _capture(viewer, "geometry_cube_with_normals");
    });

    test('create sphere (no normals)', () async {
      var viewer = await createViewer();
      await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
      await viewer.setCameraPosition(0, 0, 6);
      await viewer
          .createGeometry(GeometryHelper.sphere(normals: false, uvs: false));
      await _capture(viewer, "geometry_sphere_no_normals");
    });
  });

  //   test('create instance from glb when keepData is true', () async {
  //     var model = await viewer.loadGlb("$testDir/cube.glb", keepData: true);
  //     await viewer.transformToUnitCube(model);
  //     var instance = await viewer.createInstance(model);
  //     await viewer.setPosition(instance, 0.5, 0.5, -0.5);
  //     await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
  //     await viewer.setCameraPosition(0, 1, 5);
  //     await viewer
  //         .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
  //     await viewer.setRendering(true);
  //     await _capture(viewer, "glb_create_instance");
  //     await viewer.setRendering(false);
  //   });

  //   test('create instance from glb fails when keepData is false', () async {
  //     var model = await viewer.loadGlb("$testDir/cube.glb", keepData: false);
  //     bool thrown = false;
  //     try {
  //       await viewer.createInstance(model);
  //     } catch (err) {
  //       thrown = true;
  //     }
  //     expect(thrown, true);
  //   });
  // });

  // group('Skinning & animations', () {
  //   test('get bone names', () async {
  //     var model = await viewer.loadGlb("$testDir/assets/shapes.glb");
  //     var names = await viewer.getBoneNames(model);
  //     expect(names.first, "Bone");
  //   });

  //   test('reset bones', () async {
  //     var model = await viewer.loadGlb("$testDir/assets/shapes.glb");
  //     await viewer.resetBones(model);
  //   });
  //   test('set from BVH', () async {
  //     var model = await viewer.loadGlb("$testDir/assets/shapes.glb");
  //     var animation = BVHParser.parse(
  //         File("$testDir/assets/animation.bvh").readAsStringSync(),
  //         boneRegex: RegExp(r"Bone$"));
  //     await viewer.addBoneAnimation(model, animation);
  //   });

  //   test('fade in/out', () async {
  //     var model = await viewer.loadGlb("$testDir/assets/shapes.glb");
  //     var animation = BVHParser.parse(
  //         File("$testDir/assets/animation.bvh").readAsStringSync(),
  //         boneRegex: RegExp(r"Bone$"));
  //     await viewer.addBoneAnimation(model, animation,
  //         fadeInInSecs: 0.5, fadeOutInSecs: 0.5);
  //     await Future.delayed(Duration(seconds: 1));
  //   });

  group("materials", () {
    test('set float4 material property for custom geometry', () async {
      var viewer = await createViewer();

      await viewer.setCameraPosition(0, 0, 6);
      await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
      var light = await viewer.addLight(
          LightType.SUN, 6500, 1000000, 0, 0, 0, 0, 0, -1);

      final cube = await viewer.createGeometry(GeometryHelper.cube());

      await _capture(viewer, "set_material_float4_pre");
      await viewer.setMaterialPropertyFloat4(
          cube, "baseColorFactor", 0, 0.0, 1.0, 0.0, 1.0);
      await _capture(viewer, "set_material_float4_post");
    });
    test('set float material property for custom geometry', () async {
      var viewer = await createViewer();

      await viewer.setCameraPosition(0, 0, 6);
      await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
      var light = await viewer.addLight(
          LightType.SUN, 6500, 1000000, 0, 0, 0, 0, 0, -1);

      final cube = await viewer.createGeometry(GeometryHelper.cube());

      // this won't actually do anything because the default ubershader doesn't use specular/glossiness
      // but we can at least check that the call succeeds
      await _capture(viewer, "set_material_specular_pre");
      await viewer.setMaterialPropertyFloat(cube, "specularFactor", 0, 0.0);
      await _capture(viewer, "set_material_specular_post");
    });

    test('set float material property (roughness) for custom geometry',
        () async {
      var viewer = await createViewer();

      await viewer.setCameraPosition(0, 0, 6);
      await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
      var light = await viewer.addLight(
          LightType.SUN, 6500, 1000000, 0, 0, 0, 0, 0, -1);

      final cube = await viewer.createGeometry(GeometryHelper.cube());

      // this won't actually do anything because the default ubershader doesn't use specular/glossiness
      // but we can at least check that the call succeeds
      await _capture(viewer, "set_material_roughness_pre");

      await viewer.setMaterialPropertyFloat(cube, "metallicFactor", 0, 0.0);
      await viewer.setMaterialPropertyFloat(cube, "roughnessFactor", 0, 0.0);
      await _capture(viewer, "set_material_roughness_post");
    });
  });

  group("transforms & parenting", () {
    test('getParent and getAncestor both return null when entity has no parent',
        () async {
      var viewer = await createViewer();

      final cube = await viewer.createGeometry(GeometryHelper.cube());

      expect(await viewer.getParent(cube), isNull);
      expect(await viewer.getAncestor(cube), isNull);
    });

    test(
        'getParent returns the parent entity after one has been set via setParent',
        () async {
      var viewer = await createViewer();

      final cube1 = await viewer.createGeometry(GeometryHelper.cube());

      final cube2 = await viewer.createGeometry(GeometryHelper.cube());

      await viewer.setParent(cube1, cube2);

      final parent = await viewer.getParent(cube1);

      expect(parent, cube2);
    });

    test('getAncestor returns the ultimate parent entity', () async {
      var viewer = await createViewer();

      final grandparent = await viewer.createGeometry(GeometryHelper.cube());
      final parent = await viewer.createGeometry(GeometryHelper.cube());
      final child = await viewer.createGeometry(GeometryHelper.cube());

      await viewer.setParent(child, parent);
      await viewer.setParent(parent, grandparent);

      expect(await viewer.getAncestor(child), grandparent);
    });

    test('set position based on screenspace coord', () async {
      var viewer = await createViewer();
      print(await viewer.getCameraFov(true));
      await viewer.createIbl(1.0, 1.0, 1.0, 1000);
      await viewer.setCameraPosition(0, 0, 6);
      await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
      // Create the cube geometry
      final cube = await viewer.createGeometry(GeometryHelper.cube());
      // await viewer.setPosition(cube, -0.05, 0.04, 5.9);
      // await viewer.setPosition(cube, -2.54, 2.54, 0);
      await viewer.queuePositionUpdateFromViewportCoords(cube, 0, 0);

      // we need an explicit render call here to process the transform queue
      await viewer.render();

      await _capture(viewer, "set_position_from_viewport_coords");
    });
  });

  //   test('enable grid overlay', () async {
  //     await viewer.setBackgroundColor(0, 0, 0, 1);
  //     await viewer.setCameraPosition(0, 0.5, 0);
  //     await viewer
  //         .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.1));
  //     await viewer.setRendering(true);
  //     await viewer.setLayerEnabled(2, true);
  //     await _capture(viewer, "grid");
  //     await viewer.setRendering(false);
  //   });

  //   test('point light', () async {
  //     var model = await viewer.loadGlb("$testDir/cube.glb");
  //     await viewer.transformToUnitCube(model);
  //     var light = await viewer.addLight(
  //         LightType.POINT, 6500, 1000000, 0, 2, 0, 0, -1, 0,
  //         falloffRadius: 10.0);
  //     await viewer.setBackgroundColor(0.0, 0.0, 0.0, 1.0);
  //     await viewer.setCameraPosition(0, 1, 5);
  //     await viewer
  //         .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
  //     await viewer.setRendering(true);
  //     await _capture(viewer, "point_light");
  //     await viewer.setRendering(false);
  //   });

  //   test('set point light position', () async {
  //     var model = await viewer.loadGlb("$testDir/cube.glb");
  //     await viewer.transformToUnitCube(model);
  //     var light = await viewer.addLight(
  //         LightType.POINT, 6500, 1000000, 0, 2, 0, 0, -1, 0,
  //         falloffRadius: 10.0);
  //     await viewer.setLightPosition(light, 0.5, 2, 0);
  //     await viewer.setBackgroundColor(0.0, 0.0, 0.0, 1.0);
  //     await viewer.setCameraPosition(0, 1, 5);
  //     await viewer
  //         .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
  //     await viewer.setRendering(true);
  //     await _capture(viewer, "move_point_light");
  //     await viewer.setRendering(false);
  //   });

  //   test('directional light', () async {
  //     var model = await viewer.loadGlb("$testDir/cube.glb");
  //     await viewer.transformToUnitCube(model);
  //     var light = await viewer.addLight(
  //         LightType.SUN, 6500, 1000000, 0, 0, 0, 0, -1, 0);
  //     await viewer.setBackgroundColor(0.0, 0.0, 0.0, 1.0);
  //     await viewer.setCameraPosition(0, 1, 5);
  //     await viewer
  //         .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
  //     await viewer.setRendering(true);
  //     await _capture(viewer, "directional_light");
  //     await viewer.setRendering(false);
  //   });

  //   test('set directional light direction', () async {
  //     var model = await viewer.loadGlb("$testDir/cube.glb");
  //     await viewer.transformToUnitCube(model);
  //     var light = await viewer.addLight(
  //         LightType.SUN, 6500, 1000000, 0, 0, 0, 0, -1, 0);
  //     await viewer.setLightDirection(light, Vector3(-1, -1, -1));
  //     await viewer.setBackgroundColor(0.0, 0.0, 0.0, 1.0);
  //     await viewer.setCameraPosition(0, 1, 5);
  //     await viewer
  //         .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
  //     await viewer.setRendering(true);
  //     await _capture(viewer, "set_directional_light_direction");
  //     await viewer.setRendering(false);
  //   });

  group("stencil", () {
    test('set stencil highlight for glb', () async {
      final viewer = await createViewer();
      var model = await viewer.loadGlb("$testDir/cube.glb", keepData: true);
      await viewer.setPostProcessing(true);

      var light = await viewer.addLight(
          LightType.SUN, 6500, 1000000, 0, 0, 0, 0, -1, 0);
      await viewer.setLightDirection(light, Vector3(0, 1, -1));

      await viewer.setBackgroundColor(0.0, 1.0, 0.0, 1.0);
      await viewer.setCameraPosition(0, -1, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), pi / 8));
      await viewer.setStencilHighlight(model);
      await _capture(viewer, "stencil_highlight_glb");
    });

    test('set stencil highlight for geometry', () async {
      var viewer = await createViewer();
      await viewer.setPostProcessing(true);
      await viewer.setBackgroundColor(0.0, 1.0, 0.0, 1.0);
      await viewer.setCameraPosition(0, 2, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));

      var cube = await viewer.createGeometry(GeometryHelper.cube());
      await viewer.setStencilHighlight(cube);

      await _capture(viewer, "stencil_highlight_geometry");

      await viewer.removeStencilHighlight(cube);

      await _capture(viewer, "stencil_highlight_geometry_remove");
    });

    test('set stencil highlight for gltf asset', () async {
      var viewer = await createViewer();
      await viewer.setPostProcessing(true);
      await viewer.setBackgroundColor(0.0, 1.0, 0.0, 1.0);
      await viewer.setCameraPosition(0, 1, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));

      var cube1 = await viewer.loadGlb("$testDir/cube.glb", keepData: true);
      await viewer.transformToUnitCube(cube1);

      await viewer.setStencilHighlight(cube1);

      await _capture(viewer, "stencil_highlight_gltf");

      await viewer.removeStencilHighlight(cube1);

      await _capture(viewer, "stencil_highlight_gltf_removed");
    });

    test('set stencil highlight for multiple geometry ', () async {
      var viewer = await createViewer();
      await viewer.setPostProcessing(true);
      await viewer.setBackgroundColor(0.0, 1.0, 0.0, 1.0);
      await viewer.setCameraPosition(0, 1, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));

      var cube1 = await viewer.createGeometry(GeometryHelper.cube());
      var cube2 = await viewer.createGeometry(GeometryHelper.cube());
      await viewer.setPosition(cube2, 0.5, 0.5, 0);
      await viewer.setStencilHighlight(cube1);
      await viewer.setStencilHighlight(cube2, r: 0.0, g: 0.0, b: 1.0);

      await _capture(viewer, "stencil_highlight_multiple_geometry");

      await viewer.removeStencilHighlight(cube1);
      await viewer.removeStencilHighlight(cube2);

      await _capture(viewer, "stencil_highlight_multiple_geometry_removed");
    });

    test('set stencil highlight for multiple gltf assets ', () async {
      var viewer = await createViewer();
      await viewer.setPostProcessing(true);
      await viewer.setBackgroundColor(0.0, 1.0, 0.0, 1.0);
      await viewer.setCameraPosition(0, 1, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));

      var cube1 = await viewer.loadGlb("$testDir/cube.glb", keepData: true);
      await viewer.transformToUnitCube(cube1);
      var cube2 = await viewer.loadGlb("$testDir/cube.glb", keepData: true);
      await viewer.transformToUnitCube(cube2);
      await viewer.setPosition(cube2, 0.5, 0.5, 0);
      await viewer.setStencilHighlight(cube1);
      await viewer.setStencilHighlight(cube2, r: 0.0, g: 0.0, b: 1.0);

      await _capture(viewer, "stencil_highlight_multiple_geometry");

      await viewer.removeStencilHighlight(cube1);
      await viewer.removeStencilHighlight(cube2);

      await _capture(viewer, "stencil_highlight_multiple_geometry_removed");
    });
  });
}

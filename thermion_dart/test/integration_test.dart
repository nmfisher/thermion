import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:path/path.dart' as p;
import 'package:thermion_dart/thermion_dart/utils/geometry.dart';
import 'package:thermion_dart/thermion_dart/viewer/events.dart';
import 'package:thermion_dart/thermion_dart/viewer/ffi/src/thermion_viewer_ffi.dart';
import 'package:vector_math/vector_math_64.dart';

import 'helpers.dart';

Color kWhite = ColorFloat32(4)..setRgba(1.0, 1.0, 1.0, 1.0);
Color kRed = ColorFloat32(4)..setRgba(1.0, 0.0, 0.0, 1.0);

void main() async {
  final packageUri = findPackageRoot('thermion_dart');
  testDir = Directory("${packageUri.toFilePath()}/test").path;

  var outDir = Directory("$testDir/output");

  // outDir.deleteSync(recursive: true);
  outDir.createSync();

  Future _capture(ThermionViewer viewer, String outputFilename) async {
    await Future.delayed(Duration(milliseconds: 10));
    var outPath = p.join(outDir.path, "$outputFilename.bmp");
    var pixelBuffer = await viewer.capture();
    await savePixelBufferToBmp(
        pixelBuffer,
        viewer.viewportDimensions.$1.toInt(),
        viewer.viewportDimensions.$2.toInt(),
        outPath);
    return pixelBuffer;
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

      await viewer.setCameraLensProjection(
          near: 10.0, far: 1000.0, aspect: 1.0, focalLength: 28.0);
      frustum = await viewer.getCameraFrustum();
      print(frustum.plane5.normal);
      print(frustum.plane5.constant);
    });

    test('set custom projection/culling matrix', () async {
      var viewer =
          await createViewer(bg: kRed, cameraPosition: Vector3(0, 0, 4));
      var camera = await viewer.getMainCamera();
      final cube = await viewer.createGeometry(GeometryHelper.cube());

      // cube is visible when inside the frustum, cube is visible
      var projectionMatrix =
          makeOrthographicMatrix(-10.0, 10.0, -10.0, 10.0, 0.05, 10000);
      await camera.setProjectionMatrixWithCulling(
          projectionMatrix, 0.05, 10000);
      await _capture(
          viewer, "camera_projection_culling_matrix_object_in_frustum");

      // cube no longer visible when the far plane is moved closer to camera so cube is outside
      projectionMatrix =
          makeOrthographicMatrix(-10.0, 10.0, -10.0, 10.0, 0.05, 1);
      await camera.setProjectionMatrixWithCulling(projectionMatrix, 0.05, 1);
      await _capture(
          viewer, "camera_projection_culling_matrix_object_outside_frustum");
    });

    test('setting camera transform updates model matrix', () async {
      var viewer = await createViewer();

      var cameraEntity = await viewer.getMainCameraEntity();
      var camera = await viewer.getMainCamera();

      await viewer.setPosition(cameraEntity, 1, 0, 0);

      var modelMatrix = await viewer.getCameraModelMatrix();
      expect(modelMatrix.getColumn(3).x, 1.0);
      expect(modelMatrix.getColumn(3).y, 0.0);
      expect(modelMatrix.getColumn(3).z, 0.0);
      expect(modelMatrix.getColumn(3).w, 1.0);
    });
  });

  group('background', () {
    test('set background color to solid green', () async {
      var viewer = await createViewer();
      await viewer.setBackgroundColor(0.0, 1.0, 0.0, 1.0);
      await _capture(viewer, "set_background_color_to_solid_green");
      await viewer.dispose();
    });

    test('set background color to full transparency', () async {
      var viewer = await createViewer();
      await viewer.setBackgroundColor(0.0, 1.0, 0.0, 0.0);
      await _capture(viewer, "set_background_color_to_transparent_green");
      await viewer.dispose();
    });

    test('load skybox', () async {
      var viewer = await createViewer();
      await viewer.loadSkybox(
          "file:///$testDir/../../examples/assets/default_env/default_env_skybox.ktx");
      await Future.delayed(Duration(seconds: 1));
      await _capture(viewer, "skybox");
    });

    test('set background image', () async {
      var viewer = await createViewer();
      await viewer
          .setBackgroundImage("file:///$testDir/cube_texture_512x512.png");
      await viewer.setPostProcessing(true);
      await viewer.setToneMapping(ToneMapper.LINEAR);
      await _capture(viewer, "set_background_image");
      await viewer.dispose();
    });
  });

  group("gltf", () {
    test('load glb from file', () async {
      var viewer = await createViewer();
      var model = await viewer.loadGlb("file://$testDir/cube.glb");
      await viewer.transformToUnitCube(model);
      await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
      await viewer.setCameraPosition(0, 1, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
      await _capture(viewer, "load_glb_from_file");
    });

    test('load glb from buffer', () async {
      var viewer = await createViewer();
      var buffer = File("$testDir/cube.glb").readAsBytesSync();
      var model = await viewer.loadGlbFromBuffer(buffer);
      await viewer.transformToUnitCube(model);
      await viewer.setBackgroundColor(0.0, 0.0, 1.0, 1.0);
      await viewer.setCameraPosition(0, 1, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));
      await _capture(viewer, "load_glb_from_buffer");
    });

    test('load glb from buffer with priority', () async {
      var viewer = await createViewer();
      await viewer.addDirectLight(DirectLight.sun());
      await viewer.setBackgroundColor(1.0, 1.0, 1.0, 1.0);
      await viewer.setCameraPosition(0, 3, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));

      var buffer = File("$testDir/cube.glb").readAsBytesSync();
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
      await _capture(viewer, "load_glb_from_buffer_with_priority");
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
    test('create cube (no uvs/normals)', () async {
      var viewer = await createViewer();
      await viewer.addLight(LightType.SUN, 6500, 1000000, 0, 0, 0, 0, 0, -1);
      await viewer.setCameraPosition(0, 2, 6);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      await viewer.setBackgroundColor(1.0, 1.0, 1.0, 1.0);
      await viewer
          .createGeometry(GeometryHelper.cube(normals: false, uvs: false));

      await _capture(viewer, "geometry_cube_no_uv_no_normal");
    });

    test('create cube (no normals)', () async {
      var viewer = await createViewer();
      var light = await viewer.addLight(
          LightType.POINT, 6500, 10000000, 0, 2, 0, 0, 0, 0,
          falloffRadius: 100.0);
      await viewer.setCameraPosition(0, 2, 6);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      await viewer.setBackgroundColor(1.0, 0.0, 1.0, 1.0);
      await viewer
          .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
      await _capture(viewer, "geometry_cube_no_normals");
    });

    test('create cube (with normals)', () async {
      var viewer = await createViewer();

      var light = await viewer.addLight(
          LightType.POINT, 6500, 10000000, 0, 2, 0, 0, 0, 0,
          falloffRadius: 100.0);
      await viewer.setCameraPosition(0, 2, 6);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      await viewer.setBackgroundColor(1.0, 1.0, 1.0, 1.0);
      await viewer
          .createGeometry(GeometryHelper.cube(normals: true, uvs: false));
      await _capture(viewer, "geometry_cube_with_normals");
    });

    test('create cube with custom ubershader material instance (color)',
        () async {
      var viewer = await createViewer();
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
      await _capture(viewer, "geometry_cube_with_custom_material_ubershader");
      await viewer.removeEntity(cube);
      await viewer.destroyMaterialInstance(materialInstance);
    });

    test('create cube with custom ubershader material instance (texture)',
        () async {
      var viewer = await createViewer();
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
          File("$testDir/cube_texture_512x512.png").readAsBytesSync();
      var texture = await viewer.createTexture(textureData);
      await viewer.applyTexture(texture as ThermionFFITexture, cube);
      await _capture(
          viewer, "geometry_cube_with_custom_material_ubershader_texture");
      await viewer.removeEntity(cube);
      await viewer.destroyMaterialInstance(materialInstance);
      await viewer.destroyTexture(texture);
    });

    test('create cube with custom material instance (unlit)', () async {
      var viewer = await createViewer();
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
          File("$testDir/cube_texture_512x512.png").readAsBytesSync();
      var texture = await viewer.createTexture(textureData);
      await viewer.applyTexture(texture, cube);
      await _capture(
          viewer, "geometry_cube_with_custom_material_unlit_texture_only");
      await viewer.removeEntity(cube);

      cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstance: materialInstance);
      // reusing same material instance, so set baseColorIndex to -1 to disable the texture
      await viewer.setMaterialPropertyInt(cube, "baseColorIndex", 0, -1);
      await viewer.setMaterialPropertyFloat4(
          cube, "baseColorFactor", 0, 0.0, 1.0, 0.0, 1.0);
      await _capture(
          viewer, "geometry_cube_with_custom_material_unlit_color_only");
      await viewer.removeEntity(cube);

      cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstance: materialInstance);
      // now set baseColorIndex to 0 to enable the texture and the base color
      await viewer.setMaterialPropertyInt(cube, "baseColorIndex", 0, 0);
      await viewer.setMaterialPropertyFloat4(
          cube, "baseColorFactor", 0, 0.0, 1.0, 0.0, 0.5);
      await viewer.applyTexture(texture, cube);

      await _capture(
          viewer, "geometry_cube_with_custom_material_unlit_color_and_texture");

      await viewer.removeEntity(cube);

      await viewer.destroyTexture(texture);
      await viewer.destroyMaterialInstance(materialInstance);
      await viewer.dispose();
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

  group("MaterialInstance", () {
    test('disable depth write', () async {
      var viewer = await createViewer();
      await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);
      await viewer.setCameraPosition(0, 0, 6);
      await viewer.addDirectLight(
          DirectLight.sun(direction: Vector3(0, 0, -1)..normalize()));

      final cube1 = await viewer.createGeometry(GeometryHelper.cube());
      var materialInstance = await viewer.getMaterialInstanceAt(cube1, 0);

      final cube2 = await viewer.createGeometry(GeometryHelper.cube());
      await viewer.setMaterialPropertyFloat4(
          cube2, "baseColorFactor", 0, 0, 1, 0, 1);
      await viewer.setPosition(cube2, 1.0, 0.0, -1.0);

      expect(materialInstance, isNotNull);

      // with depth write enabled on both materials, cube2 renders behind the white cube
      await _capture(viewer, "material_instance_depth_write_enabled");

      // if we disable depth write on cube1, then cube2 will always appear in front
      // (relying on insertion order)
      materialInstance!.setDepthWriteEnabled(false);
      await _capture(viewer, "material_instance_depth_write_disabled");

      // set priority for the cube1 cube to 7 (render) last, cube1 renders in front
      await viewer.setPriority(cube1, 7);
      await _capture(
          viewer, "material_instance_depth_write_disabled_with_priority");
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

  group("layers & overlays", () {
    test('enable grid overlay', () async {
      var viewer = await createViewer();
      await viewer.setBackgroundColor(0, 0, 0, 1);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      await viewer.setCameraPosition(0, 2, 0);
      await _capture(viewer, "grid_overlay_default");
      await viewer.setLayerVisibility(7, true);
      await _capture(viewer, "grid_overlay_enabled");
      await viewer.setLayerVisibility(7, false);
      await _capture(viewer, "grid_overlay_disabled");
    });

    test('load glb from buffer with layer', () async {
      var viewer = await createViewer();

      await viewer.setBackgroundColor(1, 0, 1, 1);
      await viewer.setCameraPosition(0, 2, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));

      var buffer = File("$testDir/cube.glb").readAsBytesSync();
      var model = await viewer.loadGlbFromBuffer(buffer, layer: 1);
      await _capture(viewer, "load_glb_from_buffer_with_layer_disabled");
      await viewer.setLayerVisibility(1, true);
      await _capture(viewer, "load_glb_from_buffer_with_layer_enabled");
    });

    test('change layer visibility at runtime', () async {
      var viewer = await createViewer();

      await viewer.setBackgroundColor(1, 0, 1, 1);
      await viewer.setCameraPosition(0, 2, 5);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -0.5));

      var cube = await viewer.createGeometry(GeometryHelper.cube());
      await _capture(viewer, "change_layer_visibility_at_runtime_default");

      // all entities set to layer 0 by default, so this should now be invisible
      await viewer.setLayerVisibility(0, false);
      await _capture(
          viewer, "change_layer_visibility_at_runtime_layer0_invisible");

      // now change the visibility layer to 5, should be invisible
      await viewer.setVisibilityLayer(cube, 5);
      await _capture(
          viewer, "change_layer_visibility_at_runtime_layer5_invisible");

      // now toggle layer 5 visibility, cube should now be visible
      await viewer.setLayerVisibility(5, true);
      await _capture(
          viewer, "change_layer_visibility_at_runtime_layer5_visible");
    });
  });

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

  group("texture", () {
    test("create/apply/dispose texture", () async {
      var viewer = await createViewer();

      var textureData =
          File("$testDir/cube_texture_512x512.png").readAsBytesSync();

      var texture = await viewer.createTexture(textureData);
      await viewer.setBackgroundColor(0.0, 0.0, 0.0, 1.0);
      await viewer.addDirectLight(
          DirectLight.sun(direction: Vector3(0, -10, -1)..normalize()));
      await viewer.addDirectLight(DirectLight.spot(
          intensity: 1000000,
          position: Vector3(0, 0, 1.5),
          direction: Vector3(0, 0, -1)..normalize(),
          falloffRadius: 10,
          spotLightConeInner: 1,
          spotLightConeOuter: 1));
      await viewer.setCameraPosition(0, 2, 6);
      await viewer
          .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
      var materialInstance =
          await viewer.createUbershaderMaterialInstance(unlit: true);
      var cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstance: materialInstance);

      await viewer.setPostProcessing(true);
      await viewer.setToneMapping(ToneMapper.LINEAR);

      await viewer.applyTexture(texture, cube,
          materialIndex: 0, parameterName: "baseColorMap");

      await _capture(viewer, "texture_applied_to_geometry");

      await viewer.removeEntity(cube);
      await viewer.destroyTexture(texture);
    });
  });

  group("render thread", () {
    test("request frame on render thread", () async {
      var viewer = await createViewer();
      viewer.requestFrame();

      await Future.delayed(Duration(milliseconds: 20));
      await viewer.dispose();
    });
  });

  group("unproject", () {
    test("unproject", () async {
      final dimensions = (width: 1280, height: 768);

      var viewer = await createViewer(viewportDimensions: dimensions);
      await viewer.setPostProcessing(false);
      // await viewer.setToneMapping(ToneMapper.LINEAR);
      await viewer.setBackgroundColor(1.0, 1.0, 1.0, 1.0);
      // await viewer.createIbl(1.0, 1.0, 1.0, 100000);
      await viewer.addLight(LightType.SUN, 6500, 100000, -2, 0, 0, 1, -1, 0);
      await viewer.addLight(LightType.SPOT, 6500, 500000, 0, 0, 2, 0, 0, -1,
          falloffRadius: 10, spotLightConeInner: 1.0, spotLightConeOuter: 2.0);

      await viewer.setCameraPosition(-3, 4, 6);
      await viewer.setCameraRotation(
          Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
              Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 6));
      var cube =
          await viewer.createGeometry(GeometryHelper.cube(), keepData: true);
      await viewer.setMaterialPropertyFloat4(
          cube, "baseColorFactor", 0, 1.0, 1.0, 1.0, 1.0);
      var textureData =
          File("$testDir/cube_texture_512x512.png").readAsBytesSync();
      var texture = await viewer.createTexture(textureData);
      await viewer.applyTexture(texture, cube,
          materialIndex: 0, parameterName: "baseColorMap");

      var numFrames = 60;

      // first do the render
      for (int i = 0; i < numFrames; i++) {
        await viewer.setCameraPosition(-3 + (i / numFrames * 2), 4, 6);

        await viewer.setCameraRotation(
            Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
                Quaternion.axisAngle(
                    Vector3(1, 0, 0), -pi / 6 - (i / numFrames * pi / 6)));

        var rendered = await _capture(viewer, "unproject_render$i");
        var renderPng =
            await pixelsToPng(rendered, dimensions.width, dimensions.height);

        File("${outDir.path}/unproject_render${i}.png")
            .writeAsBytesSync(renderPng);
      }

      // then go off and convert the video

      // now unproject the render back onto the geometry
      final textureSize = (width: 1280, height: 768);
      var pixels = <Uint8List>[];
      // note we skip the first frame
      for (int i = 0; i < numFrames; i++) {
        await viewer.setCameraPosition(-3 + (i / numFrames * 2), 4, 6);

        await viewer.setCameraRotation(
            Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
                Quaternion.axisAngle(
                    Vector3(1, 0, 0), -pi / 6 - (i / numFrames * pi / 6)));

        var input = pngToPixelBuffer(File(
                "${outDir.path}/a8c317af-6081-4848-8a06-f6b69bc57664_${i + 1}.png")
            .readAsBytesSync());
        var pixelBuffer = await (await viewer as ThermionViewerFFI).unproject(
            cube,
            input,
            dimensions.width,
            dimensions.height,
            textureSize.width,
            textureSize.height);

        // var png = await pixelsToPng(Uint8List.fromList(pixelBuffer),
        //     dimensions.width, dimensions.height);

        await savePixelBufferToBmp(
            pixelBuffer,
            textureSize.width,
            textureSize.height,
            p.join(outDir.path, "unprojected_texture${i}.bmp"));

        pixels.add(pixelBuffer);

        if (i > 10) {
          break;
        }
      }

      // }

      final aggregatePixelBuffer = medianImages(pixels);
      await savePixelBufferToBmp(aggregatePixelBuffer, textureSize.width,
          textureSize.height, "unproject_texture.bmp");
      var pixelBufferPng = await pixelsToPng(
          Uint8List.fromList(aggregatePixelBuffer),
          dimensions.width,
          dimensions.height);
      File("${outDir.path}/unproject_texture.png")
          .writeAsBytesSync(pixelBufferPng);

      await viewer.setPostProcessing(true);
      await viewer.setToneMapping(ToneMapper.LINEAR);

      final unlit = await viewer.createUnlitMaterialInstance();
      await viewer.removeEntity(cube);
      cube = await viewer.createGeometry(GeometryHelper.cube(),
          materialInstance: unlit);
      var reconstructedTexture = await viewer.createTexture(pixelBufferPng);
      await viewer.applyTexture(reconstructedTexture, cube);

      await viewer.setCameraRotation(
          Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
              Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 6));
      await _capture(viewer, "unproject_reconstruct");

      // now re-render
      for (int i = 0; i < numFrames; i++) {
        await viewer.setCameraPosition(-3 + (i / numFrames * 2), 4, 6);

        await viewer.setCameraRotation(
            Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
                Quaternion.axisAngle(
                    Vector3(1, 0, 0), -pi / 6 - (i / numFrames * pi / 6)));

        var rendered = await _capture(viewer, "unproject_rerender$i");
        var renderPng =
            await pixelsToPng(rendered, dimensions.width, dimensions.height);

        File("${outDir.path}/unproject_rerender${i}.png")
            .writeAsBytesSync(renderPng);
      }
    }, timeout: Timeout(Duration(minutes: 2)));
  });
}

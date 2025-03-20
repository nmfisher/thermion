// ignore_for_file: unused_local_variable
import 'dart:io';
import 'dart:math';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("geometry");
  await testHelper.setup();
  group("custom geometry", () {
    test('create cube (uvs only)', () async {
      var viewer = await testHelper.createViewer();
      await viewer
          .createGeometry(GeometryHelper.cube(normals: false, uvs: true));
      await testHelper.capture(viewer, "geometry_cube_with_uvs");
    });
    test('create cube with normals & uvs', () async {
      var viewer = await testHelper.createViewer();
      await viewer
          .createGeometry(GeometryHelper.cube(normals: true, uvs: true));
      await testHelper.capture(viewer, "geometry_cube_with_normals_uvs");
    });

    test('create cube (no normals/uvs)', () async {
      await testHelper.withViewer((viewer) async {
        var viewMatrix =
            makeViewMatrix(Vector3(0, 2, 5), Vector3.zero(), Vector3(0, 1, 0));
        viewMatrix.invert();
        await viewer.setCameraModelMatrix4(viewMatrix);
        final cube = await viewer
            .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
        await testHelper.capture(viewer, "geometry_cube_no_normals_uvs");
        await viewer.destroyAsset(cube);
        await testHelper.capture(viewer, "geometry_remove_cube");
      });
    });

    test('create cube with unlit ubershader material (no normals/uvs)',
        () async {
      await testHelper.withViewer((viewer) async {
        final materialInstance =
            await viewer.createUbershaderMaterialInstance(unlit: true);
        await materialInstance.setParameterFloat4(
            "baseColorFactor", 1.0, 0.0, 0.0, 1.0);
        final cube = await viewer.createGeometry(
            GeometryHelper.cube(normals: false, uvs: false),
            materialInstances: [materialInstance]);
        await testHelper.capture(viewer, "geometry_cube_ubershader");
      });
    });

    test('create cube with lit ubershader material (normals/ no uvs)',
        () async {
      await testHelper.withViewer((viewer) async {
        final materialInstance = await viewer.createUbershaderMaterialInstance(
            unlit: false, alphaMode: AlphaMode.BLEND, hasVertexColors: false);
        await materialInstance.setParameterFloat4(
            "baseColorFactor", 1.0, 0.0, 0.0, 1.0);
        final cube = await viewer.createGeometry(
            GeometryHelper.cube(normals: true, uvs: false),
            materialInstances: [materialInstance]);

        await viewer.addDirectLight(DirectLight.sun(
            intensity: 100000,
            castShadows: false,
            direction: Vector3(0, -0.5, -1)));
        // await viewer.addDirectLight(DirectLight.spot(
        //   intensity: 1000000,
        //   position: Vector3(0,3,3),
        //   direction: Vector3(0,-1.5,-1),
        //   falloffRadius: 10));
        await materialInstance.setParameterFloat4(
            "baseColorFactor", 1.0, 0.0, 0.0, 1.0);
        await testHelper.capture(viewer, "geometry_cube_lit_ubershader");
      });
    });

    test('create instance', () async {
      await testHelper.withViewer((viewer) async {
        final cube = await viewer
            .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
        await viewer.setTransform(
            cube.entity, Matrix4.translation(Vector3.all(-1)));
        final instance = await cube.createInstance();
        await instance.addToScene();
        await viewer.setTransform(
            instance.entity, Matrix4.translation(Vector3.all(1)));

        await testHelper.capture(viewer, "geometry_instanced");
        await viewer.destroyAsset(instance);
        await testHelper.capture(viewer, "geometry_instance_removed");
      });
    });

    test('create instance (shared material)', () async {
      await testHelper.withViewer((viewer) async {
        final materialInstance = await viewer.createUnlitMaterialInstance();
        await materialInstance.setParameterFloat4(
            "baseColorFactor", 1.0, 0.0, 0.0, 1.0);
        final cube = await viewer.createGeometry(
            GeometryHelper.cube(normals: true, uvs: false),
            materialInstances: [materialInstance]);

        final instance = await cube.createInstance();
        await instance.addToScene();
        await viewer.setTransform(
            instance.entity, Matrix4.translation(Vector3.all(1)));

        await testHelper.capture(
            viewer, "geometry_instanced_with_shared_material");
      });
    });

    // test('create instance (no material on second instance)', () async {
    //   await testHelper.withViewer((viewer) async {
    //     final materialInstance = await viewer.createUnlitMaterialInstance();
    //     await materialInstance.setParameterFloat4(
    //         "baseColorFactor", 1.0, 0.0, 0.0, 1.0);
    //     final cube = await viewer.createGeometry(
    //         GeometryHelper.cube(normals: true, uvs: false),
    //         materialInstances: [materialInstance]);

    //     final instance = await viewer
    //         .createInstance(cube);
    //     await viewer.setTransform(
    //         instance.entity, Matrix4.translation(Vector3.all(1)));

    //     await testHelper.capture(
    //         viewer, "geometry_instanced_with_no_material_instance");
    //   });
    // });

    // test('create instance (separate materials)', () async {
    //   await testHelper.withViewer((viewer) async {
    //     final materialInstance = await viewer.createUnlitMaterialInstance();
    //     await materialInstance.setParameterFloat4(
    //         "baseColorFactor", 1.0, 0.0, 0.0, 1.0);
    //     final cube = await viewer.createGeometry(
    //         GeometryHelper.cube(normals: true, uvs: false),
    //         materialInstances: [materialInstance]);

    //     final materialInstance2 = await viewer.createUnlitMaterialInstance();
    //     await materialInstance2.setParameterFloat4(
    //         "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
    //     final instance = await viewer
    //         .createInstance(cube, materialInstances: [materialInstance2]);
    //     await viewer.setTransform(
    //         instance.entity, Matrix4.translation(Vector3.all(1)));

    //     await testHelper.capture(
    //         viewer, "geometry_instanced_with_separate_material_instances");
    //   });
    // });

    test('create cube with custom ubershader material (color)', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.addLight(LightType.SUN, 6500, 1000000, 0, 0, 0, 0, 0, -1);
        await viewer.setCameraPosition(0, 2, 6);
        await viewer
            .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
        await viewer.setBackgroundColor(1.0, 0.0, 1.0, 1.0);

        var materialInstance =
            await viewer.createUbershaderMaterialInstance(unlit: true);
        final cube = await viewer.createGeometry(
            GeometryHelper.cube(uvs: false, normals: true),
            materialInstances: [materialInstance]);
        await materialInstance.setParameterFloat4(
            "baseColorFactor", 0.0, 1.0, 0.0, 0.0);
        await testHelper.capture(
            viewer, "geometry_cube_with_custom_material_ubershader");
        await viewer.destroyAsset(cube);
      });
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
          materialInstances: [materialInstance]);
      final image = await viewer.decodeImage(
          File("${testHelper.testDir}/assets/cube_texture_512x512.png")
              .readAsBytesSync());
      var texture = await viewer.createTexture(
          await image.getWidth(), await image.getHeight());
      await texture.setLinearImage(
          image, PixelDataFormat.RGBA, PixelDataType.FLOAT);
      await testHelper.capture(
          viewer, "geometry_cube_with_custom_material_ubershader_texture");
      await viewer.destroyAsset(cube);
      await texture.dispose();
      await image.destroy();
    });

    test('unlit material with color only', () async {
      await testHelper.withViewer((viewer) async {
        var materialInstance = await viewer.createUnlitMaterialInstance();
        var cube = await viewer.createGeometry(GeometryHelper.cube(),
            materialInstances: [materialInstance]);

        await materialInstance.setParameterFloat4(
            "baseColorFactor", 0.0, 1.0, 0.0, 1.0);

        await testHelper.capture(viewer, "unlit_material_base_color");
      });
    });

    test('unlit material with texture', () async {
      await testHelper.withViewer((viewer) async {
        var materialInstance = await viewer.createUnlitMaterialInstance();
        var cube = await viewer.createGeometry(GeometryHelper.cube(),
            materialInstances: [materialInstance]);

        await materialInstance.setParameterInt("baseColorIndex", 0);

        final image = await viewer.decodeImage(
            File("${testHelper.testDir}/assets/cube_texture_512x512.png")
                .readAsBytesSync());
        var texture = await viewer.createTexture(
            await image.getWidth(), await image.getHeight());
        await texture.setLinearImage(
            image, PixelDataFormat.RGBA, PixelDataType.FLOAT);
        await testHelper.capture(viewer, "unlit_material_texture_only");
        await viewer.destroyAsset(cube);
      });
    });

    test('shared material instance with texture and base color', () async {
      await testHelper.withViewer((viewer) async {
        var materialInstance = await viewer.createUnlitMaterialInstance();
        var cube1 = await viewer.createGeometry(GeometryHelper.cube(),
            materialInstances: [materialInstance]);
        var cube2 = await viewer.createGeometry(GeometryHelper.cube(),
            materialInstances: [materialInstance]);
        await viewer.setTransform(
            cube2.entity, Matrix4.translation(Vector3(1, 1, 1)));

        await materialInstance.setParameterInt("baseColorIndex", 0);
        final image = await viewer.decodeImage(
            File("${testHelper.testDir}/assets/cube_texture_512x512.png")
                .readAsBytesSync());
        var texture = await viewer.createTexture(
            await image.getWidth(), await image.getHeight());
        await texture.setLinearImage(
            image, PixelDataFormat.RGBA, PixelDataType.FLOAT);

        await testHelper.capture(viewer, "unlit_material_shared");
        await texture.dispose();
        await image.destroy();
      });
    });

    test('create sphere (no normals)', () async {
      await testHelper.withViewer((viewer) async {
        await viewer
            .createGeometry(GeometryHelper.sphere(normals: false, uvs: false));
        await testHelper.capture(viewer, "geometry_sphere_no_normals");
      }, bg: kBlue, cameraPosition: Vector3(0, 0, 6));
    });

    test('create multiple (non-instanced) geometry', () async {
      await testHelper.withViewer((viewer) async {
        final cube1 = await viewer
            .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
        final cube2 = await viewer
            .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
        await viewer.setTransform(
            cube2.entity, Matrix4.translation(Vector3(0, 1.5, 0)));
        await testHelper.capture(viewer, "multiple_geometry");
      }, bg: kRed);
    });

    test('create camera geometry', () async {
      await testHelper.withViewer((viewer) async {
        final camera = await viewer.createGeometry(
            GeometryHelper.wireframeCamera(normals: false, uvs: false));
        await viewer.setTransform(camera.entity, Matrix4.rotationY(pi / 4));
        await testHelper.capture(viewer, "camera_geometry");
      });
    });
  });
}

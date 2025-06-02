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
    test('add/remove geometry', () async {
      await testHelper.withViewer((viewer) async {
        final asset = await viewer.createGeometry(GeometryHelper.cube());
        await viewer.addToScene(asset);
        await testHelper.capture(viewer.view, "add_geometry");
        await viewer.removeFromScene(asset);
        await testHelper.capture(viewer.view, "remove_geometry");
        await viewer.addToScene(asset);
        await viewer.destroyAsset(asset);
        await testHelper.capture(viewer.view, "destroy_geometry");
      }, bg: kRed);
    });

    test('ensure geometry is removed when destroyAll is called ', () async {
      await testHelper.withViewer((viewer) async {
        final asset = await viewer.createGeometry(GeometryHelper.cube());
        await viewer.addToScene(asset);
        await viewer.destroyAssets();
        await testHelper.capture(viewer.view, "destroyAssets_geometry");
      }, bg: kRed);
    });

    test('custom geometry (no normals/uvs)', () async {
      await testHelper.withViewer((viewer) async {
        final asset = await viewer
            .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
        await viewer.addToScene(asset);
        await testHelper.capture(viewer.view, "geometry_cube_no_normals_uvs");
        await viewer.removeFromScene(asset);
        await viewer.destroyAsset(asset);
      });
    });

    test('geometry with unlit (ubershader) material', () async {
      await testHelper.withViewer((viewer) async {
        final materialInstance = await FilamentApp.instance!
            .createUbershaderMaterialInstance(unlit: true);
        await materialInstance.setParameterFloat4(
            "baseColorFactor", 1.0, 0.0, 0.0, 1.0);

        final asset = await viewer.createGeometry(
            GeometryHelper.cube(normals: false, uvs: false),
            materialInstances: [materialInstance]);
        await viewer.addToScene(asset);
        await testHelper.capture(viewer.view, "geometry_cube_ubershader_red");
        await materialInstance.setParameterFloat4(
            "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
        await testHelper.capture(viewer.view, "geometry_cube_ubershader_green");
        await viewer.removeFromScene(asset);
        await viewer.destroyAsset(asset);
      });
    });

    // test('create cube with lit ubershader material (normals/ no uvs)',
    //     () async {
    //   await testHelper.withViewer((viewer) async {
    //     final materialInstance = await viewer.createUbershaderMaterialInstance(
    //         unlit: false, alphaMode: AlphaMode.BLEND, hasVertexColors: false);
    //     await materialInstance.setParameterFloat4(
    //         "baseColorFactor", 1.0, 0.0, 0.0, 1.0);

    //     final asset = await viewer.createGeometry(
    //         GeometryHelper.cube(normals: true, uvs: false),
    //         materialInstances: [materialInstance]);
    //     await viewer.addToScene(asset);

    //     await viewer.addDirectLight(DirectLight.sun(
    //         intensity: 100000,
    //         castShadows: false,
    //         direction: Vector3(0, -0.5, -1)));
    //     // await viewer.addDirectLight(DirectLight.spot(
    //     //   intensity: 1000000,
    //     //   position: Vector3(0,3,3),
    //     //   direction: Vector3(0,-1.5,-1),
    //     //   falloffRadius: 10));
    //     await materialInstance.setParameterFloat4(
    //         "baseColorFactor", 1.0, 0.0, 0.0, 1.0);
    //     await testHelper.capture(viewer.view, "geometry_cube_lit_ubershader");
    //     await viewer.removeFromScene(asset);
    //     await viewer.destroyAsset(asset);
    //   });
    // });

    // test('create instance', () async {
    //   await testHelper.withViewer((viewer) async {
    //     final asset = await viewer
    //         .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
    //     await viewer.addToScene(asset);
    //     await asset.setTransform(Matrix4.translation(Vector3.all(-1)));

    //     final instance = await asset.createInstance();
    //     await viewer.addToScene(instance);
    //     await instance.setTransform(Matrix4.translation(Vector3.all(1)));

    //     await testHelper.capture(viewer.view, "geometry_instanced");
    //     await viewer.destroyAsset(instance);
    //     await viewer.removeFromScene(asset);
    //     await viewer.destroyAsset(asset);
    //   });
    // });

    // test('create instance (shared material)', () async {
    //   await testHelper.withViewer((viewer) async {
    //     final materialInstance = await viewer.createUnlitMaterialInstance();
    //     await materialInstance.setParameterFloat4(
    //         "baseColorFactor", 1.0, 0.0, 0.0, 1.0);

    //     final asset = await viewer.createGeometry(
    //         GeometryHelper.cube(normals: true, uvs: false),
    //         materialInstances: [materialInstance]);
    //     await viewer.addToScene(asset);

    //     final instance = await asset.createInstance();
    //     await instance.addToScene();
    //     await viewer.setTransform(
    //         instance.entity, Matrix4.translation(Vector3.all(1)));

    //     await testHelper.capture(
    //         viewer.view, "geometry_instanced_with_shared_material");
    //     await viewer.destroyAsset(instance);
    //     await viewer.removeFromScene(asset);
    //     await viewer.destroyAsset(asset);
    //   });
    // });

    // // test('create instance (no material on second instance)', () async {
    // //   await testHelper.withViewer((viewer) async {
    // //     final materialInstance = await viewer.createUnlitMaterialInstance();
    // //     await materialInstance.setParameterFloat4(
    // //         "baseColorFactor", 1.0, 0.0, 0.0, 1.0);
    // //     final asset = await viewer.createGeometry(
    // //         GeometryHelper.cube(normals: true, uvs: false),
    // //         materialInstances: [materialInstance]);
    // //     await viewer.addToScene(asset);

    // //     final instance = await viewer.createInstance(asset);
    // //     await instance.addToScene();
    // //     await viewer.setTransform(instance.entity, Matrix4.translation(Vector3.all(1)));

    // //     await testHelper.capture(viewer.view, "geometry_instanced_with_no_material_instance");
    // //     await viewer.destroyAsset(instance);
    // //     await viewer.removeFromScene(asset);
    // //     await viewer.destroyAsset(asset);
    // //   });
    // // });

    // // test('create instance (separate materials)', () async {
    // //   await testHelper.withViewer((viewer) async {
    // //     final materialInstance = await viewer.createUnlitMaterialInstance();
    // //     await materialInstance.setParameterFloat4(
    // //         "baseColorFactor", 1.0, 0.0, 0.0, 1.0);
    // //     final asset = await viewer.createGeometry(
    // //         GeometryHelper.cube(normals: true, uvs: false),
    // //         materialInstances: [materialInstance]);
    // //     await viewer.addToScene(asset);

    // //     final materialInstance2 = await viewer.createUnlitMaterialInstance();
    // //     await materialInstance2.setParameterFloat4(
    // //         "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
    // //     final instance = await viewer.createInstance(asset, materialInstances: [materialInstance2]);
    // //     await instance.addToScene();
    // //     await viewer.setTransform(instance.entity, Matrix4.translation(Vector3.all(1)));

    // //     await testHelper.capture(viewer.view, "geometry_instanced_with_separate_material_instances");
    // //     await viewer.destroyAsset(instance);
    // //     await viewer.removeFromScene(asset);
    // //     await viewer.destroyAsset(asset);
    // //   });
    // // });

    // test('create cube with custom ubershader material (color)', () async {
    //   await testHelper.withViewer((viewer) async {
    //     await viewer.addLight(LightType.SUN, 6500, 1000000, 0, 0, 0, 0, 0, -1);
    //     await viewer.setCameraPosition(0, 2, 6);
    //     await viewer
    //         .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
    //     await viewer.setBackgroundColor(1.0, 0.0, 1.0, 1.0);

    //     var materialInstance =
    //         await viewer.createUbershaderMaterialInstance(unlit: true);
    //     final asset = await viewer.createGeometry(
    //         GeometryHelper.cube(uvs: false, normals: true),
    //         materialInstances: [materialInstance]);
    //     await viewer.addToScene(asset);
    //     await materialInstance.setParameterFloat4(
    //         "baseColorFactor", 0.0, 1.0, 0.0, 0.0);

    //     await testHelper.capture(
    //         viewer.view, "geometry_cube_with_custom_material_ubershader");
    //     await viewer.removeFromScene(asset);
    //     await viewer.destroyAsset(asset);
    //   });
    // });

    // test('create cube with custom ubershader material instance (texture)',
    //     () async {
    //   await testHelper.withViewer((viewer) async {
    //     await viewer.addLight(LightType.SUN, 6500, 1000000, 0, 0, 0, 0, 0, -1);
    //     await viewer.setCameraPosition(0, 2, 6);
    //     await viewer
    //         .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
    //     await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);

    //     var materialInstance = await viewer.createUbershaderMaterialInstance();
    //     final asset = await viewer.createGeometry(
    //         GeometryHelper.cube(uvs: true, normals: true),
    //         materialInstances: [materialInstance]);
    //     await viewer.addToScene(asset);

    //     final image = await viewer.decodeImage(
    //         File("${testHelper.testDir}/assets/cube_texture_512x512.png")
    //             .readAsBytesSync());
    //     var texture = await viewer.createTexture(
    //         await image.getWidth(), await image.getHeight());
    //     await texture.setLinearImage(
    //         image, PixelDataFormat.RGBA, PixelDataType.FLOAT);

    //     await testHelper.capture(viewer.view,
    //         "geometry_cube_with_custom_material_ubershader_texture");
    //     await viewer.removeFromScene(asset);
    //     await viewer.destroyAsset(asset);
    //     await texture.dispose();
    //     await image.destroy();
    //   });
    // });

    // test('unlit material with color only', () async {
    //   await testHelper.withViewer((viewer) async {
    //     var materialInstance = await viewer.createUnlitMaterialInstance();
    //     final asset = await viewer.createGeometry(GeometryHelper.cube(),
    //         materialInstances: [materialInstance]);
    //     await viewer.addToScene(asset);

    //     await materialInstance.setParameterFloat4(
    //         "baseColorFactor", 0.0, 1.0, 0.0, 1.0);

    //     await testHelper.capture(viewer.view, "unlit_material_base_color");
    //     await viewer.removeFromScene(asset);
    //     await viewer.destroyAsset(asset);
    //   });
    // });

    // test('unlit material with texture', () async {
    //   await testHelper.withViewer((viewer) async {
    //     var materialInstance = await viewer.createUnlitMaterialInstance();
    //     final asset = await viewer.createGeometry(GeometryHelper.cube(),
    //         materialInstances: [materialInstance]);
    //     await viewer.addToScene(asset);

    //     await materialInstance.setParameterInt("baseColorIndex", 0);

    //     final image = await viewer.decodeImage(
    //         File("${testHelper.testDir}/assets/cube_texture_512x512.png")
    //             .readAsBytesSync());
    //     var texture = await viewer.createTexture(
    //         await image.getWidth(), await image.getHeight());
    //     await texture.setLinearImage(
    //         image, PixelDataFormat.RGBA, PixelDataType.FLOAT);

    //     await testHelper.capture(viewer.view, "unlit_material_texture_only");
    //     await viewer.removeFromScene(asset);
    //     await viewer.destroyAsset(asset);
    //     await texture.dispose();
    //     await image.destroy();
    //   });
    // });

    // test('shared material instance with texture and base color', () async {
    //   await testHelper.withViewer((viewer) async {
    //     var materialInstance = await viewer.createUnlitMaterialInstance();

    //     final asset1 = await viewer.createGeometry(GeometryHelper.cube(),
    //         materialInstances: [materialInstance]);
    //     await viewer.addToScene(asset1);

    //     final asset2 = await viewer.createGeometry(GeometryHelper.cube(),
    //         materialInstances: [materialInstance]);
    //     await viewer.addToScene(asset2);
    //     await viewer.setTransform(
    //         asset2.entity, Matrix4.translation(Vector3(1, 1, 1)));

    //     await materialInstance.setParameterInt("baseColorIndex", 0);
    //     final image = await viewer.decodeImage(
    //         File("${testHelper.testDir}/assets/cube_texture_512x512.png")
    //             .readAsBytesSync());
    //     var texture = await viewer.createTexture(
    //         await image.getWidth(), await image.getHeight());
    //     await texture.setLinearImage(
    //         image, PixelDataFormat.RGBA, PixelDataType.FLOAT);

    //     await testHelper.capture(viewer.view, "unlit_material_shared");
    //     await viewer.removeFromScene(asset1);
    //     await viewer.destroyAsset(asset1);
    //     await viewer.removeFromScene(asset2);
    //     await viewer.destroyAsset(asset2);
    //     await texture.dispose();
    //     await image.destroy();
    //   });
    // });

    // test('create sphere (no normals)', () async {
    //   await testHelper.withViewer((viewer) async {
    //     final asset = await viewer
    //         .createGeometry(GeometryHelper.sphere(normals: false, uvs: false));
    //     await viewer.addToScene(asset);
    //     await testHelper.capture(viewer.view, "geometry_sphere_no_normals");
    //     await viewer.removeFromScene(asset);
    //     await viewer.destroyAsset(asset);
    //   }, bg: kBlue, cameraPosition: Vector3(0, 0, 6));
    // });

    // test('create multiple (non-instanced) geometry', () async {
    //   await testHelper.withViewer((viewer) async {
    //     final asset1 = await viewer
    //         .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
    //     await viewer.addToScene(asset1);

    //     final asset2 = await viewer
    //         .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
    //     await viewer.addToScene(asset2);
    //     await viewer.setTransform(
    //         asset2.entity, Matrix4.translation(Vector3(0, 1.5, 0)));

    //     await testHelper.capture(viewer.view, "multiple_geometry");
    //     await viewer.removeFromScene(asset1);
    //     await viewer.destroyAsset(asset1);
    //     await viewer.removeFromScene(asset2);
    //     await viewer.destroyAsset(asset2);
    //   }, bg: kRed);
    // });

    // test('create camera geometry', () async {
    //   await testHelper.withViewer((viewer) async {
    //     final asset = await viewer.createGeometry(
    //         GeometryHelper.wireframeCamera(normals: false, uvs: false));
    //     await viewer.addToScene(asset);
    //     await viewer.setTransform(asset.entity, Matrix4.rotationY(pi / 4));

    //     await testHelper.capture(viewer.view, "camera_geometry");
    //     await viewer.removeFromScene(asset);
    //     await viewer.destroyAsset(asset);
    //   });
    // });
  });
}

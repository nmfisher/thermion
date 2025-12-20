import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("geometry");
  await testHelper.setup();

  test('add/remove geometry', () async {
    await ViewerBuilder(testHelper)
        .setBackgroundColor(kRed)
        .execute((result) async {
      final asset = await result.viewer.createGeometry(GeometryHelper.cube());
      await result.viewer.addToScene(asset);
      await testHelper.capture(result.viewer.view, "add_cube");
      await result.viewer.removeFromScene(asset);
      await testHelper.capture(result.viewer.view, "remove_cube");
      await result.viewer.addToScene(asset);
      await result.viewer.destroyAsset(asset);
      await testHelper.capture(result.viewer.view, "destroy_cube");
    });
  });

  test('update vertex buffer', () async {
    await ViewerBuilder(testHelper)
        .setBackgroundColor(kRed)
        .execute((result) async {
      final asset = await result.viewer.createGeometry(GeometryHelper.cube());
      await result.viewer.addToScene(asset);
      await testHelper.capture(result.viewer.view, "update_vertex_buffer_1");
      final vb = await asset.getVertexBuffer();
      expect(vb, isNotNull);
      final vertices = Float32List.fromList([
      // Front face
      -1, -1, 1, // 0
      1, -1, 1, // 1
      2, 2, 2, // 2
      -1, 1, 1, // 3

      // Back face
      -1, -1, -1, // 4
      1, -1, -1, // 5
      1, 1, -1, // 6
      -1, 1, -1, // 7

      // Top face
      -1, 1, 1, // 3 (8)
      2, 2, 2, //2 (9)
      1, 1, -1, //6 (10)
      -1, 1, -1, // 7 (11)

      // Bottom
      -1, -1, -1, // 4 (12)
      1, -1, -1, // 5 (13)
      1, -1, 1, // 1 (14)
      -1, -1, 1, // 0 (15)

      // Right
      1, -1, 1, // 1 (16)
      1, -1, -1, // 5 (17)
      1, 1, -1, // 6 (18)
      2, 2, 2, // 2 (19)

      // Left
      -1, -1, -1, // 4 (20)
      -1, -1, 1, // 0 (21)
      -1, 1, 1, // 3 (22)
      -1, 1, -1 // 7 (23)
    ]);
      await vb!.setBufferAt(0, vertices);
      await testHelper.capture(result.viewer.view, "update_vertex_buffer_2");
    });
  });

  test('material with vertexDomain: view', () async {
    await ViewerBuilder(testHelper)
        .setBackgroundColor(kBlue)
        .setCameraLookAt(Vector3(0, 0, 0), focus: Vector3(0, 0, -1))
        .execute((result) async {
      var material = await testHelper.loadViewSpaceMateral();
      await material.setCullingMode(CullingMode.NONE);
      var geo = await Geometry(
          Float32List.fromList([-1, -1, -15, 1, -1, -15, 1, 1, -15]),
          Int16List.fromList([0, 1, 2]));
      await result.viewer.setViewFrustumCulling(false);
      await result.viewer.createGeometry(geo, materialInstances: [material]);

      await testHelper.capture(result.viewer.view, "vertex_domain_view");
    });
  });

  test('material with custom0 attribute: view', () async {
    await ViewerBuilder(testHelper)
        .setBackgroundColor(kBlue)
        .setCameraLookAt(Vector3(0, 0, 0), focus: Vector3(0, 0, -1))
        .execute((result) async {
      var material = await testHelper.loadCustomAttributeMaterial();
      await material.setCullingMode(CullingMode.NONE);
      var geo = await Geometry(
        // these vertices don't matter since we're going to use the custom0
        // attribute to set the position in the shader. We just need to make
        // sure Filament can calculate a non-degenerate bounding box.
        Float32List.fromList([0, 1, 2, 0, 10, 20, 0, 20, 30]),
        Int16List.fromList([0, 1, 2]),
        attribute0:
            Float32List.fromList([-1, -1, -15, 0, 1, -1, -15, 0, 1, 1, -15, 0]),
      );
      await result.viewer.setViewFrustumCulling(false);
      await result.viewer.createGeometry(geo, materialInstances: [material]);

      await testHelper.capture(result.viewer.view, "custom_attribute");
    });
  });

  test('ensure geometry is removed when destroyAll is called ', () async {
    await ViewerBuilder(testHelper)
        .setBackgroundColor(kRed)
        .execute((result) async {
      final asset = await result.viewer.createGeometry(GeometryHelper.cube());
      await result.viewer.addToScene(asset);
      await result.viewer.destroyAssets();
      await testHelper.capture(result.viewer.view, "destroyAssets_cube");
    });
  });

  test('custom geometry (no normals/uvs)', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final asset = await result.viewer
          .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
      await result.viewer.addToScene(asset);
      await testHelper.capture(
          result.viewer.view, "geometry_cube_no_normals_uvs");
      await result.viewer.removeFromScene(asset);
      await result.viewer.destroyAsset(asset);
    });
  });

  test('geometry with unlit (ubershader) material', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final materialInstance = await FilamentApp.instance!
          .createUbershaderMaterialInstance(unlit: true);
      await materialInstance.setParameterFloat4(
          "baseColorFactor", 1.0, 0.0, 0.0, 1.0);

      final asset = await result.viewer.createGeometry(
          GeometryHelper.cube(normals: false, uvs: false),
          materialInstances: [materialInstance]);
      await result.viewer.addToScene(asset);
      await testHelper.capture(
          result.viewer.view, "geometry_cube_ubershader_red");
      await materialInstance.setParameterFloat4(
          "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
      await testHelper.capture(
          result.viewer.view, "geometry_cube_ubershader_green");
      await result.viewer.removeFromScene(asset);
      await result.viewer.destroyAsset(asset);
    });
  });

  test('wireframe shader test', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      // Load the wireframe material
      final materialInstance = await testHelper.loadWireframeMaterial(
          edgeR: 1.0, edgeG: 0.0, edgeB: 0.0, edgeA: 1.0, // Red edges
          faceR: 0.0, faceG: 0.0, faceB: 1.0, faceA: 0.5, // Blue transparent faces
          edgeWidth: 2.0);

      // Create a cube with custom barycentric coordinates in UV0
      // Each triangle needs barycentric coordinates (1,0), (0,1), (0,0) for its vertices
      final vertices = Float32List.fromList([
        // Front face
        -1, -1,  1,   // 0
         1, -1,  1,   // 1
         1,  1,  1,   // 2
        -1,  1,  1,   // 3
        // Back face
        -1, -1, -1,   // 4
         1, -1, -1,   // 5
         1,  1, -1,   // 6
        -1,  1, -1,   // 7
      ]);

      final indices = Int16List.fromList([
        // Front face - two triangles
        0, 1, 2,  0, 2, 3,
        // Back face - two triangles
        4, 6, 5,  4, 7, 6,
        // Left face - two triangles
        4, 0, 3,  4, 3, 7,
        // Right face - two triangles
        1, 5, 6,  1, 6, 2,
        // Top face - two triangles
        3, 2, 6,  3, 6, 7,
        // Bottom face - two triangles
        4, 5, 1,  4, 1, 0,
      ]);

      // Create UV coordinates with barycentric data
      // For each triangle, the three vertices get (1,0), (0,1), (0,0) respectively
      final uvs = Float32List.fromList([
        // Front face
        1, 0,  // vertex 0 in triangle 0
        0, 1,  // vertex 1 in triangle 0
        0, 0,  // vertex 2 in triangle 0
        1, 0,  // vertex 0 in triangle 1
        0, 1,  // vertex 2 in triangle 1
        0, 0,  // vertex 3 in triangle 1
        // Back face
        1, 0,  // vertex 4 in triangle 2
        0, 1,  // vertex 6 in triangle 2
        0, 0,  // vertex 5 in triangle 2
        1, 0,  // vertex 4 in triangle 3
        0, 1,  // vertex 7 in triangle 3
        0, 0,  // vertex 6 in triangle 3
        // Left face
        1, 0,  // vertex 4 in triangle 4
        0, 1,  // vertex 0 in triangle 4
        0, 0,  // vertex 3 in triangle 4
        1, 0,  // vertex 4 in triangle 5
        0, 1,  // vertex 3 in triangle 5
        0, 0,  // vertex 7 in triangle 5
        // Right face
        1, 0,  // vertex 1 in triangle 6
        0, 1,  // vertex 5 in triangle 6
        0, 0,  // vertex 6 in triangle 6
        1, 0,  // vertex 1 in triangle 7
        0, 1,  // vertex 2 in triangle 7
        0, 0,  // vertex 6 in triangle 7
        // Top face
        1, 0,  // vertex 3 in triangle 8
        0, 1,  // vertex 2 in triangle 8
        0, 0,  // vertex 6 in triangle 8
        1, 0,  // vertex 3 in triangle 9
        0, 1,  // vertex 6 in triangle 9
        0, 0,  // vertex 7 in triangle 9
        // Bottom face
        1, 0,  // vertex 4 in triangle 10
        0, 1,  // vertex 5 in triangle 10
        0, 0,  // vertex 1 in triangle 10
        1, 0,  // vertex 4 in triangle 11
        0, 1,  // vertex 1 in triangle 11
        0, 0,  // vertex 0 in triangle 11
      ]);

      final geometry = Geometry(
        vertices,
        indices,
        uvs: uvs,
      );

      final asset = await result.viewer.createGeometry(
          geometry,
          materialInstances: [materialInstance]);
      await result.viewer.addToScene(asset);
      await testHelper.capture(result.viewer.view, "geometry_cube_wireframe");
      await result.viewer.removeFromScene(asset);
      await result.viewer.destroyAsset(asset);
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

  //     await testHelper.capture(viewer.view, "multiple_cube");
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

  //     await testHelper.capture(viewer.view, "camera_cube");
  //     await viewer.removeFromScene(asset);
  //     await viewer.destroyAsset(asset);
  //   });
  // });
}

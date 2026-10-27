import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("geometry");
  await testHelper.setup();

  test('add/remove geometry', () async {
    await ViewerBuilder(testHelper).setBackgroundColor(kRed).execute((result) async {
      final asset = await result.viewer.createGeometry(GeometryUtils.cube());
      expect(asset.type, SceneAssetType.geometry);
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
    await ViewerBuilder(testHelper).setBackgroundColor(kRed).execute((result) async {
      final asset = await result.viewer.createGeometry(GeometryUtils.cube());
      await result.viewer.addToScene(asset);
      await testHelper.capture(result.viewer.view, "update_vertex_buffer_1");
      final vb = await asset.getVertexBuffer();
      expect(vb, isNotNull);
      expect(vb!.storageMode, VertexBufferStorageMode.direct);
      expect(
        asset.geometryCapabilities,
        containsAll(const {
          SceneAssetGeometryCapability.accessibleGeometryBuffers,
          SceneAssetGeometryCapability.writableVertices,
        }),
      );
      await expectLater(vb.destroy(), throwsStateError);
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
        -1, 1, -1, // 7 (23)
      ]);
      await vb.setBufferAt(0, vertices);
      await testHelper.capture(result.viewer.view, "update_vertex_buffer_2");
    });
  });

  test('material with vertexDomain: view', () async {
    await ViewerBuilder(
      testHelper,
    ).setBackgroundColor(kBlue).setCameraLookAt(Vector3(0, 0, 0), focus: Vector3(0, 0, -1)).execute((result) async {
      var material = await testHelper.loadViewSpaceMaterial();
      await material.setCullingMode(CullingMode.NONE);
      var geo = await Geometry(
        Float32List.fromList([-1, -1, -15, 1, -1, -15, 1, 1, -15]),
        Int16List.fromList([0, 1, 2]),
      );
      await result.viewer.setViewFrustumCulling(false);
      await result.viewer.createGeometry(geo, materialInstances: [material]);

      await testHelper.capture(result.viewer.view, "vertex_domain_view");
    });
  });

  test('material with custom0 attribute: view', () async {
    await ViewerBuilder(
      testHelper,
    ).setBackgroundColor(kBlue).setCameraLookAt(Vector3(0, 0, 0), focus: Vector3(0, 0, -1)).execute((result) async {
      var material = await testHelper.loadCustomAttributeMaterial();
      await material.setCullingMode(CullingMode.NONE);
      var geo = await Geometry(
        // these vertices don't matter since we're going to use the custom0
        // attribute to set the position in the shader. We just need to make
        // sure Filament can calculate a non-degenerate bounding box.
        Float32List.fromList([0, 1, 2, 0, 10, 20, 0, 20, 30]),
        Int16List.fromList([0, 1, 2]),
        attribute0: Float32List.fromList([-1, -1, -15, 0, 1, -1, -15, 0, 1, 1, -15, 0]),
      );
      await result.viewer.setViewFrustumCulling(false);
      await result.viewer.createGeometry(geo, materialInstances: [material]);

      await testHelper.capture(result.viewer.view, "custom_attribute");
    });
  });

  test('ensure geometry is removed when destroyAll is called ', () async {
    await ViewerBuilder(testHelper).setBackgroundColor(kRed).execute((result) async {
      final asset = await result.viewer.createGeometry(GeometryUtils.cube());
      await result.viewer.addToScene(asset);
      await result.viewer.destroyAssets();
      await testHelper.capture(result.viewer.view, "destroyAssets_cube");
    });
  });

  test('custom geometry (no normals/uvs)', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final asset = await result.viewer.createGeometry(GeometryUtils.cube(normals: false, uvs: false));
      await result.viewer.addToScene(asset);
      await testHelper.capture(result.viewer.view, "geometry_cube_no_normals_uvs");
      await result.viewer.removeFromScene(asset);
      await result.viewer.destroyAsset(asset);
    });
  });

  test('geometry with unlit (ubershader) material', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final materialInstance = await FilamentApp.instance!.createUbershaderMaterialInstance(unlit: true);
      await materialInstance.setParameterFloat4("baseColorFactor", 1.0, 0.0, 0.0, 1.0);

      final asset = await result.viewer.createGeometry(
        GeometryUtils.cube(normals: false, uvs: false),
        materialInstances: [materialInstance],
      );
      await result.viewer.addToScene(asset);
      await testHelper.capture(result.viewer.view, "geometry_cube_ubershader_red");
      await materialInstance.setParameterFloat4("baseColorFactor", 0.0, 1.0, 0.0, 1.0);
      await testHelper.capture(result.viewer.view, "geometry_cube_ubershader_green");
      await result.viewer.removeFromScene(asset);
      await result.viewer.destroyAsset(asset);
    });
  });

  test('destroyAsset while destroyAssets is running', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final assets = [for (var i = 0; i < 3; i++) await result.viewer.createGeometry(GeometryUtils.cube())];

      // destroyAssets suspends inside its loop, so these calls run while it
      // is still iterating. Each asset must only be destroyed once.
      final destroyAll = result.viewer.destroyAssets();
      await Future.wait([destroyAll, for (final asset in assets) result.viewer.destroyAsset(asset)]);

      // Destroying an asset that was already destroyed is a no-op.
      await result.viewer.destroyAsset(assets.first);
    });
  });

  for (final destroyAll in [true, false]) {
    final operation = destroyAll ? 'destroyAssets' : 'destroyAsset(owner)';
    test('$operation before queued instance cleanup is safe', () async {
      await ViewerBuilder(testHelper).execute((result) async {
        final viewer = result.viewer;
        final asset = await viewer.createGeometry(GeometryUtils.cube());
        final instance = await asset.createInstance();
        final alias = (await asset.getInstances()).single;
        await viewer.addToScene(instance);
        final entities = [asset.entity, instance.entity];

        // The queued instance wrappers refer to native memory freed by the
        // owning asset's destruction. Neither wrapper may reach native code.
        final destroyOwner = destroyAll ? viewer.destroyAssets() : viewer.destroyAsset(asset);
        await Future.wait([destroyOwner, viewer.destroyAsset(instance), viewer.destroyAsset(alias)]);
        await viewer.destroyAsset(instance);

        for (final entity in entities) {
          expect(FilamentApp.instance!.renderableManager.hasComponent(entity), isFalse);
        }
      });
    });
  }

  test('app-created geometry stays app-owned when added to the viewer', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final app = FilamentApp.instance!;
      final asset = await app.createGeometry(GeometryUtils.cube());
      final instance = await asset.createInstance();
      final entity = asset.entity;
      final instanceEntity = instance.entity;
      await result.viewer.addToScene(asset);
      await result.viewer.addToScene(instance);
      try {
        await result.viewer.destroyAsset(asset);
        await result.viewer.destroyAsset(instance);
        await result.viewer.destroyAssets();
        expect(app.renderableManager.hasComponent(entity), isTrue);
        expect(app.renderableManager.hasComponent(instanceEntity), isTrue);

        await result.viewer.removeFromScene(instance);
        await result.viewer.removeFromScene(asset);
        await result.viewer.dispose();

        // Viewer cleanup after teardown cannot act on app-owned resources.
        await result.viewer.destroyAsset(asset);
        await result.viewer.destroyAsset(instance);
        await result.viewer.removeFromScene(asset);
        expect(app.renderableManager.hasComponent(entity), isTrue);
        expect(app.renderableManager.hasComponent(instanceEntity), isTrue);
      } finally {
        await app.destroyAsset(asset);
      }
      expect(app.renderableManager.hasComponent(entity), isFalse);
      expect(app.renderableManager.hasComponent(instanceEntity), isFalse);
    });
  });

  test('remove and destroy assets and lights while the viewer is disposed', () async {
    await ViewerBuilder(testHelper).execute((result) async {
      final viewer = result.viewer;
      final assets = [for (var i = 0; i < 3; i++) await viewer.createGeometry(GeometryUtils.cube())];
      final light = await viewer.addDirectLight(DirectLight.point());
      final entities = assets.map((asset) => asset.entity).toList();

      // App code often releases its own assets and lights while the viewer is
      // being disposed (e.g. in a parent widget's dispose()), or after.
      Future release() => Future.wait([
        for (final asset in assets) viewer.removeFromScene(asset).then((_) => viewer.destroyAsset(asset)),
        viewer.removeLight(light),
      ]);
      await Future.wait([viewer.dispose(), release()]);
      await release();
      for (final entity in entities) {
        expect(FilamentApp.instance!.renderableManager.hasComponent(entity), isFalse);
      }
      expect(FilamentApp.instance!.lightManager.hasComponent(light), isFalse);
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
  //         GeometryUtils.cube(normals: true, uvs: false),
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
  //         .createGeometry(GeometryUtils.cube(normals: false, uvs: false));
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
  //         GeometryUtils.cube(normals: true, uvs: false),
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
  // //         GeometryUtils.cube(normals: true, uvs: false),
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
  // //         GeometryUtils.cube(normals: true, uvs: false),
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
  //         GeometryUtils.cube(uvs: false, normals: true),
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
  //         GeometryUtils.cube(uvs: true, normals: true),
  //         materialInstances: [materialInstance]);
  //     await viewer.addToScene(asset);

  //     final image = await viewer.decodeImage(
  //         File("${testHelper.assetsDir}/cube_texture_512x512.png")
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
  //     final asset = await viewer.createGeometry(GeometryUtils.cube(),
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
  //     final asset = await viewer.createGeometry(GeometryUtils.cube(),
  //         materialInstances: [materialInstance]);
  //     await viewer.addToScene(asset);

  //     await materialInstance.setParameterInt("baseColorIndex", 0);

  //     final image = await viewer.decodeImage(
  //         File("${testHelper.assetsDir}/cube_texture_512x512.png")
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

  //     final asset1 = await viewer.createGeometry(GeometryUtils.cube(),
  //         materialInstances: [materialInstance]);
  //     await viewer.addToScene(asset1);

  //     final asset2 = await viewer.createGeometry(GeometryUtils.cube(),
  //         materialInstances: [materialInstance]);
  //     await viewer.addToScene(asset2);
  //     await viewer.setTransform(
  //         asset2.entity, Matrix4.translation(Vector3(1, 1, 1)));

  //     await materialInstance.setParameterInt("baseColorIndex", 0);
  //     final image = await viewer.decodeImage(
  //         File("${testHelper.assetsDir}/cube_texture_512x512.png")
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
  //         .createGeometry(GeometryUtils.sphere(normals: false, uvs: false));
  //     await viewer.addToScene(asset);
  //     await testHelper.capture(viewer.view, "geometry_sphere_no_normals");
  //     await viewer.removeFromScene(asset);
  //     await viewer.destroyAsset(asset);
  //   }, bg: kBlue, cameraPosition: Vector3(0, 0, 6));
  // });

  // test('create multiple (non-instanced) geometry', () async {
  //   await testHelper.withViewer((viewer) async {
  //     final asset1 = await viewer
  //         .createGeometry(GeometryUtils.cube(normals: false, uvs: false));
  //     await viewer.addToScene(asset1);

  //     final asset2 = await viewer
  //         .createGeometry(GeometryUtils.cube(normals: false, uvs: false));
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
  //         GeometryUtils.wireframeCamera(normals: false, uvs: false));
  //     await viewer.addToScene(asset);
  //     await viewer.setTransform(asset.entity, Matrix4.rotationY(pi / 4));

  //     await testHelper.capture(viewer.view, "camera_cube");
  //     await viewer.removeFromScene(asset);
  //     await viewer.destroyAsset(asset);
  //   });
  // });
}

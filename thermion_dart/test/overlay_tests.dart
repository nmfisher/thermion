import 'dart:io';
import 'dart:typed_data';

import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';

import 'package:vector_math/vector_math_64.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("overlay");
  // var material = await viewer.createMaterial(File(
  //         "/Users/nickfisher/Documents/thermion/materials/grid.filamat")
  //     .readAsBytesSync());
  // var materialInstance = await material.createInstance();
  // await materialInstance.setCullingMode(CullingMode.NONE);
  // await materialInstance.setParameterFloat("distance", 10000.0);
  // await materialInstance.setParameterFloat("lineSize", 0.001);

  // var grid = await viewer.createGeometry(await createGridGeometry(),
  //     materialInstances: [materialInstance]);

  // await viewer.setPriority(grid.entity, 7);

  // await viewer.setViewFrustumCulling(false);
  Future<Geometry> createGridGeometry() async {
    List<double> vertices = [];
    List<int> indices = [];
    double stepSize = 1 / 4.0;

    for (double x = -1.0; x < 1.0; x += stepSize) {
      for (double z = -1.0; z < 1.0; z += stepSize) {
        int baseIndex = vertices.length ~/ 3;
        var verts = [
          x,
          0.0,
          z,
          x,
          0.0,
          z + stepSize,
          x + stepSize,
          0.0,
          z + stepSize,
          x + stepSize,
          0.0,
          z
        ];
        vertices.addAll(verts);

        indices.addAll([
          baseIndex,
          baseIndex + 1,
          baseIndex + 2,
          baseIndex + 2,
          baseIndex + 3,
          baseIndex
        ]);
      }
    }

    return Geometry(Float32List.fromList(vertices), indices);
  }

  group("overlay tests", () {
    group("grid", () {
      test('enable grid', () async {
        await testHelper.withViewer(
          (viewer) async {
            var viewMatrix = makeViewMatrix(
                Vector3(0, 20, 0), Vector3(0, 0, 0), Vector3(0, 0, -1));

            var modelMatrix = viewMatrix.clone()..invert();
            await viewer.setCameraModelMatrix4(modelMatrix);

            await viewer.showGridOverlay();
            await viewer.setLayerVisibility(VisibilityLayers.OVERLAY, true);

            final cube = await viewer.createGeometry(
                GeometryHelper.cube(normals: false, uvs: false));
            await testHelper.capture(viewer, "grid_added_layer_visible");
            await viewer.setLayerVisibility(VisibilityLayers.OVERLAY, false);
            await testHelper.capture(viewer, "grid_added_layer_invisible");
            await viewer.setLayerVisibility(VisibilityLayers.OVERLAY, true);
            await viewer.removeGridOverlay();
            await testHelper.capture(viewer, "grid_remove_layer_visible");
          },
          postProcessing: true,
        );
      });
    });

    group("stencil", () {
      test('set stencil highlight for geometry', () async {
        await testHelper.withViewer((viewer) async {
          var cube = await viewer
              .createGeometry(GeometryHelper.cube(normals: false, uvs: false));
          await testHelper.capture(viewer, "geometry_before_stencil_highlight");
          await cube.setStencilHighlight();

          await testHelper.capture(viewer, "geometry_add_stencil_highlight");

          await cube.removeStencilHighlight();

          await testHelper.capture(viewer, "geometry_remove_stencil_highlight");

          await viewer.setTransform(
              cube.entity, Matrix4.translation(Vector3(1, 0, 0)));
          await cube.setStencilHighlight();

          await testHelper.capture(viewer, "geometry_add_stencil_highlight2");
        }, postProcessing: true);
      });

      test('set stencil highlight for glb', () async {
        await testHelper.withViewer((viewer) async {
          var cube = await viewer.loadGlb(
              "${testHelper.testDir}/assets/cube.glb",
              numInstances: 2);
          await testHelper.capture(viewer, "glb_before_stencil_highlight");

          // gltf is slightly more complicated, because the "head" entity is
          // not renderable, so we need to pick a child entity with a renderable
          // component.
          await cube.setStencilHighlight(entityIndex: 0);

          await testHelper.capture(viewer, "glb_add_stencil_highlight");

          await cube.removeStencilHighlight();

          await testHelper.capture(viewer, "glb_remove_stencil_highlight");
        }, postProcessing: true, bg: kWhite);
      });
    });

    group("bounding box", () {
      test('add bounding box to geometry', () async {
        await testHelper.withViewer(
          (viewer) async {
            final cube = await viewer.createGeometry(
                GeometryHelper.cube(normals: false, uvs: false));
            await cube.setBoundingBoxVisibility(true);
            await testHelper.capture(viewer, "geometry_bounding_box_visible");
            await cube.setBoundingBoxVisibility(false);
            await testHelper.capture(
                viewer, "geometry_bounding_box_not_visible");
            await cube.setBoundingBoxVisibility(true);
            await viewer.removeAsset(cube);
            await testHelper.capture(
                viewer, "geometry_bounding_box_removed");
          },
          postProcessing: true,
        );
      });

      test('add bounding box to gltf', () async {
        await testHelper.withViewer(
          (viewer) async {
            var cube = await viewer
                .loadGlb("file://${testHelper.testDir}/assets/cube.glb");
            await cube.setBoundingBoxVisibility(true);
            await testHelper.capture(viewer, "gltf_bounding_box_visible");
            await cube.setBoundingBoxVisibility(false);
            await testHelper.capture(viewer, "gltf_bounding_box_not_visible");
          },
          postProcessing: true,
        );
      });
    });
  });

  //   test('set uv scaling (unlit)', () async {
  //     var viewer = await testHelper.createViewer();
  //     await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);
  //     await viewer.setCameraPosition(0, 0, 6);
  //     await viewer.addDirectLight(
  //         DirectLight.sun(direction: Vector3(0, 0, -1)..normalize()));

  //     final unlitMaterialInstance = await viewer.createUnlitMaterialInstance();
  //     final cube = await viewer.createGeometry(GeometryHelper.cube(),
  //         materialInstance: unlitMaterialInstance);
  //     await viewer.setMaterialPropertyFloat4(
  //         cube, 'baseColorFactor', 0, 1, 1, 1, 1);
  //     await viewer.setMaterialPropertyInt(cube, 'baseColorIndex', 0, 1);
  //     unlitMaterialInstance.setParameterFloat2("uvScale", 2.0, 4.0);

  //     var textureData =
  //         File("${testHelper.testDir}/assets/cube_texture_512x512.png")
  //             .readAsBytesSync();
  //     var texture = await viewer.createTexture(textureData);
  //     await viewer.applyTexture(texture, cube);
  //     await testHelper.capture(viewer, "set_uv_scaling");
  //     await viewer.dispose();
  //   });
  // });

  // group("texture", () {
  //   test("create/apply/dispose texture", () async {
  //     var viewer = await testHelper.createViewer();

  //     var textureData =
  //         File("${testHelper.testDir}/assets/cube_texture_512x512.png")
  //             .readAsBytesSync();

  //     var texture = await viewer.createTexture(textureData);
  //     await viewer.setBackgroundColor(0.0, 0.0, 0.0, 1.0);
  //     await viewer.addDirectLight(
  //         DirectLight.sun(direction: Vector3(0, -10, -1)..normalize()));
  //     await viewer.addDirectLight(DirectLight.spot(
  //         intensity: 1000000,
  //         position: Vector3(0, 0, 1.5),
  //         direction: Vector3(0, 0, -1)..normalize(),
  //         falloffRadius: 10,
  //         spotLightConeInner: 1,
  //         spotLightConeOuter: 1));
  //     await viewer.setCameraPosition(0, 2, 6);
  //     await viewer
  //         .setCameraRotation(Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 8));
  //     var materialInstance =
  //         await viewer.createUbershaderMaterialInstance(unlit: true);
  //     var cube = await viewer.createGeometry(GeometryHelper.cube(),
  //         materialInstances: [materialInstance]);

  //     await viewer.setPostProcessing(true);
  //     await viewer.setToneMapping(ToneMapper.LINEAR);

  //     await viewer.applyTexture(texture, cube,
  //         materialIndex: 0, parameterName: "baseColorMap");

  //     await testHelper.capture(viewer, "texture_applied_to_geometry");

  //     await viewer.removeAsset(cube);
  //     await viewer.destroyTexture(texture);
  //     await viewer.dispose();
  //   });
  // });

  // group("unproject", () {
  //   test("unproject", () async {
  //     final dimensions = (width: 1280, height: 768);

  //     var viewer = await testHelper.createViewer(viewportDimensions: dimensions);
  //     await viewer.setPostProcessing(false);
  //     // await viewer.setToneMapping(ToneMapper.LINEAR);
  //     await viewer.setBackgroundColor(1.0, 1.0, 1.0, 1.0);
  //     // await viewer.createIbl(1.0, 1.0, 1.0, 100000);
  //     await viewer.addLight(LightType.SUN, 6500, 100000, -2, 0, 0, 1, -1, 0);
  //     await viewer.addLight(LightType.SPOT, 6500, 500000, 0, 0, 2, 0, 0, -1,
  //         falloffRadius: 10, spotLightConeInner: 1.0, spotLightConeOuter: 2.0);

  //     await viewer.setCameraPosition(-3, 4, 6);
  //     await viewer.setCameraRotation(
  //         Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
  //             Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 6));
  //     var cube =
  //         await viewer.createGeometry(GeometryHelper.cube(), keepData: true);
  //     await viewer.setMaterialPropertyFloat4(
  //         cube, "baseColorFactor", 0, 1.0, 1.0, 1.0, 1.0);
  //     var textureData =
  //         File("${testHelper.testDir}/assets/cube_texture_512x512.png").readAsBytesSync();
  //     var texture = await viewer.createTexture(textureData);
  //     await viewer.applyTexture(texture, cube,
  //         materialIndex: 0, parameterName: "baseColorMap");

  //     var numFrames = 60;

  //     // first do the render
  //     for (int i = 0; i < numFrames; i++) {
  //       await viewer.setCameraPosition(-3 + (i / numFrames * 2), 4, 6);

  //       await viewer.setCameraRotation(
  //           Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
  //               Quaternion.axisAngle(
  //                   Vector3(1, 0, 0), -pi / 6 - (i / numFrames * pi / 6)));

  //       var rendered = await testHelper.capture(viewer, "unproject_render$i");
  //       var renderPng =
  //           await pixelsToPng(rendered, dimensions.width, dimensions.height);

  //       File("${outDir.path}/unproject_render${i}.png")
  //           .writeAsBytesSync(renderPng);
  //     }

  //     // then go off and convert the video

  //     // now unproject the render back onto the geometry
  //     final textureSize = (width: 1280, height: 768);
  //     var pixels = <Uint8List>[];
  //     // note we skip the first frame
  //     for (int i = 0; i < numFrames; i++) {
  //       await viewer.setCameraPosition(-3 + (i / numFrames * 2), 4, 6);

  //       await viewer.setCameraRotation(
  //           Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
  //               Quaternion.axisAngle(
  //                   Vector3(1, 0, 0), -pi / 6 - (i / numFrames * pi / 6)));

  //       var input = pngToPixelBuffer(File(
  //               "${outDir.path}/a8c317af-6081-4848-8a06-f6b69bc57664_${i + 1}.png")
  //           .readAsBytesSync());
  //       var pixelBuffer = await (await viewer as ThermionViewerFFI).unproject(
  //           cube,
  //           input,
  //           dimensions.width,
  //           dimensions.height,
  //           textureSize.width,
  //           textureSize.height);

  //       // var png = await pixelsToPng(Uint8List.fromList(pixelBuffer),
  //       //     dimensions.width, dimensions.height);

  //       await savePixelBufferToBmp(
  //           pixelBuffer,
  //           textureSize.width,
  //           textureSize.height,
  //           p.join(outDir.path, "unprojected_texture${i}.bmp"));

  //       pixels.add(pixelBuffer);

  //       if (i > 10) {
  //         break;
  //       }
  //     }

  //     // }

  //     final aggregatePixelBuffer = medianImages(pixels);
  //     await savePixelBufferToBmp(aggregatePixelBuffer, textureSize.width,
  //         textureSize.height, "unproject_texture.bmp");
  //     var pixelBufferPng = await pixelsToPng(
  //         Uint8List.fromList(aggregatePixelBuffer),
  //         dimensions.width,
  //         dimensions.height);
  //     File("${outDir.path}/unproject_texture.png")
  //         .writeAsBytesSync(pixelBufferPng);

  //     await viewer.setPostProcessing(true);
  //     await viewer.setToneMapping(ToneMapper.LINEAR);

  //     final unlit = await viewer.createUnlitMaterialInstance();
  //     await viewer.removeAsset(cube);
  //     cube = await viewer.createGeometry(GeometryHelper.cube(),
  //         materialInstance: unlit);
  //     var reconstructedTexture = await viewer.createTexture(pixelBufferPng);
  //     await viewer.applyTexture(reconstructedTexture, cube);

  //     await viewer.setCameraRotation(
  //         Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
  //             Quaternion.axisAngle(Vector3(1, 0, 0), -pi / 6));
  //     await testHelper.capture(viewer, "unproject_reconstruct");

  //     // now re-render
  //     for (int i = 0; i < numFrames; i++) {
  //       await viewer.setCameraPosition(-3 + (i / numFrames * 2), 4, 6);

  //       await viewer.setCameraRotation(
  //           Quaternion.axisAngle(Vector3(0, 1, 0), -pi / 8) *
  //               Quaternion.axisAngle(
  //                   Vector3(1, 0, 0), -pi / 6 - (i / numFrames * pi / 6)));

  //       var rendered = await testHelper.capture(viewer, "unproject_rerender$i");
  //       var renderPng =
  //           await pixelsToPng(rendered, dimensions.width, dimensions.height);

  //       File("${outDir.path}/unproject_rerender${i}.png")
  //           .writeAsBytesSync(renderPng);
  //     }
  //   }, timeout: Timeout(Duration(minutes: 2)));
}

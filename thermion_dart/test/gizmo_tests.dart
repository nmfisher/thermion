import 'dart:async';

import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("gizmo");

  group("gizmo tests", () {
    test('add gizmo', () async {
      await testHelper.withViewer((viewer) async {
        var modelMatrix =
            makeViewMatrix(Vector3(0.5, 0.5, 0.5), Vector3.zero(), Vector3(0, 1, 0));
        modelMatrix.invert();
        await viewer.setCameraModelMatrix4(modelMatrix);

        final view = await viewer.getViewAt(0);
        final gizmo = await viewer.createGizmo(view, GizmoType.translation);
        await viewer.setLayerVisibility(VisibilityLayers.OVERLAY, true);
        await gizmo.addToScene();
        await testHelper.capture(
            viewer, "gizmo_added_to_scene_unattached_close");

        modelMatrix =
            makeViewMatrix(Vector3(0.5, 0.5, 0.5).scaled(10), Vector3.zero(), Vector3(0, 1, 0));
        modelMatrix.invert();
        await viewer.setCameraModelMatrix4(modelMatrix);

        // gizmo occupies same viewport size no matter the camera position
        await testHelper.capture(viewer, "gizmo_added_to_scene_unattached_far");
      }, postProcessing: true, bg: kWhite);
    });

    test('pick gizmo when not added to scene (this should not crash)',
        () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setCameraPosition(0, 0, 1);
        final view = await viewer.getViewAt(0);
        final viewport = await view.getViewport();
        final gizmo = await viewer.createGizmo(view, GizmoType.translation);

        final completer = Completer<GizmoPickResultType>();

        await gizmo.pick(viewport.width ~/ 2, viewport.height ~/ 2 + 1,
            handler: (GizmoPickResultType resultType, Vector3 coords) async {
          completer.complete(resultType);
        });

        for (int i = 0; i < 10; i++) {
          await testHelper.capture(
              viewer, "pick_gizmo_without_adding_to_scene");
          if (completer.isCompleted) {
            break;
          }
        }

        expect(completer.isCompleted, false);
      }, postProcessing: true, bg: kWhite);
    });

    test('pick gizmo when added to scene', () async {
      await testHelper.withViewer((viewer) async {
        await viewer.setCameraPosition(0, 0, 1);
        final view = await viewer.getViewAt(0);
        final viewport = await view.getViewport();
        final gizmo = await viewer.createGizmo(view, GizmoType.translation);
        await gizmo.addToScene();
        await viewer.setLayerVisibility(VisibilityLayers.OVERLAY, true);

        final completer = Completer<GizmoPickResultType>();

        await testHelper.capture(viewer, "gizmo_before_pick_no_highlight");

        await gizmo.pick(viewport.width ~/ 2, viewport.height ~/ 2 + 1,
            handler: (resultType, coords) async {
          completer.complete(resultType);
        });

        for (int i = 0; i < 10; i++) {
          await testHelper.capture(viewer, "gizmo_after_pick_no_highlight");
          if (completer.isCompleted) {
            break;
          }
        }

        assert(completer.isCompleted);
      }, postProcessing: true, bg: kWhite);
    });

    test('highlight/unhighlight gizmo', () async {
      await testHelper.withViewer((viewer) async {
        final modelMatrix =
            makeViewMatrix(Vector3(0.5, 0.5, 0.5), Vector3.zero(), Vector3(0, 1, 0));
        modelMatrix.invert();
        await viewer.setCameraModelMatrix4(modelMatrix);
        final view = await viewer.getViewAt(0);
        final viewport = await view.getViewport();
        final gizmo = await viewer.createGizmo(view, GizmoType.translation);
        await gizmo.addToScene();
        await viewer.setLayerVisibility(VisibilityLayers.OVERLAY, true);

        await testHelper.capture(viewer, "gizmo_before_highlight");
        await gizmo.highlight(Axis.X);
        await testHelper.capture(viewer, "gizmo_after_highlight");
        await gizmo.unhighlight();
        await testHelper.capture(viewer, "gizmo_after_unhighlight");
      }, postProcessing: true, bg: kWhite);
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

  //     await viewer.removeEntity(cube);
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
  //     await viewer.removeEntity(cube);
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

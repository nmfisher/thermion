// ignore_for_file: unused_local_variable

import 'dart:async';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("view");

  group('view tests', () {
    test('get camera from view', () async {
      await testHelper.withViewer((viewer) async {
        var view = await viewer.getViewAt(0);
        expect(await view.getCamera(), isNotNull);
      });
    });

    test('one swapchain, render view to render target', () async {
      await testHelper.withViewer((viewer) async {
        final texture = await testHelper.createTexture(500, 500);
        final renderTarget = await viewer.createRenderTarget(
            500, 500, texture.metalTextureAddress);
        final view = await viewer.getViewAt(0);
        await view.setRenderTarget(renderTarget);

        await viewer.setBackgroundColor(1.0, 0, 0, 1);
        final cube = await viewer
            .createGeometry(GeometryHelper.cube(normals: false, uvs: false));

        var mainCamera = await viewer.getMainCamera();
        mainCamera.setTransform(Matrix4.translation(Vector3(0, 0, 5)));
        await testHelper.capture(
            viewer,
            renderTarget: renderTarget,
            "default_swapchain_default_view_render_target");
      });
    });

    test('create secondary view, default swapchain', () async {
      await testHelper.withViewer((viewer) async {
        final cube = await viewer
            .createGeometry(GeometryHelper.cube(normals: false, uvs: false));

        var mainCamera = await viewer.getMainCamera();
        mainCamera.setTransform(Matrix4.translation(Vector3(0, 0, 5)));
        await testHelper.capture(viewer, "default_swapchain_default_view");

        final view = await viewer.createView();
        view.updateViewport(500, 500);
        view.setCamera(mainCamera);
        await testHelper.capture(
          viewer,
          "default_swapchain_new_view_with_main_camera",
          view: view,
        );

        var newCamera = await viewer.createCamera();
        newCamera.setTransform(Matrix4.translation(Vector3(0.0, 0.0, 10.0)));
        newCamera.setLensProjection();
        view.setCamera(newCamera);

        await testHelper.capture(
          viewer,
          "default_swapchain_new_view_new_camera",
          view: view,
        );

        await testHelper.capture(
          viewer,
          "default_swapchain_default_view_main_camera_no_change",
        );
      });
    });

    test('create secondary view, different swapchain', () async {
      await testHelper.withViewer((viewer) async {
        final cube = await viewer.createGeometry(GeometryHelper.cube());

        var mainCamera = await viewer.getMainCamera();
        mainCamera.setTransform(Matrix4.translation(Vector3(0, 0, 5)));
        final swapChain = await viewer.createHeadlessSwapChain(1, 1);
        await testHelper.capture(
            viewer, "create_swapchain_default_view_default_swapchain");

        final view = await viewer.createView();

        final texture = await testHelper.createTexture(200, 400);
        final renderTarget = await viewer.createRenderTarget(
            200, 400, texture.metalTextureAddress);
        await view.setRenderTarget(renderTarget);

        await view.updateViewport(200, 400);
        view.setCamera(mainCamera);
        mainCamera.setLensProjection(aspect: 0.5);

        await testHelper.capture(
          viewer,
          view: view,
          swapChain: swapChain,
          renderTarget: renderTarget,
          "create_swapchain_secondary_view_new_swapchain",
        );
      });
    });

    test('pick', () async {
      await testHelper.withViewer((viewer) async {
        final view = await viewer.getViewAt(0);

        await view.setRenderable(true, testHelper.swapChain);

        final cube = await viewer
            .createGeometry(GeometryHelper.cube(normals: false, uvs: false));

        await testHelper.capture(viewer, "view_pick");

        final completer = Completer();

        await viewer.pick(250, 250, (result) {
          completer.complete(result.entity);
          print(
              "Pick result : ${result.fragX} ${result.fragY} ${result.fragZ}");
        });

        for (int i = 0; i < 10; i++) {
          await testHelper.capture(viewer, "view_pick");
          if (completer.isCompleted) {
            break;
          }
        }

        expect(completer.isCompleted, true);
        expect(await completer.future, cube.entity);
      }, cameraPosition: Vector3(0, 0, 3));
    });

    test('dithering', () async {
      await testHelper.withViewer((viewer) async {
        final view = await viewer.getViewAt(0);

        expect(await view.isDitheringEnabled(), true);

        final cube = await viewer
            .createGeometry(GeometryHelper.cube(normals: false, uvs: false));

        await testHelper.capture(viewer, "dithering_enabled");

        await view.setDithering(false);
        expect(await view.isDitheringEnabled(), false);
        await testHelper.capture(viewer, "dithering_disabled");
      }, cameraPosition: Vector3(0, 0, 3));
    });
  });
}

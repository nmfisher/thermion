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
      var viewer = await testHelper.createViewer();
      var view = await viewer.getViewAt(0);
      expect(await view.getCamera(), isNotNull);

      await viewer.dispose();

    });

    test('one swapchain, render view to render target', () async {
      var viewer = await testHelper.createViewer();

      final texture = await testHelper.createTexture(500, 500);
      final renderTarget = await viewer.createRenderTarget(
          500, 500, texture.metalTextureAddress);
      viewer.setRenderTarget(renderTarget);

      await viewer.setBackgroundColor(1.0, 0, 0, 1);
      final cube = await viewer.createGeometry(GeometryHelper.cube());

      var mainCamera = await viewer.getMainCamera();
      mainCamera.setTransform(Matrix4.translation(Vector3(0, 0, 5)));
      await testHelper.capture(
          viewer,
          renderTarget: renderTarget,
          "default_swapchain_default_view_render_target");

      await viewer.dispose();

    });

    test('create secondary view, default swapchain', () async {
      var viewer = await testHelper.createViewer();
      await viewer.setBackgroundColor(1.0, 0, 0, 1);

      final cube = await viewer.createGeometry(GeometryHelper.cube());

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

      await viewer.dispose();
    });

    test('create secondary view, different swapchain', () async {
      var viewer = await testHelper.createViewer();
      await viewer.setBackgroundColor(1.0, 0, 0, 1);
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

      await viewer.dispose();
    });

    test('pick', () async {
      var viewer = await testHelper.createViewer(
          bg: kRed, cameraPosition: Vector3(0, 0, 5));

      final cube = await viewer.createGeometry(GeometryHelper.cube());

      final completer = Completer();
      late StreamSubscription listener;
      listener = viewer.pickResult.listen((result) async {
        completer.complete(result.entity);
        await listener.cancel();
      });

      viewer.pick(250, 250);

      for (int i = 0; i < 10; i++) {
        await viewer.requestFrame();
        await Future.delayed(Duration(milliseconds: 100));
      }

      expect(completer.isCompleted, true);
      expect(await completer.future, cube);
      await viewer.dispose();
    });
  });
}

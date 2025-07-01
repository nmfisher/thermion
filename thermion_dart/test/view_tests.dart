@Timeout(const Duration(seconds: 600))

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_camera.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/src/bindings/src/thermion_dart_ffi.g.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  Logger.root.onRecord.listen((record) {
    print(record);
  });

  final testHelper = TestHelper("view");
  await testHelper.setup();

  test('get camera from view', () async {
    await testHelper.withViewer((viewer) async {
      final camera = await viewer.view.getCamera();
      expect(camera, isNotNull);
    });
  });

  test('render two views, change material instance in between', () async {
    final viewportDimensions = (width: 500, height: 500);
    final swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
        viewportDimensions.width, viewportDimensions.height);
    await FilamentApp.instance!.setClearOptions(0, 0, 0, 0);
    final views = [];
    final scene = await FilamentApp.instance!.createScene() as FFIScene;
    final camera = await FilamentApp.instance!.createCamera() as FFICamera;
    await camera.setLensProjection();
    for (int i = 0; i < 2; i++) {
      final view = await FilamentApp.instance!.createView() as FFIView;
      await view.setScene(scene);
      await view.setCamera(camera);
      await view.setRenderable(true);
      await view.setViewport(
          viewportDimensions.width, viewportDimensions.height);
      await view.setFrustumCullingEnabled(false);
      await FilamentApp.instance!.register(swapChain, view);
      views.add(view);
    }

    var red = await FilamentApp.instance!.createUnlitMaterialInstance();
    await red.setParameterFloat4("baseColorFactor", 1, 0, 0, 1);

    var green = await FilamentApp.instance!.createUnlitMaterialInstance();
    await green.setParameterFloat4("baseColorFactor", 0, 1, 0, 1);

    var cube = await FilamentApp.instance!.createGeometry(
        GeometryHelper.cube(flipUvs: true), nullptr,
        materialInstances: [red]) as FFIAsset;

    await scene.add(cube);

    await camera.lookAt(Vector3(0, 0, 10));

    await testHelper.capture(null, "multiview_change_material_instance",
        swapChain: swapChain, beforeRender: (view) async {
      if (view == views.last) {
        await cube.setMaterialInstanceAt(green);
      }
    });
  });

  test('render to multiple views, same camera', () async {
    final viewportDimensions = (width: 500, height: 500);
    final swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
        viewportDimensions.width, viewportDimensions.height);
    await FilamentApp.instance!.setClearOptions(0, 0, 0, 0);
    final views = [];
    final scene = await FilamentApp.instance!.createScene() as FFIScene;
    final camera = await FilamentApp.instance!.createCamera() as FFICamera;
    await camera.setLensProjection();
    for (int i = 0; i < 2; i++) {
      final view = await FilamentApp.instance!.createView() as FFIView;
      await view.setScene(scene);
      await view.setCamera(camera);
      await view.setRenderable(true);
      await view.setViewport(
          viewportDimensions.width, viewportDimensions.height);
      await view.setFrustumCullingEnabled(false);
      await view.setPostProcessing(false);
      await FilamentApp.instance!.register(swapChain, view);
      views.add(view);
      await view.setRenderTarget(await FilamentApp.instance!.createRenderTarget(
        viewportDimensions.width,
        viewportDimensions.height,
      ) as FFIRenderTarget);
    }

    await camera.lookAt(Vector3(0, 0, 10));

    var materialInstance =
        await FilamentApp.instance!.createUnlitMaterialInstance();
    await materialInstance.setParameterFloat4("baseColorFactor", 1, 0, 0, 0);

    var cube = await FilamentApp.instance!.createGeometry(
        GeometryHelper.cube(flipUvs: true), nullptr,
        materialInstances: [materialInstance]) as FFIAsset;

    await scene.add(cube);
    final results = await FilamentApp.instance!.capture(swapChain);

    await savePixelBufferToBmp(
        results.first.$2,
        viewportDimensions.width,
        viewportDimensions.height,
        p.join(testHelper.outDir.path, "multi_view_same_camera_0.bmp"),
        isFloat: true);
    await savePixelBufferToBmp(
        results.last.$2,
        viewportDimensions.width,
        viewportDimensions.height,
        p.join(testHelper.outDir.path, "multi_view_same_camera_1.bmp"),
        isFloat: true);
  });

  test('render to multiple views, same scene, different camera', () async {
    final viewportDimensions = (width: 500, height: 500);
    final swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
        viewportDimensions.width, viewportDimensions.height);
    final views = <FFIView>[];
    final scene = await FilamentApp.instance!.createScene() as FFIScene;
    final camera1 = await FilamentApp.instance!.createCamera() as FFICamera;
    await camera1.setLensProjection();
    final camera2 = await FilamentApp.instance!.createCamera() as FFICamera;
    await camera2.setLensProjection();
    for (int i = 0; i < 2; i++) {
      final view = await FilamentApp.instance!.createView() as FFIView;
      await view.setScene(scene);
      await view.setRenderable(true);
      await view.setViewport(
          viewportDimensions.width, viewportDimensions.height);
      await view.setFrustumCullingEnabled(false);
      await view.setPostProcessing(false);
      await FilamentApp.instance!.register(swapChain, view);
      views.add(view);
    }

    await camera1.lookAt(Vector3(-5, 0, 10));
    await camera2.lookAt(Vector3(5, 0, 10));

    await views.first.setCamera(camera1);
    await views.last.setCamera(camera2);

    var materialInstance =
        await FilamentApp.instance!.createUnlitMaterialInstance();
    await materialInstance.setParameterFloat4("baseColorFactor", 1, 0, 0, 0);

    var cube = await FilamentApp.instance!.createGeometry(
        GeometryHelper.cube(flipUvs: true), nullptr,
        materialInstances: [materialInstance]) as FFIAsset;

    await scene.add(cube);

    await testHelper.capture(null, "multiple_view_different_camera");
  });

  test('render view to render target, used as input for another', () async {
    final viewportDimensions = (width: 500, height: 500);
    final swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
        viewportDimensions.width, viewportDimensions.height);
    final views = <FFIView>[];
    final scene = await FilamentApp.instance!.createScene() as FFIScene;
    final camera = await FilamentApp.instance!.createCamera() as FFICamera;
    await camera.setLensProjection();

    await FilamentApp.instance!.setClearOptions(0, 0, 0, 0);

    for (int i = 0; i < 2; i++) {
      final view = await FilamentApp.instance!.createView() as FFIView;
      await view.setScene(scene);
      await view.setRenderable(true);
      await view.setViewport(
          viewportDimensions.width, viewportDimensions.height);
      await view.setFrustumCullingEnabled(false);
      await view.setPostProcessing(false);
      await view.setRenderTarget(await FilamentApp.instance!.createRenderTarget(
              viewportDimensions.width, viewportDimensions.height)
          as FFIRenderTarget);
      await FilamentApp.instance!.register(swapChain, view);
      await view.setCamera(camera);
      views.add(view);
    }

    await camera.lookAt(Vector3(0, 4, 12), focus: Vector3(0, -4, 0));

    var materialInstance1 =
        await FilamentApp.instance!.createUnlitMaterialInstance();
    await materialInstance1.setParameterFloat4("baseColorFactor", 1, 0, 0, 0);

    var cube = await FilamentApp.instance!.createGeometry(
        GeometryHelper.cube(flipUvs: true), nullptr,
        materialInstances: [materialInstance1]) as FFIAsset;

    await scene.add(cube);

    var result =
        await FilamentApp.instance!.capture(swapChain, view: views.first);

    await savePixelBufferToBmp(
        result.first.$2,
        viewportDimensions.width,
        viewportDimensions.height,
        p.join(testHelper.outDir.path, "render_target_output.bmp"),
        isFloat: true);

    var materialInstance2 = await FilamentApp.instance!
        .createUbershaderMaterialInstance(
            hasBaseColorTexture: true, unlit: false);

    var light = await FilamentApp.instance!.createDirectLight(DirectLight(
        type: LightType.SUN,
        color: 6500,
        intensity: 100000000,
        direction: Vector3(0, 0, -1),
        position: Vector3.zero()));
    await scene.addEntity(light);

    final texture =
        await (await views.first.getRenderTarget())!.getColorTexture();

    await materialInstance2.setParameterTexture("baseColorMap", texture,
        await FilamentApp.instance!.createTextureSampler());
    await materialInstance2.setParameterInt("baseColorIndex", 0);
    await materialInstance2.setParameterFloat4("baseColorFactor", 1, 1, 1, 1);
    await cube.setMaterialInstanceAt(materialInstance2 as FFIMaterialInstance);

    result = await FilamentApp.instance!.capture(swapChain, view: views.last);

    await savePixelBufferToBmp(
        result.first.$2,
        viewportDimensions.width,
        viewportDimensions.height,
        p.join(testHelper.outDir.path, "render_target_as_texture.bmp"),
        isFloat: true);
  });

  ///
  ///
  ///
  test('render two views to same render target', () async {
    final viewportDimensions = (width: 500, height: 500);
    final swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
        viewportDimensions.width, viewportDimensions.height);
    final views = <FFIView>[];

    await FilamentApp.instance!.setClearOptions(0, 0, 0, 0,
        clear: false, clearStencil: 0, discard: false);

    final renderTarget = await FilamentApp.instance!.createRenderTarget(
        viewportDimensions.width, viewportDimensions.height) as FFIRenderTarget;

    for (int i = 0; i < 2; i++) {
      final camera = await FilamentApp.instance!.createCamera() as FFICamera;
      await camera.setLensProjection();
      final view = await FilamentApp.instance!.createView() as FFIView;
      final scene = await FilamentApp.instance!.createScene() as FFIScene;
      await view.setScene(scene);
      await view.setRenderable(true);
      await view.setViewport(
          viewportDimensions.width, viewportDimensions.height);
      await view.setFrustumCullingEnabled(false);
      await view.setPostProcessing(false);

      await view.setRenderTarget(renderTarget);

      await FilamentApp.instance!.register(swapChain, view);
      await view.setCamera(camera);
      views.add(view);

      await camera.lookAt(Vector3(0, 4, 12),
          focus: Vector3(i == 0 ? -2 : 2, 0, 0));

      var cube = await FilamentApp.instance!.createGeometry(
          GeometryHelper.cube(flipUvs: true), nullptr) as FFIAsset;

      await scene.add(cube);
    }
    var result = await FilamentApp.instance!
        .capture(swapChain, captureRenderTarget: true);

    await savePixelBufferToBmp(
        result.first.$2,
        viewportDimensions.width,
        viewportDimensions.height,
        p.join(testHelper.outDir.path, "two_views_same_render_target1.bmp"),
        isFloat: true);
    await savePixelBufferToBmp(
        result.last.$2,
        viewportDimensions.width,
        viewportDimensions.height,
        p.join(testHelper.outDir.path, "two_views_same_render_target2.bmp"),
        isFloat: true);
  });

  test('render depth buffer to render target', () async {
    final viewportDimensions = (width: 500, height: 500);
    final swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
        viewportDimensions.width, viewportDimensions.height);
    final views = <FFIView>[];
    final scene = await FilamentApp.instance!.createScene() as FFIScene;
    final camera = await FilamentApp.instance!.createCamera() as FFICamera;
    await camera.setLensProjection();

    await FilamentApp.instance!.setClearOptions(0, 0, 0, 0);

    for (int i = 0; i < 2; i++) {
      final view = await FilamentApp.instance!.createView() as FFIView;
      await view.setScene(scene);
      await view.setRenderable(true);
      await view.setViewport(
          viewportDimensions.width, viewportDimensions.height);
      await view.setFrustumCullingEnabled(false);
      await view.setPostProcessing(false);
      await view.setRenderTarget(await FilamentApp.instance!.createRenderTarget(
              viewportDimensions.width, viewportDimensions.height)
          as FFIRenderTarget);
      await FilamentApp.instance!.register(swapChain, view);
      await view.setCamera(camera);
      views.add(view);
    }

    await camera.lookAt(Vector3(0, 4, 12), focus: Vector3(0, -4, 0));

    var materialInstance1 =
        await FilamentApp.instance!.createUnlitMaterialInstance();
    await materialInstance1.setParameterFloat4("baseColorFactor", 1, 0, 0, 0);

    var cube = await FilamentApp.instance!.createGeometry(
        GeometryHelper.cube(flipUvs: true), nullptr,
        materialInstances: [materialInstance1]) as FFIAsset;

    await scene.add(cube);

    var result =
        await FilamentApp.instance!.capture(swapChain, view: views.first);

    await savePixelBufferToBmp(
        result.first.$2,
        viewportDimensions.width,
        viewportDimensions.height,
        p.join(testHelper.outDir.path, "render_target_output.bmp"),
        isFloat: true);

    var materialInstance2 = await FilamentApp.instance!
        .createUbershaderMaterialInstance(
            hasBaseColorTexture: true, unlit: false);

    var light = await FilamentApp.instance!.createDirectLight(DirectLight(
        type: LightType.SUN,
        color: 6500,
        intensity: 100000000,
        direction: Vector3(0, 0, -1),
        position: Vector3.zero()));
    await scene.addEntity(light);

    final texture =
        await (await views.first.getRenderTarget())!.getColorTexture();

    await materialInstance2.setParameterTexture("baseColorMap", texture,
        await FilamentApp.instance!.createTextureSampler());
    await materialInstance2.setParameterInt("baseColorIndex", 0);
    await materialInstance2.setParameterFloat4("baseColorFactor", 1, 1, 1, 1);
    await cube.setMaterialInstanceAt(materialInstance2 as FFIMaterialInstance);

    result = await FilamentApp.instance!.capture(swapChain, view: views.last);

    await savePixelBufferToBmp(
        result.first.$2,
        viewportDimensions.width,
        viewportDimensions.height,
        p.join(testHelper.outDir.path, "render_target_as_texture.bmp"),
        isFloat: true);
  });

  test('fog tests', () async {
    await testHelper.withViewer((viewer) async {
      var cube = await FilamentApp.instance!
          .createGeometry(GeometryHelper.cube(flipUvs: true), nullptr);
      await viewer.addToScene(cube);

      final camera = await viewer.getActiveCamera();
      await camera.lookAt(Vector3(1, 3, 5), focus: Vector3.zero());

      await testHelper.capture(viewer.view, "fog_options_disabled");

      await viewer.view
          .setFogOptions(FogOptions(enabled: true, distance: 0, density: 0.5));
      await testHelper.capture(viewer.view, "fog_options_enabled");
    }, addSkybox: true, postProcessing: true);
  });

  test('show/hide stencil highlight', () async {
    await testHelper.withViewer((viewer) async {

      var cube = await FilamentApp.instance!
          .createGeometry(GeometryHelper.cube(flipUvs: true), nullptr);
      await viewer.addToScene(cube);
      await viewer.view.setStencilHighlight(cube);
      await FilamentApp.instance!.setClearOptions(1, 1, 1, 0, clear: true, discard: false);
      await FilamentApp.instance!.requestFrame();

      await testHelper.capture(
          null, "stencil_highlight_enabled", render:false);
      
      await FilamentApp.instance!.setClearOptions(1, 1, 1, 0, clear: true, discard: false);
      await viewer.view.removeStencilHighlight(cube);
      await FilamentApp.instance!.requestFrame();

     
      await testHelper.capture(
          null, "stencil_highlight_removed", render:false);
    }, postProcessing: false);
  });
}
// manually construct two views with stencil buffer
// final viewportDimensions = (width: 500, height: 500);
//       final swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
//           viewportDimensions.width, viewportDimensions.height,
//           hasStencilBuffer: true);
//       final renderTarget = await FilamentApp.instance!.createRenderTarget(
//           viewportDimensions.width, viewportDimensions.height);
//       await FilamentApp.instance!.setClearOptions(1, 1, 0, 0);
//       final views = <View>[];
//       final scene = await FilamentApp.instance!.createScene();
//       final camera = await FilamentApp.instance!.createCamera();
//       await camera.setLensProjection();
//       await camera.lookAt(Vector3(0, 0, 10));
//       for (int i = 0; i < 2; i++) {
//         final view = await FilamentApp.instance!.createView() as FFIView;
//         await view.setScene(scene);
//         await view.setCamera(camera);
//         await view.setStencilBufferEnabled(true);
//         await view.setBlendMode(BlendMode.transparent);
//         await view.setViewport(
//             viewportDimensions.width, viewportDimensions.height);
//         await view.setFrustumCullingEnabled(false);
//         await view.setPostProcessing(true);
//         await view.setRenderTarget(renderTarget);
//         views.add(view);
//       }

//       var green = await FilamentApp.instance!.createUnlitMaterialInstance();
//       await green.setParameterFloat4("baseColorFactor", 0, 1, 0, 1);
//       await green.setStencilCompareFunction(SamplerCompareFunction.A);
//       await green.setStencilOpDepthStencilPass(StencilOperation.REPLACE);
//       await green.setStencilReferenceValue(11);
//       await green.setDepthCullingEnabled(false);
//       await green.setStencilWriteEnabled(true);

//       var red = await FilamentApp.instance!.createUnlitMaterialInstance();
//       await red.setParameterFloat4("baseColorFactor", 1, 0, 0, 1);
//       await red.setDepthCullingEnabled(false);
//       await red.setDepthFunc(SamplerCompareFunction.E);
//       await red.setStencilCompareFunction(SamplerCompareFunction.A);
//       await red.setStencilReferenceValue(11);

//       var cube = await FilamentApp.instance!.createGeometry(
//           GeometryHelper.cube(), nullptr,
//           materialInstances: [green]);
//       // var cube2 = await FilamentApp.instance!.createGeometry(
//       //     GeometryHelper.cube(), nullptr,
//       //     materialInstances: [red]);
//       await scene.add(cube);
//       // await scene.add(cube2);
//       await FilamentApp.instance!.setPriority(cube.entity, 0);
//       // await FilamentApp.instance!.setPriority(cube2.entity, 1);

//       final renderer = FilamentApp.instance!.renderer;

//       final beginFrame = await withBoolCallback((cb) {
//         Renderer_beginFrameRenderThread(
//             renderer, swapChain.getNativeHandle(), 0.toBigInt, cb);
//       });
//       await withVoidCallback((requestId, cb) {
//         Renderer_renderRenderThread(
//             renderer, views[0].getNativeHandle(), requestId, cb);
//       });

//       await cube.setMaterialInstanceAt(red);

//       await FilamentApp.instance!.flush;

//       await withVoidCallback((requestId, cb) {
//         Renderer_renderRenderThread(
//             renderer, views[1].getNativeHandle(), requestId, cb);
//       });
//       var out = Uint8List(500 * 500 * 4 * 4);

//       await withVoidCallback((requestId, cb) {
//         Renderer_readPixelsRenderThread(
//             renderer,
//             views[0].getNativeHandle(),
//             renderTarget.getNativeHandle(),
//             PixelDataFormat.RGBA.value,
//             PixelDataType.FLOAT.value,
//             out.address,
//             out.length,
//             requestId,
//             cb);
//       });

//       await withVoidCallback((requestId, cb) {
//         Renderer_endFrameRenderThread(renderer, requestId, cb);
//       });

//       await FilamentApp.instance!.flush();

//       await savePixelBufferToPng(out, 500, 500, "/tmp/foo.png",
//           hasAlpha: true, isFloat: true);
//     }, createStencilBuffer: true);

//     test('one swapchain, render view to render target', () async {
//       await testHelper.withViewer((viewer) async {
//         final texture = await testHelper.createTexture(500, 500);
//         final renderTarget = await viewer.createRenderTarget(
//             500, 500, texture.metalTextureAddress);
//         final view = await viewer.getViewAt(0);
//         await view.setRenderTarget(renderTarget);

//         await viewer.setBackgroundColor(1.0, 0, 0, 1);
//         final cube = await viewer
//             .createGeometry(GeometryHelper.cube(normals: false, uvs: false));

//         var mainCamera = await viewer.getMainCamera();
//         mainCamera.setTransform(Matrix4.translation(Vector3(0, 0, 5)));
//         await testHelper.capture(
//             viewer,
//             renderTarget: renderTarget,
//             "default_swapchain_default_view_render_target");
//       });
//     });

//     test('create secondary view, default swapchain', () async {
//       await testHelper.withViewer((viewer) async {
//         final cube = await viewer
//             .createGeometry(GeometryHelper.cube(normals: false, uvs: false));

//         var mainCamera = await viewer.getMainCamera();
//         mainCamera.setTransform(Matrix4.translation(Vector3(0, 0, 5)));
//         await testHelper.capture(viewer, "default_swapchain_default_view");

//         final view = await viewer.createView();
//         view.setViewport(500, 500);
//         view.setCamera(mainCamera);
//         await testHelper.capture(
//           viewer,
//           "default_swapchain_new_view_with_main_camera",
//           view: view,
//         );

//         var newCamera = await viewer.createCamera();
//         newCamera.setTransform(Matrix4.translation(Vector3(0.0, 0.0, 10.0)));
//         newCamera.setLensProjection();
//         view.setCamera(newCamera);

//         await testHelper.capture(
//           viewer,
//           "default_swapchain_new_view_new_camera",
//           view: view,
//         );

//         await testHelper.capture(
//           viewer,
//           "default_swapchain_default_view_main_camera_no_change",
//         );
//       });
//     });

//     test('create secondary view, different swapchain', () async {
//       await testHelper.withViewer((viewer) async {
//         final cube = await viewer.createGeometry(GeometryHelper.cube());

//         var mainCamera = await viewer.getMainCamera();
//         mainCamera.setTransform(Matrix4.translation(Vector3(0, 0, 5)));
//         final swapChain = await viewer.createHeadlessSwapChain(1, 1);
//         await testHelper.capture(
//             viewer, "create_swapchain_default_view_default_swapchain");

//         final view = await viewer.createView();

//         final texture = await testHelper.createTexture(200, 400);
//         final renderTarget = await viewer.createRenderTarget(
//             200, 400, texture.metalTextureAddress);
//         await view.setRenderTarget(renderTarget);

//         await view.setViewport(200, 400);
//         view.setCamera(mainCamera);
//         mainCamera.setLensProjection(aspect: 0.5);

//         await testHelper.capture(
//           viewer,
//           view: view,
//           swapChain: swapChain,
//           renderTarget: renderTarget,
//           "create_swapchain_secondary_view_new_swapchain",
//         );
//       });
//     });

// }

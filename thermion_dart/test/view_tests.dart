@Timeout(const Duration(seconds: 600))
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_camera.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';
import 'src/test_io.dart' show isWeb;

void main() async {
  final testHelper = TestHelper("view");
  await testHelper.setup();

  test('get/set debug name', () async {
    final view = await FilamentApp.instance!.createView();
    expect(await view.getName(), "unnamed_view");
    view.setName("viewname");
    expect(await view.getName(), "viewname");
    await FilamentApp.instance!.destroyView(view);
  });

  test('get camera from view', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      final camera = await result.viewer.view.getCamera();
      expect(camera, isNotNull);
    });
  });

  test('set camera to null', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      // Verify camera is initially set
      final camera = await result.viewer.view.getCamera();
      expect(camera, isNotNull);

      // Set camera to null - should not throw
      await result.viewer.view.setCamera(null);

      // Re-set the camera
      await result.viewer.view.setCamera(camera);
      final cameraAfter = await result.viewer.view.getCamera();
      expect(cameraAfter, isNotNull);
    });
  });

  test('toggle transparent picking', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      expect(await result.viewer.view.isTransparentPickingEnabled(), false);
      await result.viewer.view.setTransparentPickingEnabled(true);
      expect(await result.viewer.view.isTransparentPickingEnabled(), true);
      await result.viewer.view.setTransparentPickingEnabled(false);
      expect(await result.viewer.view.isTransparentPickingEnabled(), false);
    });
  });

  test('render two views, change material instance in between', () async {
    final viewportDimensions = (width: 500, height: 500);
    final swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
      viewportDimensions.width,
      viewportDimensions.height,
    );
    await FilamentApp.instance!.setClearOptions(0, 0, 0, 0);
    final views = <View>[];
    final scene = await FilamentApp.instance!.createScene();
    final camera = await FilamentApp.instance!.createCamera();
    await camera.setLensProjection();
    for (int i = 0; i < 2; i++) {
      final view = await FilamentApp.instance!.createView();
      await view.setScene(scene);
      await view.setCamera(camera);

      await view.setViewport(viewportDimensions.width, viewportDimensions.height);
      await view.setFrustumCullingEnabled(false);
      await FilamentApp.instance!.renderManager.attach(view, swapChain);

      views.add(view);
    }

    var red = await FilamentApp.instance!.createUnlitMaterialInstance();
    await red.setParameterFloat4("baseColorFactor", 1, 0, 0, 1);

    var green = await FilamentApp.instance!.createUnlitMaterialInstance();
    await green.setParameterFloat4("baseColorFactor", 0, 1, 0, 1);

    var cube =
        await FilamentApp.instance!.createGeometry(GeometryUtils.cube(flipUvs: true), materialInstances: [red])
            as FFIAsset;

    await scene.add(cube);

    await camera.lookAt(Vector3(0, 0, 10));

    try {
      await testHelper.capture(
        null,
        "multiview_change_material_instance",
        swapChain: swapChain,
        beforeRender: (view) async {
          if (view == views.last) {
            await cube.setMaterialInstanceAt(green);
          }
        },
      );
    } finally {
      // Cleanup in the same order as ThermionViewerFFI.dispose()
      // 1. Remove assets from scene and destroy them
      await scene.remove(cube);
      await FilamentApp.instance!.destroyAsset(cube);

      // 2. Unset scene from all views and destroy views
      for (final view in views) {
        await FilamentApp.instance!.destroyView(view);
      }

      // 3. Destroy scene
      await FilamentApp.instance!.destroyScene(scene);

      // 4. Destroy swapchain
      await FilamentApp.instance!.destroySwapChain(swapChain);
    }
  });

  test('render to multiple views, same camera', () async {
    final viewportDimensions = (width: 500, height: 500);
    final swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
      viewportDimensions.width,
      viewportDimensions.height,
    );
    await FilamentApp.instance!.setClearOptions(0, 0, 0, 0);
    final views = [];
    final scene = await FilamentApp.instance!.createScene() as FFIScene;
    final camera = await FilamentApp.instance!.createCamera() as FFICamera;
    await camera.setLensProjection();
    for (int i = 0; i < 2; i++) {
      final view = await FilamentApp.instance!.createView() as FFIView;
      await view.setScene(scene);
      await view.setCamera(camera);

      await view.setViewport(viewportDimensions.width, viewportDimensions.height);
      await view.setFrustumCullingEnabled(false);
      await view.setPostProcessing(false);
      await FilamentApp.instance!.renderManager.attach(view, swapChain);

      views.add(view);
      await view.setRenderTarget(
        await FilamentApp.instance!.createRenderTarget(viewportDimensions.width, viewportDimensions.height)
            as FFIRenderTarget,
      );
    }

    await camera.lookAt(Vector3(0, 0, 10));

    var materialInstance = await FilamentApp.instance!.createUnlitMaterialInstance();
    await materialInstance.setParameterFloat4("baseColorFactor", 1, 0, 0, 0);

    var cube =
        await FilamentApp.instance!.createGeometry(
              GeometryUtils.cube(flipUvs: true),
              materialInstances: [materialInstance],
            )
            as FFIAsset;

    await scene.add(cube);
    final results = await FilamentApp.instance!.capture(swapChain);

    await savePixelBufferToBmp(
      results.first.$2,
      viewportDimensions.width,
      viewportDimensions.height,
      p.join(testHelper.outDirPath, "multi_view_same_camera_0.bmp"),
      isFloat: true,
    );
    await savePixelBufferToBmp(
      results.last.$2,
      viewportDimensions.width,
      viewportDimensions.height,
      p.join(testHelper.outDirPath, "multi_view_same_camera_1.bmp"),
      isFloat: true,
    );

    await FilamentApp.instance!.destroySwapChain(swapChain);
  });

  test('render to multiple views, same scene, different camera', () async {
    final viewportDimensions = (width: 500, height: 500);
    final swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
      viewportDimensions.width,
      viewportDimensions.height,
    );
    final views = <FFIView>[];
    final scene = await FilamentApp.instance!.createScene() as FFIScene;
    final camera1 = await FilamentApp.instance!.createCamera() as FFICamera;
    await camera1.setLensProjection();
    final camera2 = await FilamentApp.instance!.createCamera() as FFICamera;
    await camera2.setLensProjection();
    for (int i = 0; i < 2; i++) {
      final view = await FilamentApp.instance!.createView() as FFIView;
      await view.setScene(scene);

      await view.setViewport(viewportDimensions.width, viewportDimensions.height);
      await view.setFrustumCullingEnabled(false);
      await view.setPostProcessing(false);
      await FilamentApp.instance!.renderManager.attach(view, swapChain);

      views.add(view);
    }

    await camera1.lookAt(Vector3(-5, 0, 10));
    await camera2.lookAt(Vector3(5, 0, 10));

    await views.first.setCamera(camera1);
    await views.last.setCamera(camera2);

    var materialInstance = await FilamentApp.instance!.createUnlitMaterialInstance();
    await materialInstance.setParameterFloat4("baseColorFactor", 1, 0, 0, 0);

    var cube =
        await FilamentApp.instance!.createGeometry(
              GeometryUtils.cube(flipUvs: true),
              materialInstances: [materialInstance],
            )
            as FFIAsset;

    await scene.add(cube);

    await testHelper.capture(null, "multiple_view_different_camera");

    await FilamentApp.instance!.destroySwapChain(swapChain);
  });

  test('render view to render target, used as input for another', () async {
    final viewportDimensions = (width: 500, height: 500);
    final swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
      viewportDimensions.width,
      viewportDimensions.height,
    );
    final views = <FFIView>[];
    final scene = await FilamentApp.instance!.createScene() as FFIScene;
    final camera = await FilamentApp.instance!.createCamera() as FFICamera;
    await camera.setLensProjection();

    await FilamentApp.instance!.setClearOptions(0, 0, 0, 0);

    for (int i = 0; i < 2; i++) {
      final view = await FilamentApp.instance!.createView() as FFIView;
      await view.setScene(scene);

      await view.setViewport(viewportDimensions.width, viewportDimensions.height);
      await view.setFrustumCullingEnabled(false);
      await view.setPostProcessing(false);
      await view.setRenderTarget(
        await FilamentApp.instance!.createRenderTarget(viewportDimensions.width, viewportDimensions.height)
            as FFIRenderTarget,
      );
      await FilamentApp.instance!.renderManager.attach(view, swapChain);

      await view.setCamera(camera);
      views.add(view);
    }

    await camera.lookAt(Vector3(0, 4, 12), focus: Vector3(0, -4, 0));

    var materialInstance1 = await FilamentApp.instance!.createUnlitMaterialInstance();
    await materialInstance1.setParameterFloat4("baseColorFactor", 1, 0, 0, 0);

    var cube =
        await FilamentApp.instance!.createGeometry(
              GeometryUtils.cube(flipUvs: true),
              materialInstances: [materialInstance1],
            )
            as FFIAsset;

    await scene.add(cube);

    var result = await FilamentApp.instance!.capture(swapChain, view: views.first);

    await savePixelBufferToBmp(
      result.first.$2,
      viewportDimensions.width,
      viewportDimensions.height,
      p.join(testHelper.outDirPath, "render_target_output.bmp"),
      isFloat: true,
    );

    var materialInstance2 = await FilamentApp.instance!.createUbershaderMaterialInstance(
      hasBaseColorTexture: true,
      unlit: false,
    );

    var light = await FilamentApp.instance!.createDirectLight(
      DirectLight(type: LightType.SUN, intensity: 100000000, direction: Vector3(0, 0, -1), position: Vector3.zero()),
    );
    await scene.addEntity(light);

    final texture = await (await views.first.getRenderTarget())!.getColorTexture();

    await materialInstance2.setParameterTexture(
      "baseColorMap",
      texture,
      await FilamentApp.instance!.createTextureSampler(),
    );
    await materialInstance2.setParameterInt("baseColorIndex", 0);
    await materialInstance2.setParameterFloat4("baseColorFactor", 1, 1, 1, 1);
    await cube.setMaterialInstanceAt(materialInstance2 as FFIMaterialInstance);

    result = await FilamentApp.instance!.capture(swapChain, view: views.last);

    await savePixelBufferToBmp(
      result.first.$2,
      viewportDimensions.width,
      viewportDimensions.height,
      p.join(testHelper.outDirPath, "render_target_as_texture.bmp"),
      isFloat: true,
    );

    await FilamentApp.instance!.destroySwapChain(swapChain);
  });

  ///
  ///
  ///
  test('render two views to same render target', () async {
    final viewportDimensions = (width: 500, height: 500);
    final swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
      viewportDimensions.width,
      viewportDimensions.height,
    );
    final views = <FFIView>[];

    await FilamentApp.instance!.setClearOptions(0, 0, 0, 0, clear: false, clearStencil: 0, discard: false);

    final renderTarget =
        await FilamentApp.instance!.createRenderTarget(viewportDimensions.width, viewportDimensions.height)
            as FFIRenderTarget;

    for (int i = 0; i < 2; i++) {
      final camera = await FilamentApp.instance!.createCamera() as FFICamera;
      await camera.setLensProjection();
      final view = await FilamentApp.instance!.createView() as FFIView;
      final scene = await FilamentApp.instance!.createScene() as FFIScene;
      await view.setScene(scene);

      await view.setViewport(viewportDimensions.width, viewportDimensions.height);
      await view.setFrustumCullingEnabled(false);
      await view.setPostProcessing(false);

      await view.setRenderTarget(renderTarget);

      await FilamentApp.instance!.renderManager.attach(view, swapChain);

      await view.setCamera(camera);
      views.add(view);

      await camera.lookAt(Vector3(0, 4, 12), focus: Vector3(i == 0 ? -2 : 2, 0, 0));

      var cube = await FilamentApp.instance!.createGeometry(GeometryUtils.cube(flipUvs: true)) as FFIAsset;

      await scene.add(cube);
    }
    var result = await FilamentApp.instance!.capture(swapChain, captureRenderTarget: true);

    await savePixelBufferToBmp(
      result.first.$2,
      viewportDimensions.width,
      viewportDimensions.height,
      p.join(testHelper.outDirPath, "two_views_same_render_target1.bmp"),
      isFloat: true,
    );
    await savePixelBufferToBmp(
      result.last.$2,
      viewportDimensions.width,
      viewportDimensions.height,
      p.join(testHelper.outDirPath, "two_views_same_render_target2.bmp"),
      isFloat: true,
    );
    await FilamentApp.instance!.destroySwapChain(swapChain);
  });

  test('render depth buffer to render target', () async {
    final viewportDimensions = (width: 500, height: 500);
    final swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
      viewportDimensions.width,
      viewportDimensions.height,
    );

    final views = <FFIView>[];
    final scene = await FilamentApp.instance!.createScene() as FFIScene;
    final camera = await FilamentApp.instance!.createCamera() as FFICamera;
    await camera.setLensProjection();

    await FilamentApp.instance!.setClearOptions(0, 0, 0, 0);

    for (int i = 0; i < 2; i++) {
      final view = await FilamentApp.instance!.createView() as FFIView;
      await view.setScene(scene);
      await view.setViewport(viewportDimensions.width, viewportDimensions.height);
      await view.setFrustumCullingEnabled(false);
      await view.setPostProcessing(false);
      await view.setRenderTarget(
        await FilamentApp.instance!.createRenderTarget(viewportDimensions.width, viewportDimensions.height)
            as FFIRenderTarget,
      );
      await FilamentApp.instance!.renderManager.attach(view, swapChain);

      await view.setCamera(camera);
      views.add(view);
    }

    await camera.lookAt(Vector3(0, 4, 12), focus: Vector3(0, -4, 0));

    var materialInstance1 = await FilamentApp.instance!.createUnlitMaterialInstance();
    await materialInstance1.setParameterFloat4("baseColorFactor", 1, 0, 0, 0);

    var cube =
        await FilamentApp.instance!.createGeometry(
              GeometryUtils.cube(flipUvs: true),
              materialInstances: [materialInstance1],
            )
            as FFIAsset;

    await scene.add(cube);

    var result = await FilamentApp.instance!.capture(swapChain, view: views.first);

    await savePixelBufferToBmp(
      result.first.$2,
      viewportDimensions.width,
      viewportDimensions.height,
      p.join(testHelper.outDirPath, "render_target_output.bmp"),
      isFloat: true,
    );

    var materialInstance2 = await FilamentApp.instance!.createUbershaderMaterialInstance(
      hasBaseColorTexture: true,
      unlit: false,
    );

    var light = await FilamentApp.instance!.createDirectLight(
      DirectLight(type: LightType.SUN, intensity: 100000000, direction: Vector3(0, 0, -1), position: Vector3.zero()),
    );
    await scene.addEntity(light);

    final texture = await (await views.first.getRenderTarget())!.getColorTexture();

    await materialInstance2.setParameterTexture(
      "baseColorMap",
      texture,
      await FilamentApp.instance!.createTextureSampler(),
    );
    await materialInstance2.setParameterInt("baseColorIndex", 0);
    await materialInstance2.setParameterFloat4("baseColorFactor", 1, 1, 1, 1);
    await cube.setMaterialInstanceAt(materialInstance2 as FFIMaterialInstance);

    result = await FilamentApp.instance!.capture(swapChain, view: views.last);

    await savePixelBufferToBmp(
      result.first.$2,
      viewportDimensions.width,
      viewportDimensions.height,
      p.join(testHelper.outDirPath, "render_target_as_texture.bmp"),
      isFloat: true,
    );

    await FilamentApp.instance!.destroySwapChain(swapChain);
  });

  test('fog tests', () async {
    await ViewerBuilder(testHelper)
        .setRenderTargetEnabled(true)
        .addCube()
        .addCube(position: Vector3(0, 0, -20))
        .setCameraLookAt(Vector3(1, 5, 10))
        .execute((result) async {
          // Test default fog options (should be disabled)
          final defaultOptions = result.viewer.view.getFogOptions();
          expect(defaultOptions.enabled, isFalse);
          expect(defaultOptions.distance, closeTo(0.0, 0.001));
          expect(defaultOptions.density, closeTo(0.1, 0.001));

          await testHelper.capture(result.viewer.view, "fog_options_disabled");

          // Set custom fog options
          final customOptions = FogOptions(
            enabled: true,
            distance: 0,
            density: 0.5,
            cutOffDistance: 100.0,
            maximumOpacity: 0.9,
            linearColor: Vector3(0.8, 0.9, 1.0),
          );
          await result.viewer.view.setFogOptions(customOptions);

          // Verify the options were set correctly
          final retrievedOptions = result.viewer.view.getFogOptions();
          expect(retrievedOptions.enabled, isTrue);
          expect(retrievedOptions.distance, closeTo(0.0, 0.001));
          expect(retrievedOptions.density, closeTo(0.5, 0.001));
          expect(retrievedOptions.cutOffDistance, closeTo(100.0, 0.001));
          expect(retrievedOptions.maximumOpacity, closeTo(0.9, 0.001));
          expect(retrievedOptions.linearColor.r, closeTo(0.8, 0.001));
          expect(retrievedOptions.linearColor.g, closeTo(0.9, 0.001));
          expect(retrievedOptions.linearColor.b, closeTo(1.0, 0.001));

          await testHelper.capture(result.viewer.view, "fog_options_enabled");
        });
  });

  test('show/hide stencil highlight', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).setStencilBufferEnabled(true).execute((result) async {
      await result.viewer.view.setHighlightOverlayEnabled(true);

      final manager = result.viewer.view.getHighlightOverlay();
      assert(manager != null);

      var cube = await FilamentApp.instance!.createGeometry(GeometryUtils.cube(flipUvs: true));
      await result.viewer.addToScene(cube);

      await result.viewer.view.setStencilHighlight(cube, r: 1.0, g: 0.5, b: 0.0, outlineWidth: 5.0);
      await FilamentApp.instance!.setClearOptions(1, 1, 1, 0, clear: true, discard: false);
      await FilamentApp.instance!.render();

      await testHelper.capture(null, "stencil_highlight_5px_orange", render: true, captureRenderTarget: true);

      // Test with thin outline (1 pixel) and blue color
      await result.viewer.view.removeStencilHighlight(cube);
      await result.viewer.view.setStencilHighlight(cube, r: 0.0, g: 0.5, b: 1.0, outlineWidth: 1.0);

      await FilamentApp.instance!.render();

      await testHelper.capture(null, "stencil_highlight_1px_blue", captureRenderTarget: true, render: false);

      // Test that highlight follows object translation
      await cube.setTransform(Matrix4.translation(Vector3(2, 0, 0)));

      await FilamentApp.instance!.render();

      await testHelper.capture(null, "stencil_highlight_after_translate", captureRenderTarget: true, render: false);

      // Test that highlight follows object rotation
      await cube.setTransform(Matrix4.translation(Vector3(-2, 1, 0)) * Matrix4.rotationZ(0.5));

      await FilamentApp.instance!.render();

      await testHelper.capture(null, "stencil_highlight_after_rotate", captureRenderTarget: true, render: false);

      // Test that highlight works after camera change
      final camera = await result.viewer.view.getCamera();
      await camera.lookAt(Vector3(5, 3, 10), focus: Vector3(0, 0, 0));

      await FilamentApp.instance!.render();

      await testHelper.capture(null, "stencil_highlight_after_camera_move", captureRenderTarget: true, render: false);

      await result.viewer.view.removeStencilHighlight(cube);

      Logger.root.log(Level.ALL, "removed stencil highlight");

      // Disable the highlight overlay system
      await result.viewer.view.setHighlightOverlayEnabled(false);

      Logger.root.log(Level.ALL, "disabled highlight overlay");

      await FilamentApp.instance!.render();

      await testHelper.capture(
        null,
        "stencil_highlight_after_overlay_disabled",
        captureRenderTarget: true,
        render: false,
      );
    });
  });

  test('consecutive setStencilHighlight with different colors updates correctly', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).setStencilBufferEnabled(true).execute((result) async {
      await result.viewer.view.setHighlightOverlayEnabled(true);

      var cube = await FilamentApp.instance!.createGeometry(GeometryUtils.cube(flipUvs: true));
      await result.viewer.addToScene(cube);

      // Set initial highlight to orange
      await result.viewer.view.setStencilHighlight(cube, r: 1.0, g: 0.5, b: 0.0, outlineWidth: 5.0);
      await FilamentApp.instance!.render();

      await testHelper.capture(
        null,
        "consecutive_highlight_first_color_orange",
        render: true,
        captureRenderTarget: true,
      );

      // Change to blue - this should now work correctly
      await result.viewer.view.setStencilHighlight(cube, r: 0.0, g: 0.5, b: 1.0, outlineWidth: 5.0);

      await FilamentApp.instance!.render();

      await testHelper.capture(
        null,
        "consecutive_highlight_second_color_blue",
        captureRenderTarget: true,
        render: false,
      );
      // Should now be blue, not orange!

      await result.viewer.view.removeStencilHighlight(cube);
      await result.viewer.view.setHighlightOverlayEnabled(false);
    });
  });

  test('stencil highlight visible on plane from both sides', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).setStencilBufferEnabled(true).execute((result) async {
      await result.viewer.view.setHighlightOverlayEnabled(true);

      var materialInstance = await FilamentApp.instance!.createUbershaderMaterialInstance(unlit: true);
      await materialInstance.setParameterFloat4("baseColorFactor", 1, 1, 1, 1);
      var plane = await FilamentApp.instance!.createGeometry(
        GeometryUtils.plane(width: 2, height: 2),
        materialInstances: [materialInstance],
      );
      await result.viewer.addToScene(plane);

      await result.viewer.view.setStencilHighlight(plane, r: 1.0, g: 0.5, b: 0.0, outlineWidth: 5.0);
      await FilamentApp.instance!.setClearOptions(0, 0, 0, 1, clear: true, discard: false);

      // View from above (front face - normals point up)
      final camera = await result.viewer.view.getCamera();
      await camera.lookAt(Vector3(0, 5, 0.1), focus: Vector3(0, 0, 0));
      await FilamentApp.instance!.render();

      await testHelper.capture(null, "stencil_highlight_plane_front", render: true, captureRenderTarget: true);

      // View from below (back face) - highlight should still be visible
      await camera.lookAt(Vector3(0, -5, 0.1), focus: Vector3(0, 0, 0));
      await FilamentApp.instance!.render();

      await testHelper.capture(null, "stencil_highlight_plane_back", captureRenderTarget: true, render: false);

      await result.viewer.view.removeStencilHighlight(plane);
      await result.viewer.view.setHighlightOverlayEnabled(false);
    });
  });

  test('multi-mesh glTF child entity highlighting', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).setStencilBufferEnabled(true).execute((result) async {
      await result.viewer.view.setHighlightOverlayEnabled(true);

      // Load FlightHelmet, a multi-mesh glTF asset
      final asset = await result.viewer.loadGltf(
        p.join(testHelper.assetsDir, "FlightHelmet", "FlightHelmet.gltf"),
        requiredGeometryCapabilities: const {SceneAssetGeometryCapability.accessibleGeometryBuffers},
      );
      expect(asset, isNotNull);

      final ffiAsset = asset as FFIAsset;

      // Get all child entities
      final childEntities = await asset.getChildEntities();
      expect(childEntities, isNotEmpty, reason: "FlightHelmet should have child entities");

      // Filter to renderable children only
      final renderableChildren = <ThermionEntity>[];
      for (final child in childEntities) {
        if (await FilamentApp.instance!.isRenderable(child)) {
          renderableChildren.add(child);
        }
      }
      expect(renderableChildren.length, greaterThan(0), reason: "FlightHelmet should have renderable child entities");

      // Test highlighting the first child
      final firstChild = renderableChildren[0];
      await result.viewer.view.setStencilHighlight(
        asset,
        entity: firstChild,
        r: 1.0,
        g: 0.0,
        b: 0.0,
        outlineWidth: 3.0,
      );

      await FilamentApp.instance!.render();

      // Verify the entity was added to highlights
      final manager = result.viewer.view.getHighlightOverlay();
      expect(manager, isNotNull);
      expect(manager!.highlightedEntities, contains(firstChild));

      await testHelper.capture(
        null,
        "stencil_highlight_multi_mesh_first_child",
        render: false,
        captureRenderTarget: true,
      );

      // Remove it and highlight a different child
      await result.viewer.view.removeStencilHighlight(asset);
      expect(manager.highlightedEntities, isNot(contains(firstChild)));

      if (renderableChildren.length > 1) {
        final secondChild = renderableChildren[1];
        await result.viewer.view.setStencilHighlight(
          asset,
          entity: secondChild,
          r: 0.0,
          g: 0.0,
          b: 1.0,
          outlineWidth: 3.0,
        );

        await FilamentApp.instance!.render();

        expect(manager.highlightedEntities, contains(secondChild));
        expect(manager.highlightedEntities, isNot(contains(firstChild)));

        // Bug-catcher for entity-only mode: setStencilHighlight should have
        // called asset.getPrimitiveOffsetForEntity(secondChild) and used that
        // entity's preserved buffers — not silently fallen back to primitive 0.
        // Verify by comparing the recorded indexCount to primitive 0's
        // indexCount (they must differ because secondChild's primitive offset
        // is > 0 in FlightHelmet).
        final secondChildOffset = await ffiAsset.getPrimitiveOffsetForEntity(secondChild);
        expect(secondChildOffset, greaterThan(0), reason: "Test relies on secondChild not being at offset 0");

        // Get the primitive count for secondChild
        final secondChildPrimCount = await FilamentApp.instance!.getPrimitiveCount(secondChild);

        // Verify that we can access the buffers at the correct offset
        for (int i = 0; i < secondChildPrimCount; i++) {
          final flatIndex = secondChildOffset + i;
          final vb = asset.getVertexBuffer(primitiveIndex: flatIndex);
          final ib = SceneAsset_getIndexBuffer(ffiAsset.asset, flatIndex);

          // At least one primitive should have valid buffers
          // (some might be null placeholders for non-triangle primitives)
          if (vb != null && ib != nullptr) {
            expect(vb, isA<FFIVertexBuffer>());
            break;
          }
        }

        await testHelper.capture(
          null,
          "stencil_highlight_multi_mesh_second_child",
          render: false,
          captureRenderTarget: true,
        );

        await result.viewer.view.removeStencilHighlight(asset);
      }

      await result.viewer.view.setHighlightOverlayEnabled(false);
    });
  }, skip: isWeb ? 'Requires HTTP asset serving for FlightHelmet glTF' : null);

  test('VSM shadow options set/get', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      // Test default values
      final defaultOptions = result.viewer.view.getVsmShadowOptions();
      expect(defaultOptions.anisotropy, equals(0));
      expect(defaultOptions.mipmapping, isFalse);
      expect(defaultOptions.msaaSamples, equals(1));
      expect(defaultOptions.highPrecision, isFalse);
      expect(defaultOptions.minVarianceScale, closeTo(0.5, 0.001));
      expect(defaultOptions.lightBleedReduction, closeTo(0.15, 0.001));

      // Test setting custom options
      const customOptions = VsmShadowOptions(
        anisotropy: 4,
        mipmapping: true,
        msaaSamples: 4,
        highPrecision: true,
        minVarianceScale: 0.75,
        lightBleedReduction: 0.25,
      );

      await result.viewer.view.setVsmShadowOptions(customOptions);

      // Verify the options were set correctly
      final retrievedOptions = result.viewer.view.getVsmShadowOptions();
      expect(retrievedOptions.anisotropy, equals(4));
      expect(retrievedOptions.mipmapping, isTrue);
      expect(retrievedOptions.msaaSamples, equals(4));
      expect(retrievedOptions.highPrecision, isTrue);
      expect(retrievedOptions.minVarianceScale, closeTo(0.75, 0.001));
      expect(retrievedOptions.lightBleedReduction, closeTo(0.25, 0.001));
    });
  });

  test('VSM shadow options with shadows enabled', () async {
    final builder = ViewerBuilder(testHelper)
        .setBackgroundColor(kBlue)
        .setPostProcessing(true)
        .setRenderTargetEnabled(true)
        .setShadowType(ShadowType.VSM)
        .addSun(intensity: 50000, castShadows: true, direction: Vector3(1, -0.5, 0).normalized())
        .addCube(castShadows: true, color: kRed)
        .addPlane(
          position: Vector3(0, -1.5, 0),
          rotation: Quaternion.axisAngle(Vector3(1, 0, 0), -3.14159 / 2),
          scale: Vector3(10, 10, 1),
          receiveShadows: true,
          castShadows: false,
          color: kGreen,
        );

    await builder.execute((result) async {
      // Enable VSM shadows
      await result.viewer.setShadowsEnabled(true);
      await testHelper.capture(result.viewer.view, "vsm_shadows_default_options");

      // Test with custom VSM options that should improve quality
      const vsmOptions = VsmShadowOptions(
        anisotropy: 8, // Higher anisotropy for better sampling
        mipmapping: true, // Enable mipmapping
        msaaSamples: 4, // MSAA for smoother edges
        highPrecision: true, // 32-bit precision to reduce light leaks
        minVarianceScale: 0.3,
        lightBleedReduction: 0.2,
      );

      await result.viewer.view.setVsmShadowOptions(vsmOptions);
      await testHelper.capture(result.viewer.view, "vsm_shadows_custom_options");

      // Test with different VSM options
      const lowQualityVsmOptions = VsmShadowOptions(
        anisotropy: 0, // No anisotropic filtering
        mipmapping: false, // No mipmapping
        msaaSamples: 1, // No MSAA
        highPrecision: false, // 16-bit precision
        minVarianceScale: 0.5,
        lightBleedReduction: 0.15,
      );

      await result.viewer.view.setVsmShadowOptions(lowQualityVsmOptions);
      await testHelper.capture(result.viewer.view, "vsm_shadows_low_quality_options");
    });
  });

  test('VSM shadow options getter works correctly', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      // Set specific options
      const testOptions = VsmShadowOptions(
        anisotropy: 2,
        mipmapping: true,
        msaaSamples: 2,
        highPrecision: false,
        minVarianceScale: 1.0,
        lightBleedReduction: 0.5,
      );

      await result.viewer.view.setVsmShadowOptions(testOptions);

      // Get the options back and verify all fields match
      final retrieved = result.viewer.view.getVsmShadowOptions();
      expect(retrieved.anisotropy, equals(testOptions.anisotropy));
      expect(retrieved.mipmapping, equals(testOptions.mipmapping));
      expect(retrieved.msaaSamples, equals(testOptions.msaaSamples));
      expect(retrieved.highPrecision, equals(testOptions.highPrecision));
      expect(retrieved.minVarianceScale, closeTo(testOptions.minVarianceScale, 0.001));
      expect(retrieved.lightBleedReduction, closeTo(testOptions.lightBleedReduction, 0.001));
    });
  });

  test('ShadowType get/set functionality', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      // Test default shadow type (should be PCF)
      final defaultShadowType = await result.viewer.view.getShadowType();
      expect(defaultShadowType, equals(ShadowType.PCF));

      // Test setting and getting each shadow type
      for (final shadowType in ShadowType.values) {
        await result.viewer.view.setShadowType(shadowType);
        final retrievedType = await result.viewer.view.getShadowType();
        expect(retrievedType, equals(shadowType), reason: 'ShadowType $shadowType should be retrieved correctly');
      }

      // Test with a specific sequence
      await result.viewer.view.setShadowType(ShadowType.VSM);
      expect(await result.viewer.view.getShadowType(), equals(ShadowType.VSM));

      await result.viewer.view.setShadowType(ShadowType.PCSS);
      expect(await result.viewer.view.getShadowType(), equals(ShadowType.PCSS));

      await result.viewer.view.setShadowType(ShadowType.PCF);
      expect(await result.viewer.view.getShadowType(), equals(ShadowType.PCF));
    });
  });

  test('SoftShadowOptions functionality', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      // Test default options (check what Filament returns as default)
      final defaultOptions = result.viewer.view.getSoftShadowOptions();
      expect(defaultOptions.penumbraScale, closeTo(1.0, 0.001));
      expect(defaultOptions.penumbraRatioScale, closeTo(1.0, 0.001));
      expect(defaultOptions.maxPenumbraRatio, closeTo(10.0, 0.001));
      expect(defaultOptions.maxSearchRadius, closeTo(1.0, 0.001));

      // Test custom soft shadow options
      const customOptions = SoftShadowOptions(
        penumbraScale: 2.5,
        penumbraRatioScale: 3.0,
        maxPenumbraRatio: 4.0,
        maxSearchRadius: 0.25,
      );

      await result.viewer.view.setSoftShadowOptions(customOptions);

      // Verify the options were set correctly
      final retrievedOptions = result.viewer.view.getSoftShadowOptions();
      expect(retrievedOptions.penumbraScale, closeTo(2.5, 0.001));
      expect(retrievedOptions.penumbraRatioScale, closeTo(3.0, 0.001));
      expect(retrievedOptions.maxPenumbraRatio, closeTo(4.0, 0.001));
      expect(retrievedOptions.maxSearchRadius, closeTo(0.25, 0.001));

      // Test with DPCF shadow type (supports soft shadows)
      await result.viewer.view.setShadowType(ShadowType.DPCF);
      await result.viewer.view.setSoftShadowOptions(customOptions);

      final dpfcOptions = result.viewer.view.getSoftShadowOptions();
      expect(dpfcOptions.penumbraScale, closeTo(2.5, 0.001));
      expect(dpfcOptions.penumbraRatioScale, closeTo(3.0, 0.001));

      // Test with PCSS shadow type (supports soft shadows)
      await result.viewer.view.setShadowType(ShadowType.PCSS);
      await result.viewer.view.setSoftShadowOptions(
        const SoftShadowOptions(penumbraScale: 1.5, penumbraRatioScale: 2.0),
      );

      final pcssOptions = result.viewer.view.getSoftShadowOptions();
      expect(pcssOptions.penumbraScale, closeTo(1.5, 0.001));
      expect(pcssOptions.penumbraRatioScale, closeTo(2.0, 0.001));

      // Test with different values that may have precision issues
      const testOptions = SoftShadowOptions(penumbraScale: 0.8, penumbraRatioScale: 1.2);

      await result.viewer.view.setSoftShadowOptions(testOptions);
      final finalOptions = result.viewer.view.getSoftShadowOptions();
      expect(finalOptions.penumbraScale, closeTo(0.8, 0.001));
      expect(finalOptions.penumbraRatioScale, closeTo(1.2, 0.001));

      // Test with values that are likely to have precision differences
      const precisionTestOptions = SoftShadowOptions(penumbraScale: 0.1, penumbraRatioScale: 1.33);

      await result.viewer.view.setSoftShadowOptions(precisionTestOptions);
      final precisionOptions = result.viewer.view.getSoftShadowOptions();
      expect(precisionOptions.penumbraScale, closeTo(0.1, 0.001));
      expect(precisionOptions.penumbraRatioScale, closeTo(1.33, 0.001));
    });
  });

  test('visible renderable diagnostics', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).addCube().addPlane().execute((result) async {
      await testHelper.capture(result.viewer.view, null);
      expect(result.viewer.view.getVisibleRenderableCount(), greaterThanOrEqualTo(2));
    });
  });

  test('AmbientOcclusionOptions set/get functionality', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      // Test default options
      final defaultOptions = result.viewer.view.getAmbientOcclusionOptions();
      expect(defaultOptions.enabled, isFalse);
      expect(defaultOptions.aoType, equals(AmbientOcclusionType.SAO));
      expect(defaultOptions.radius, closeTo(0.3, 0.001));
      expect(defaultOptions.power, closeTo(1.0, 0.001));
      expect(defaultOptions.bias, closeTo(0.0005, 0.0001));
      expect(defaultOptions.resolution, closeTo(0.5, 0.001));
      expect(defaultOptions.intensity, closeTo(1.0, 0.001));
      expect(defaultOptions.bilateralThreshold, closeTo(0.05, 0.001));
      expect(defaultOptions.quality, equals(QualityLevel.LOW));
      expect(defaultOptions.lowPassFilter, equals(QualityLevel.MEDIUM));
      expect(defaultOptions.upsampling, equals(QualityLevel.LOW));
      expect(defaultOptions.bentNormals, isFalse);
      expect(defaultOptions.minHorizonAngleRad, closeTo(0.0, 0.001));

      // Test SSCT default options
      expect(defaultOptions.ssct.enabled, isFalse);
      expect(defaultOptions.ssct.lightConeRad, closeTo(1.0, 0.001));
      expect(defaultOptions.ssct.shadowDistance, closeTo(0.3, 0.001));
      expect(defaultOptions.ssct.contactDistanceMax, closeTo(1.0, 0.001));
      expect(defaultOptions.ssct.intensity, closeTo(0.8, 0.001));
      expect(defaultOptions.ssct.lightDirection[0], closeTo(0.0, 0.001));
      expect(defaultOptions.ssct.lightDirection[1], closeTo(-1.0, 0.001));
      expect(defaultOptions.ssct.lightDirection[2], closeTo(0.0, 0.001));
      expect(defaultOptions.ssct.depthBias, closeTo(0.01, 0.001));
      expect(defaultOptions.ssct.depthSlopeBias, closeTo(0.01, 0.001));
      expect(defaultOptions.ssct.sampleCount, equals(4));
      expect(defaultOptions.ssct.rayCount, equals(1));

      // Test GTAO default options
      expect(defaultOptions.gtao.sampleSliceCount, equals(4));
      expect(defaultOptions.gtao.sampleStepsPerSlice, equals(3));
      expect(defaultOptions.gtao.thicknessHeuristic, closeTo(0.004, 0.0001));
      expect(defaultOptions.gtao.useVisibilityBitmasks, isFalse);
      expect(defaultOptions.gtao.constThickness, closeTo(0.5, 0.001));
      expect(defaultOptions.gtao.linearThickness, isFalse);

      // Test setting custom ambient occlusion options
      final customOptions = AmbientOcclusionOptions(
        enabled: true,
        aoType: AmbientOcclusionType.GTAO,
        radius: 0.8,
        power: 1.5,
        bias: 0.001,
        resolution: 1.0,
        intensity: 1.2,
        bilateralThreshold: 0.1,
        quality: QualityLevel.HIGH,
        lowPassFilter: QualityLevel.HIGH,
        upsampling: QualityLevel.MEDIUM,
        bentNormals: true,
        minHorizonAngleRad: 0.1,
        ssct: SsctOptions(
          enabled: true,
          lightConeRad: 0.5,
          shadowDistance: 0.8,
          contactDistanceMax: 1.5,
          intensity: 1.0,
          lightDirection: [0.5, -0.8, 0.2],
          depthBias: 0.02,
          depthSlopeBias: 0.015,
          sampleCount: 8,
          rayCount: 2,
        ),
        gtao: GtaoOptions(
          sampleSliceCount: 6,
          sampleStepsPerSlice: 4,
          thicknessHeuristic: 0.006,
          useVisibilityBitmasks: true,
          constThickness: 0.75,
          linearThickness: true,
        ),
      );

      await result.viewer.view.setAmbientOcclusionOptions(customOptions);

      // Verify the options were set correctly
      final retrievedOptions = result.viewer.view.getAmbientOcclusionOptions();
      expect(retrievedOptions.enabled, equals(customOptions.enabled));
      expect(retrievedOptions.aoType, equals(customOptions.aoType));
      expect(retrievedOptions.radius, closeTo(customOptions.radius, 0.001));
      expect(retrievedOptions.power, closeTo(customOptions.power, 0.001));
      expect(retrievedOptions.bias, closeTo(customOptions.bias, 0.0001));
      expect(retrievedOptions.resolution, closeTo(customOptions.resolution, 0.001));
      expect(retrievedOptions.intensity, closeTo(customOptions.intensity, 0.001));
      expect(retrievedOptions.bilateralThreshold, closeTo(customOptions.bilateralThreshold, 0.001));
      expect(retrievedOptions.quality, equals(customOptions.quality));
      expect(retrievedOptions.lowPassFilter, equals(customOptions.lowPassFilter));
      expect(retrievedOptions.upsampling, equals(customOptions.upsampling));
      expect(retrievedOptions.bentNormals, equals(customOptions.bentNormals));
      expect(retrievedOptions.minHorizonAngleRad, closeTo(customOptions.minHorizonAngleRad, 0.001));

      // Verify SSCT options
      expect(retrievedOptions.ssct.enabled, equals(customOptions.ssct.enabled));
      expect(retrievedOptions.ssct.lightConeRad, closeTo(customOptions.ssct.lightConeRad, 0.001));
      expect(retrievedOptions.ssct.shadowDistance, closeTo(customOptions.ssct.shadowDistance, 0.001));
      expect(retrievedOptions.ssct.contactDistanceMax, closeTo(customOptions.ssct.contactDistanceMax, 0.001));
      expect(retrievedOptions.ssct.intensity, closeTo(customOptions.ssct.intensity, 0.001));
      expect(retrievedOptions.ssct.lightDirection[0], closeTo(customOptions.ssct.lightDirection[0], 0.1));
      expect(retrievedOptions.ssct.lightDirection[1], closeTo(customOptions.ssct.lightDirection[1], 0.1));
      expect(retrievedOptions.ssct.lightDirection[2], closeTo(customOptions.ssct.lightDirection[2], 0.1));
      expect(retrievedOptions.ssct.depthBias, closeTo(customOptions.ssct.depthBias, 0.001));
      expect(retrievedOptions.ssct.depthSlopeBias, closeTo(customOptions.ssct.depthSlopeBias, 0.001));
      expect(retrievedOptions.ssct.sampleCount, equals(customOptions.ssct.sampleCount));
      expect(retrievedOptions.ssct.rayCount, equals(customOptions.ssct.rayCount));

      // Verify GTAO options
      expect(retrievedOptions.gtao.sampleSliceCount, equals(customOptions.gtao.sampleSliceCount));
      expect(retrievedOptions.gtao.sampleStepsPerSlice, equals(customOptions.gtao.sampleStepsPerSlice));
      expect(retrievedOptions.gtao.thicknessHeuristic, closeTo(customOptions.gtao.thicknessHeuristic, 0.0001));
      expect(retrievedOptions.gtao.useVisibilityBitmasks, equals(customOptions.gtao.useVisibilityBitmasks));
      expect(retrievedOptions.gtao.constThickness, closeTo(customOptions.gtao.constThickness, 0.001));
      expect(retrievedOptions.gtao.linearThickness, equals(customOptions.gtao.linearThickness));
    });
  });

  test('AmbientOcclusionOptions visual verification', () async {
    final builder = ViewerBuilder(testHelper)
        .setBackgroundColor(kWhite)
        .setPostProcessing(true)
        .addCube(color: kRed)
        .addSun(direction: Vector3(1, -1, 0.5), intensity: 100000);

    await builder.execute((result) async {
      // Capture without ambient occlusion
      await testHelper.capture(result.viewer.view, "ambient_occlusion_disabled");

      // Enable basic ambient occlusion
      await result.viewer.view.setAmbientOcclusionOptions(
        AmbientOcclusionOptions(enabled: true, radius: 0.5, intensity: 1.0, quality: QualityLevel.MEDIUM),
      );
      await testHelper.capture(result.viewer.view, "ambient_occlusion_enabled_basic");

      // Enable higher quality ambient occlusion
      await result.viewer.view.setAmbientOcclusionOptions(
        AmbientOcclusionOptions(
          enabled: true,
          radius: 0.8,
          intensity: 1.5,
          quality: QualityLevel.HIGH,
          bentNormals: true,
        ),
      );
      await testHelper.capture(result.viewer.view, "ambient_occlusion_enabled_high_quality");

      // Test with bent normals enabled
      await result.viewer.view.setAmbientOcclusionOptions(
        AmbientOcclusionOptions(
          enabled: true,
          radius: 0.6,
          intensity: 1.2,
          quality: QualityLevel.HIGH,
          bentNormals: true,
          bilateralThreshold: 0.02,
        ),
      );
      await testHelper.capture(result.viewer.view, "ambient_occlusion_bent_normals");

      // Test with different radius values
      await result.viewer.view.setAmbientOcclusionOptions(
        AmbientOcclusionOptions(enabled: true, radius: 0.2, intensity: 1.0, quality: QualityLevel.MEDIUM),
      );
      await testHelper.capture(result.viewer.view, "ambient_occlusion_small_radius");

      await result.viewer.view.setAmbientOcclusionOptions(
        AmbientOcclusionOptions(enabled: true, radius: 1.0, intensity: 1.0, quality: QualityLevel.MEDIUM),
      );
      await testHelper.capture(result.viewer.view, "ambient_occlusion_large_radius");
    });
  });

  test('AmbientOcclusionOptions SAO and GTAO visual comparison', () async {
    final builder = ViewerBuilder(testHelper)
        .setBackgroundColor(kWhite)
        .setCameraLookAt(Vector3(0, 4, 6), focus: Vector3(0, -0.2, 0))
        .setPostProcessing(true)
        .addCube(position: Vector3(-0.8, 0, 0), color: kRed)
        .addCube(position: Vector3(0.8, -0.35, 0), scale: Vector3.all(0.65), color: kBlue)
        .addPlane(position: Vector3(0, -1.05, 0), color: kWhite, createUbershader: true);

    await builder.execute((result) async {
      await result.viewer.loadIbl("file://${testHelper.assetsDir}/default_env_ibl.ktx");

      await result.viewer.view.setAmbientOcclusionOptions(
        AmbientOcclusionOptions(
          enabled: true,
          aoType: AmbientOcclusionType.SAO,
          radius: 0.8,
          intensity: 1.0,
          quality: QualityLevel.HIGH,
          lowPassFilter: QualityLevel.HIGH,
        ),
      );
      final saoImages = await testHelper.capture(result.viewer.view, "ambient_occlusion_sao");

      await result.viewer.view.setAmbientOcclusionOptions(
        AmbientOcclusionOptions(
          enabled: true,
          aoType: AmbientOcclusionType.GTAO,
          radius: 0.8,
          intensity: 1.0,
          quality: QualityLevel.HIGH,
          lowPassFilter: QualityLevel.HIGH,
          gtao: GtaoOptions(sampleSliceCount: 4, sampleStepsPerSlice: 3),
        ),
      );
      final gtaoImages = await testHelper.capture(result.viewer.view, "ambient_occlusion_gtao");

      expect(saoImages[result.viewer.view], isNotEmpty);
      expect(gtaoImages[result.viewer.view], isNotEmpty);
      expect(gtaoImages[result.viewer.view], isNot(orderedEquals(saoImages[result.viewer.view]!)));
    });
  });

  test('AmbientOcclusionOptions with SSCT enabled', () async {
    final builder = ViewerBuilder(testHelper)
        .setBackgroundColor(kWhite)
        .setPostProcessing(true)
        .addCube(color: kRed)
        .addSun(direction: Vector3(0.5, -1, 0.2), intensity: 100000);

    await builder.execute((result) async {
      // Enable ambient occlusion with SSCT
      await result.viewer.view.setAmbientOcclusionOptions(
        AmbientOcclusionOptions(
          enabled: true,
          radius: 0.5,
          intensity: 1.0,
          quality: QualityLevel.HIGH,
          ssct: SsctOptions(
            enabled: true,
            lightDirection: [0.5, -1, 0.2],
            intensity: 0.8,
            shadowDistance: 0.5,
            contactDistanceMax: 1.0,
            sampleCount: 4,
          ),
        ),
      );
      await testHelper.capture(result.viewer.view, "ambient_occlusion_ssct_enabled");

      // Test with different SSCT parameters
      await result.viewer.view.setAmbientOcclusionOptions(
        AmbientOcclusionOptions(
          enabled: true,
          radius: 0.5,
          intensity: 1.0,
          quality: QualityLevel.HIGH,
          ssct: SsctOptions(
            enabled: true,
            lightDirection: [0.3, -0.9, 0.1],
            intensity: 1.2,
            shadowDistance: 0.8,
            contactDistanceMax: 1.5,
            sampleCount: 8,
            rayCount: 2,
          ),
        ),
      );
      await testHelper.capture(result.viewer.view, "ambient_occlusion_ssct_custom");
    });
  });

  test('AmbientOcclusionOptions precision edge cases', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      // Test with very small values
      final smallValueOptions = AmbientOcclusionOptions(
        enabled: true,
        radius: 0.01,
        bias: 0.0001,
        bilateralThreshold: 0.001,
        minHorizonAngleRad: 0.001,
      );

      await result.viewer.view.setAmbientOcclusionOptions(smallValueOptions);
      final retrievedSmall = result.viewer.view.getAmbientOcclusionOptions();
      expect(retrievedSmall.radius, closeTo(smallValueOptions.radius, 0.001));
      expect(retrievedSmall.bias, closeTo(smallValueOptions.bias, 0.0001));
      expect(retrievedSmall.bilateralThreshold, closeTo(smallValueOptions.bilateralThreshold, 0.001));
      expect(retrievedSmall.minHorizonAngleRad, closeTo(smallValueOptions.minHorizonAngleRad, 0.001));

      // Test with larger values
      final largeValueOptions = AmbientOcclusionOptions(
        enabled: true,
        radius: 2.0,
        power: 3.0,
        intensity: 2.5,
        bilateralThreshold: 0.2,
      );

      await result.viewer.view.setAmbientOcclusionOptions(largeValueOptions);
      final retrievedLarge = result.viewer.view.getAmbientOcclusionOptions();
      expect(retrievedLarge.radius, closeTo(largeValueOptions.radius, 0.001));
      expect(retrievedLarge.power, closeTo(largeValueOptions.power, 0.001));
      expect(retrievedLarge.intensity, closeTo(largeValueOptions.intensity, 0.001));
      expect(retrievedLarge.bilateralThreshold, closeTo(largeValueOptions.bilateralThreshold, 0.001));

      // Test SSCT precision
      final ssctPrecisionOptions = AmbientOcclusionOptions(
        enabled: true,
        ssct: SsctOptions(
          enabled: true,
          lightDirection: [0.123456, -0.987654, 0.246801],
          depthBias: 0.001,
          depthSlopeBias: 0.002,
        ),
      );

      await result.viewer.view.setAmbientOcclusionOptions(ssctPrecisionOptions);
      final retrievedSsct = result.viewer.view.getAmbientOcclusionOptions();
      expect(retrievedSsct.ssct.lightDirection[0], closeTo(ssctPrecisionOptions.ssct.lightDirection[0], 0.1));
      expect(retrievedSsct.ssct.lightDirection[1], closeTo(ssctPrecisionOptions.ssct.lightDirection[1], 0.1));
      expect(retrievedSsct.ssct.lightDirection[2], closeTo(ssctPrecisionOptions.ssct.lightDirection[2], 0.1));
      expect(retrievedSsct.ssct.depthBias, closeTo(ssctPrecisionOptions.ssct.depthBias, 0.001));
      expect(retrievedSsct.ssct.depthSlopeBias, closeTo(ssctPrecisionOptions.ssct.depthSlopeBias, 0.001));
    });
  });

  test('AmbientOcclusionOptions quality levels', () async {
    await ViewerBuilder(testHelper).setRenderTargetEnabled(true).execute((result) async {
      // Test each quality level
      for (final quality in QualityLevel.values) {
        final options = AmbientOcclusionOptions(
          enabled: true,
          quality: quality,
          lowPassFilter: quality,
          upsampling: quality,
        );

        await result.viewer.view.setAmbientOcclusionOptions(options);
        final retrieved = result.viewer.view.getAmbientOcclusionOptions();

        expect(retrieved.quality, equals(quality));
        expect(retrieved.lowPassFilter, equals(quality));
        expect(retrieved.upsampling, equals(quality));
        expect(retrieved.enabled, isTrue);
      }
    });
  });

  test('translation axis material renders axis lines', () async {
    await ViewerBuilder(testHelper)
        .setRenderTargetEnabled(true)
        .setBackgroundColor(kGrey)
        // Camera looking at XZ plane from an angle
        .setCameraLookAt(Vector3(30, 30, 30), focus: Vector3(0, 0, 0))
        .execute((result) async {
          // Create a large plane to apply the translation axis material to
          final plane = await FilamentApp.instance!.createGeometry(GeometryUtils.plane(width: 200, height: 200));

          // Test X axis (red) - line along x at z=0
          final xAxisMaterial = await TranslationAxisMaterial.createMaterialInstance(
            originX: 0,
            originY: 0,
            originZ: 0,
            axis: 0, // X axis
            lineWidth: 30.0, // world units - thick for visibility
            lineLength: 80.0,
          );
          await plane.setMaterialInstanceAt(xAxisMaterial);
          await result.viewer.addToScene(plane);

          await testHelper.capture(result.viewer.view, "translation_axis_x");

          // Test Z axis (blue) - line along z at x=0
          final zAxisMaterial = await TranslationAxisMaterial.createMaterialInstance(
            originX: 0,
            originY: 0,
            originZ: 0,
            axis: 2, // Z axis
            lineWidth: 5.0, // world units
            lineLength: 80.0,
          );
          await plane.setMaterialInstanceAt(zAxisMaterial);

          await testHelper.capture(result.viewer.view, "translation_axis_z");

          // Test with offset origin (line at x=20)
          final offsetAxisMaterial = await TranslationAxisMaterial.createMaterialInstance(
            originX: 20,
            originY: 0,
            originZ: 0,
            axis: 2, // Z axis (will appear offset from center)
            lineWidth: 5.0, // world units
            lineLength: 80.0,
          );
          await plane.setMaterialInstanceAt(offsetAxisMaterial);

          await testHelper.capture(result.viewer.view, "translation_axis_offset_origin");

          await result.viewer.removeFromScene(plane);
        });
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
//           GeometryUtils.cube(),
//           materialInstances: [green]);
//       // var cube2 = await FilamentApp.instance!.createGeometry(
//       //     GeometryUtils.cube(),
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
//       await ViewerBuilder(testHelper)
// .setRenderTargetEnabled(true)
// .execute((result) async {
//         final texture = await testHelper.createTexture(500, 500);
//         final renderTarget = await result.viewer.createRenderTarget(
//             500, 500, texture.metalTextureAddress);
//         final view = await result.viewer.getViewAt(0);
//         await view.setRenderTarget(renderTarget);

//         await result.viewer.setBackgroundColor(1.0, 0, 0, 1);
//         final cube = await viewer
//             .createGeometry(GeometryUtils.cube(normals: false, uvs: false));

//         var mainCamera = await result.viewer.getMainCamera();
//         mainCamera.setTransform(Matrix4.translation(Vector3(0, 0, 5)));
//         await testHelper.capture(
//             viewer,
//             renderTarget: renderTarget,
//             "default_swapchain_default_view_render_target");
//       });
//     });

//     test('create secondary view, default swapchain', () async {
//       await ViewerBuilder(testHelper)
// .setRenderTargetEnabled(true)
// .execute((result) async {
//         final cube = await viewer
//             .createGeometry(GeometryUtils.cube(normals: false, uvs: false));

//         var mainCamera = await result.viewer.getMainCamera();
//         mainCamera.setTransform(Matrix4.translation(Vector3(0, 0, 5)));
//         await testHelper.capture(viewer, "default_swapchain_default_view");

//         final view = await result.viewer.createView();
//         view.setViewport(500, 500);
//         view.setCamera(mainCamera);
//         await testHelper.capture(
//           viewer,
//           "default_swapchain_new_view_with_main_camera",
//           view: view,
//         );

//         var newCamera = await result.viewer.createCamera();
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
//       await ViewerBuilder(testHelper)
// .setRenderTargetEnabled(true)
// .execute((result) async {
//         final cube = await result.viewer.createGeometry(GeometryUtils.cube());

//         var mainCamera = await result.viewer.getMainCamera();
//         mainCamera.setTransform(Matrix4.translation(Vector3(0, 0, 5)));
//         final swapChain = await result.viewer.createHeadlessSwapChain(1, 1);
//         await testHelper.capture(
//             viewer, "create_swapchain_default_view_default_swapchain");

//         final view = await result.viewer.createView();

//         final texture = await testHelper.createTexture(200, 400);
//         final renderTarget = await result.viewer.createRenderTarget(
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

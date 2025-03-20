@Timeout(const Duration(seconds: 600))
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart';
import 'package:test/test.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/callbacks.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_camera.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_render_target.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_swapchain.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_texture.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_view.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_viewer_ffi.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("material");

  group("image", () {
    test('create 2D texture & set from decoded image', () async {
      await testHelper.withViewer((viewer) async {
        var imageData = File(
          "${testHelper.testDir}/assets/cube_texture_512x512.png",
        ).readAsBytesSync();
        final image = await viewer.decodeImage(imageData);
        expect(await image.getChannels(), 4);
        expect(await image.getWidth(), 512);
        expect(await image.getHeight(), 512);

        final texture = await viewer.createTexture(
          await image.getWidth(),
          await image.getHeight(),
          textureFormat: TextureFormat.RGBA32F,
        );
        await texture.setLinearImage(
          image,
          PixelDataFormat.RGBA,
          PixelDataType.FLOAT,
        );
        await texture.dispose();
      }, bg: kRed);
    });

    test('create 2D texture and set image from raw buffer', () async {
      await testHelper.withViewer((viewer) async {
        var imageData = File(
          "${testHelper.testDir}/assets/cube_texture_512x512.png",
        ).readAsBytesSync();
        final image = await viewer.decodeImage(imageData);
        expect(await image.getChannels(), 4);
        expect(await image.getWidth(), 512);
        expect(await image.getHeight(), 512);

        final texture = await viewer.createTexture(
          await image.getWidth(),
          await image.getHeight(),
          textureFormat: TextureFormat.RGBA32F,
        );
        var data = await image.getData();

        await texture.setImage(
          0,
          data.buffer.asUint8List(data.offsetInBytes),
          512,
          512,
          4,
          PixelDataFormat.RGBA,
          PixelDataType.FLOAT,
        );
        await texture.dispose();
      }, bg: kRed);
    });

    test('create 3D texture and set image from buffers', () async {
      await testHelper.withViewer((viewer) async {
        final width = 128;
        final height = 128;
        final channels = 4;
        final depth = 5;
        final texture = await viewer.createTexture(
          width,
          height,
          depth: depth,
          textureSamplerType: TextureSamplerType.SAMPLER_3D,
          textureFormat: TextureFormat.RGBA32F,
        );

        for (int i = 0; i < depth; i++) {
          final buffer = Uint8List(width * height * channels * sizeOf<Float>());
          await texture.setImage3D(
            0,
            0,
            0,
            i,
            width,
            height,
            channels,
            1,
            buffer,
            PixelDataFormat.RGBA,
            PixelDataType.FLOAT,
          );
        }
        await texture.dispose();
      }, bg: kRed);
    });

    test('apply 3D texture material ', () async {
      await testHelper.withViewer((viewer) async {
        final material = await viewer.createMaterial(
          File(
            "/Users/nickfisher/Documents/thermion/materials/texture_array.filamat",
          ).readAsBytesSync(),
        );
        final materialInstance = await material.createInstance();
        final sampler = await viewer.createTextureSampler();
        final cube = await viewer.createGeometry(
          GeometryHelper.cube(),
          materialInstances: [materialInstance],
        );

        final width = 1;
        final height = 1;
        final channels = 4;
        final numTextures = 2;
        final texture = await viewer.createTexture(
          width,
          height,
          depth: numTextures,
          textureSamplerType: TextureSamplerType.SAMPLER_3D,
          textureFormat: TextureFormat.RGBA32F,
        );

        for (int i = 0; i < numTextures; i++) {
          var pixelBuffer = Float32List.fromList([
            i == 0 ? 1.0 : 0.0,
            i == 1 ? 1.0 : 0.0,
            0.0,
            1.0,
          ]);
          var byteBuffer = pixelBuffer.buffer.asUint8List(
            pixelBuffer.offsetInBytes,
          );

          await texture.setImage3D(
            0,
            0,
            0,
            i,
            width,
            height,
            channels,
            1,
            byteBuffer,
            PixelDataFormat.RGBA,
            PixelDataType.FLOAT,
          );
        }

        await materialInstance.setParameterTexture(
          "textures",
          texture,
          sampler,
        );
        await materialInstance.setParameterInt("activeTexture", 0);

        await testHelper.capture(viewer, "3d_texture_0");

        await materialInstance.setParameterInt("activeTexture", 1);

        await testHelper.capture(viewer, "3d_texture_1");

        await viewer.destroyAsset(cube);
        await materialInstance.dispose();
        await material.dispose();
        await texture.dispose();
      });
    });
  });

  group("sampler", () {
    test('create sampler', () async {
      await testHelper.withViewer((viewer) async {
        final sampler = viewer.createTextureSampler();
      }, bg: kRed);
    });
  });

  group('projection', () {
    Future withProjectionMaterial(
      ThermionViewer viewer,
      Future Function(
        TextureSampler sampler,
        MaterialInstance mi,
        RenderTarget rt,
        int width,
        int height,
      ) fn,
    ) async {
      // setup render target
      final view = await viewer.getViewAt(0);
      final vp = await view.getViewport();

      final rtTextureHandle = await testHelper.createTexture(512, 512);
      final (viewportWidth, viewportHeight) = (vp.width, vp.height);

      final rt = await viewer.createRenderTarget(
        viewportWidth,
        viewportHeight,
        colorTextureHandle: rtTextureHandle.metalTextureAddress,
      );

      await view.setRenderTarget(rt);

      // setup base material + geometry
      final sampler = await viewer.createTextureSampler();

      var projectionMaterial = await viewer.createMaterial(
        File(
          "/Users/nickfisher/Documents/thermion/materials/capture_uv.filamat",
        ).readAsBytesSync(),
      );
      expect(await projectionMaterial.hasParameter("flipUVs"), true);
      var projectionMaterialInstance =
          await projectionMaterial.createInstance();
      await projectionMaterialInstance.setParameterBool("flipUVs", true);
      final colorTexture = await rt.getColorTexture();
      final depthTexture = await rt.getDepthTexture();
      final w = await depthTexture.getWidth();
      final h = await depthTexture.getHeight();
      final d = await depthTexture.getDepth();

      final depthSampler = await viewer.createTextureSampler(
        compareMode: TextureCompareMode.COMPARE_TO_TEXTURE,
      );
      await projectionMaterialInstance.setParameterTexture(
        "color",
        colorTexture,
        sampler,
      );
      await projectionMaterialInstance.setParameterTexture(
        "depth",
        depthTexture,
        depthSampler,
      );
      await projectionMaterialInstance.setDepthFunc(SamplerCompareFunction.A);

      await fn(
        sampler,
        projectionMaterialInstance,
        rt,
        viewportWidth,
        viewportHeight,
      );

      // cleanup
      await sampler.dispose();
      await projectionMaterialInstance.dispose();
      await projectionMaterial.dispose();
    }

    Future withCube(
      ThermionViewer viewer,
      Future Function(
        ThermionAsset asset,
        MaterialInstance mi,
        Future Function() resetMaterial,
      ) fn,
    ) async {
      // var material = await viewer.createUbershaderMaterialInstance(unlit: true);
      var material = await viewer.createUnlitMaterialInstance();
      final cube = await viewer.createGeometry(
        GeometryHelper.cube(),
        materialInstances: [material],
      );
      var sampler = await viewer.createTextureSampler();
      var inputTextureData = File(
        "${testHelper.testDir}/assets/cube_texture2_512x512.png",
      ).readAsBytesSync();
      var inputImage = await viewer.decodeImage(inputTextureData);
      var inputTexture = await viewer.createTexture(
        await inputImage.getWidth(),
        await inputImage.getHeight(),
        textureFormat: TextureFormat.RGBA32F,
      );
      await inputTexture.setLinearImage(
        inputImage,
        PixelDataFormat.RGBA,
        PixelDataType.FLOAT,
      );
      final resetMaterial = () async {
        await material.setCullingMode(CullingMode.BACK);
        await material.setParameterInt("baseColorIndex", 0);
        await material.setParameterTexture(
          "baseColorMap",
          inputTexture,
          sampler,
        );
        await material.setParameterFloat4(
          "baseColorFactor",
          1.0,
          1.0,
          1.0,
          1.0,
        );
      };
      await resetMaterial();

      await fn(cube, material, resetMaterial);
    }

    test('depth visualization', () async {
      RenderLoop_create();
      final engine = await withPointerCallback<TEngine>(
          (cb) => Engine_createRenderThread(TBackend.BACKEND_METAL.index, nullptr, nullptr, 1, false, cb));

      final gltfResourceLoader = await withPointerCallback<TGltfResourceLoader>(
          (cb) => GltfResourceLoader_createRenderThread(engine, cb));
      final gltfAssetLoader = await withPointerCallback<TGltfAssetLoader>(
          (cb) => GltfAssetLoader_createRenderThread(engine, nullptr, cb));

      final renderer = await withPointerCallback<TRenderer>(
          (cb) => Engine_createRendererRenderThread(engine, cb));
      final swapchain = await withPointerCallback<TSwapChain>((cb) =>
          Engine_createHeadlessSwapChainRenderThread(
              engine,
              500,
              500,
              TSWAP_CHAIN_CONFIG_TRANSPARENT | TSWAP_CHAIN_CONFIG_READABLE,
              cb));
      final camera = await withPointerCallback<TCamera>(
          (cb) => Engine_createCameraRenderThread(engine, cb));

      final offscreenView = await withPointerCallback<TView>(
          (cb) => Engine_createViewRenderThread(engine, cb));
      final view = await withPointerCallback<TView>(
          (cb) => Engine_createViewRenderThread(engine, cb));

      final colorTexture = await withPointerCallback<TTexture>((cb) =>
          Texture_buildRenderThread(
              engine,
              500,
              500,
              1,
              1,
              TTextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT.value |
                  TTextureUsage.TEXTURE_USAGE_SAMPLEABLE.value |
                  TTextureUsage.TEXTURE_USAGE_BLIT_SRC.value,
              0,
              TTextureSamplerType.SAMPLER_2D,
              TTextureFormat.TEXTUREFORMAT_RGBA8,
              cb));

      final depthTexture = await withPointerCallback<TTexture>((cb) =>
          Texture_buildRenderThread(
              engine,
              500,
              500,
              1,
              1,
              TTextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT.value |
                  TTextureUsage.TEXTURE_USAGE_SAMPLEABLE.value,
              0,
              TTextureSamplerType.SAMPLER_2D,
              TTextureFormat.TEXTUREFORMAT_DEPTH32F,
              cb));

      final renderTarget = await withPointerCallback<TRenderTarget>((cb) =>
          RenderTarget_createRenderThread(
              engine, 500, 500, colorTexture, depthTexture, cb));
      View_setRenderTarget(offscreenView, renderTarget);
      final offscreenScene = Engine_createScene(engine);
      final scene = Engine_createScene(engine);

      await withVoidCallback((cb) {
        Renderer_setClearOptionsRenderThread(
            renderer, 1.0, 0.0, 1.0, 1.0, 0, true, true, cb);
      });
      View_setFrustumCullingEnabled(offscreenView, false);
      View_setFrustumCullingEnabled(view, false);
      View_setScene(offscreenView, offscreenScene);
      View_setScene(view, scene);
      View_setCamera(offscreenView, camera);
      View_setCamera(view, camera);
      View_setViewport(offscreenView, 500, 500);
      View_setViewport(view, 500, 500);
      final eye = Struct.create<double3>()
        ..x = 5.0
        ..y = 1.0
        ..z = 5.0;
      Camera_lookAt(
          camera,
          eye,
          Struct.create<double3>()
            ..x = 0.0
            ..y = 0.0
            ..z = 0.0,
          Struct.create<double3>()
            ..x = 0.0
            ..y = 1.0
            ..z = 0.0);
      View_setBloomRenderThread(offscreenView, false, 0.0);

      Camera_setLensProjection(camera, 0.05, 100000, 1.0, kFocalLength);
      View_setPostProcessing(offscreenView, false);
      View_setPostProcessing(view, false);

      final iblData = File("${testHelper.testDir}/assets/default_env_ibl.ktx")
          .readAsBytesSync();
      final ibl = await withPointerCallback<TIndirectLight>((cb) =>
          Engine_buildIndirectLightRenderThread(
              engine, iblData.address, iblData.length, 30000, cb, nullptr));

      Scene_setIndirectLight(offscreenScene, ibl);
      Scene_setIndirectLight(scene, ibl);

      final skyboxData =
          File("${testHelper.testDir}/assets/default_env_skybox.ktx")
              .readAsBytesSync();

      final skybox = await withPointerCallback<TSkybox>((cb) =>
          Engine_buildSkyboxRenderThread(
              engine, skyboxData.address, skyboxData.length, cb, nullptr));

      Scene_setSkybox(offscreenScene, skybox);
      Scene_setSkybox(scene, skybox);

      // final cubeData = GeometryHelper.cube();
      // final cube = await withPointerCallback<TSceneAsset>((cb) =>
      //     SceneAsset_createGeometryRenderThread(
      //         engine,
      //         cubeData.vertices.address,
      //         cubeData.vertices.length,
      //         cubeData.normals.address,
      //         cubeData.normals.length,
      //         cubeData.uvs.address,
      //         cubeData.uvs.length,
      //         cubeData.indices.address,
      //         cubeData.indices.length,
      //         TPrimitiveType.PRIMITIVETYPE_POINTS,
      //         nullptr,
      //         0,
      //         cb));
      // Scene_addEntity(offscreenScene, SceneAsset_getEntity(cube));
      var cube =
          File("${testHelper.testDir}/assets/cube.glb").readAsBytesSync();
      final filamentAsset = await withPointerCallback<TFilamentAsset>((cb) =>
          GltfAssetLoader_loadRenderThread(gltfAssetLoader, 
              cube.address, cube.length, 1, cb));
      var entities = Int32List(FilamentAsset_getEntityCount(filamentAsset));
      FilamentAsset_getEntities(filamentAsset, entities.address);

      final unlitMaData =
          File("/Users/nickfisher/Documents/thermion/materials/unlit.filamat")
              .readAsBytesSync();
      final unlitMa =
          Engine_buildMaterial(engine, unlitMaData.address, unlitMaData.length);
      final unlitMi = await withPointerCallback<TMaterialInstance>(
          (cb) => Material_createInstanceRenderThread(unlitMa, cb));
      MaterialInstance_setParameterFloat2(
          unlitMi, "uvScale".toNativeUtf8().cast<Char>(), 1.0, 1.0);
      MaterialInstance_setParameterFloat4(unlitMi,
          "baseColorFactor".toNativeUtf8().cast<Char>(), 1.0, 1.0, 0.0, 1.0);
      MaterialInstance_setParameterInt(
          unlitMi, "baseColorIndex".toNativeUtf8().cast<Char>(), -1);
      for (int i = 0; i < entities.length; i++) {
        RenderableManager_setMaterialInstanceAt(
            Engine_getRenderableManager(engine), entities[i], 0, unlitMi);
      }

      // final materialInstance = GltfAssetLoader_getMaterialInstance(
      //     Engine_getRenderableManager(engine), filamentAsset);
      // MaterialInstance_setParameterFloat4(materialInstance,
      //     "baseColorFactor".toNativeUtf8().cast<Char>(), 1.0, 0, 0, 1);

      final imageData =
          File("${testHelper.testDir}/assets/cube_texture2_512x512.png")
              .readAsBytesSync();
      final image = await Image_decode(imageData.address, imageData.length,
          "unused".toNativeUtf8().cast<Char>());
      final texture = await withPointerCallback<TTexture>((cb) =>
          Texture_buildRenderThread(
              engine,
              Image_getWidth(image),
              Image_getHeight(image),
              1,
              1,
              TTextureUsage.TEXTURE_USAGE_SAMPLEABLE.index,
              0,
              TTextureSamplerType.SAMPLER_2D,
              TTextureFormat.TEXTUREFORMAT_RGBA32F,
              cb));

      await withBoolCallback((cb) => Texture_loadImageRenderThread(
          engine,
          texture,
          image,
          TPixelDataFormat.PIXELDATAFORMAT_RGBA,
          TPixelDataType.PIXELDATATYPE_FLOAT,
          cb));
      MaterialInstance_setParameterInt(
          unlitMi, "baseColorIndex".toNativeUtf8().cast<Char>(), 0);
      MaterialInstance_setParameterTexture(
          unlitMi,
          "baseColorMap".toNativeUtf8().cast<Char>(),
          RenderTarget_getDepthTexture(renderTarget),
          // texture,
          TextureSampler_create());

      await withVoidCallback((cb) {
        Scene_addFilamentAssetRenderThread(offscreenScene, filamentAsset, cb);
      });

      await withVoidCallback((cb) {
        Scene_addFilamentAssetRenderThread(scene, filamentAsset, cb);
      });

      await withVoidCallback((cb) {
        Engine_flushAndWaitRenderThead(engine, cb);
      });

      await withBoolCallback((cb) {
        Renderer_beginFrameRenderThread(
          renderer,
          swapchain,
          0,
          cb,
        );
      });

      await withVoidCallback((cb) {
        Renderer_renderRenderThread(renderer, offscreenView, cb);
      });

      await withVoidCallback((cb) {
        Renderer_renderRenderThread(renderer, view, cb);
      });

      var offscreenViewOut = Uint8List(500 * 500 * 4);

      await withVoidCallback((cb) {
        Renderer_readPixelsRenderThread(
          renderer,
          offscreenView,
          renderTarget,
          TPixelDataFormat.PIXELDATAFORMAT_RGBA,
          TPixelDataType.PIXELDATATYPE_UBYTE,
          offscreenViewOut.address,
          cb,
        );
      });

      var swapchainOut = Uint8List(500 * 500 * 4);

      await withVoidCallback((cb) {
        Renderer_readPixelsRenderThread(
          renderer,
          view,
          nullptr,
          TPixelDataFormat.PIXELDATAFORMAT_RGBA,
          TPixelDataType.PIXELDATATYPE_UBYTE,
          swapchainOut.address,
          cb,
        );
      });

      await withVoidCallback((cb) {
        Engine_flushAndWaitRenderThead(engine!, cb);
      });

      await savePixelBufferToPng(
        offscreenViewOut,
        500,
        500,
        "/tmp/view1.png",
      );

      await savePixelBufferToPng(
        swapchainOut,
        500,
        500,
        "/tmp/sc1.png",
      );

      await withVoidCallback((cb) => Engine_destroyIndirectLightRenderThread(engine, ibl, cb));
      await withVoidCallback((cb) => Engine_destroySkyboxRenderThread(engine, skybox, cb));
      RenderLoop_destroy();

      //   final mirrorMaterial = await viewer.createMaterial(
      //     File(
      //       "/Users/nickfisher/Documents/thermion/materials/mirror.filamat",
      //     ).readAsBytesSync(),
      //   );
      //   final mirrorMi = await mirrorMaterial.createInstance();
      //   await mirrorMi.setDepthWriteEnabled(false);
      //   final plane = await viewer.createGeometry(GeometryHelper.sphere(),
      //       materialInstances: [mirrorMi]);
      //   await viewer.setTransform(
      //       plane.entity,
      //       Matrix4.compose(
      //           Vector3.zero(),
      //           Quaternion.axisAngle(Vector3(1, 0, 0), pi / 2),
      //           Vector3.all(750)));

      //   final renderer = bindings.renderer;
      //   final _engine = engine;

      //   // final sampler = await viewer.createTextureSampler(
      //   // compareMode: TextureCompareMode.COMPARE_TO_TEXTURE,
      //   // );

      //   // second view
      //   FFIView view2 = await viewer.createView() as FFIView;
      //   var scene2 = Engine_createScene(engine);
      //   Scene_addEntity(scene2, plane.entity);
      //   View_setScene(view2.view, scene2);
      //   await view2.setPostProcessing(false);
      //   await view2.setViewport(vp.width, vp.height);
      //   await view2.setCamera(camera);
      //   await view2.setFrustumCullingEnabled(false);

      //   await mirrorMi.setParameterTexture(
      //       "albedo",
      //       // texture as FFITexture,
      //       (await rt.getDepthTexture())! as FFITexture,
      //       (await viewer.createTextureSampler(
      //               compareMode: TextureCompareMode.COMPARE_TO_TEXTURE,
      //               compareFunc: TextureCompareFunc.LESS_EQUAL)
      //           as FFITextureSampler));

      //   var fence = await withPointerCallback<TFence>((cb) {
      //     Engine_createFenceRenderThread(engine!, cb);
      //   });

      //   var view2Out = Uint8List(vp.width * vp.height * 4);

      //   await withVoidCallback((cb) {
      //     Renderer_renderRenderThread(bindings.renderer, view2.view, cb);
      //   });

      //   await withVoidCallback((cb) {
      //     Renderer_readPixelsRenderThread(
      //       renderer,
      //       view2.view,
      //       nullptr,
      //       TPixelDataFormat.PIXELDATAFORMAT_RGBA.index,
      //       TPixelDataType.PIXELDATATYPE_UBYTE.index,
      //       view2Out.address,
      //       cb,
      //     );
      //   });

      //   await withVoidCallback((cb) {
      //     Renderer_endFrameRenderThread(renderer, cb);
      //   });

      //   await withVoidCallback((cb) {
      //     Engine_flushAndWaitRenderThead(_engine!, cb);
      //   });

      //   await withVoidCallback((cb) {
      //     Engine_destroyFenceRenderThread(_engine, fence, cb);
      //   });

      //   await savePixelBufferToPng(
      //     view2Out,
      //     vp.width,
      //     vp.height,
      //     "/tmp/view2.png",
      //   );
      //   while (true) {
      //     await Future.delayed(Duration(seconds: 1));
      //   }
      //   // await testHelper.capture(viewer, "depth_vis", renderTarget: rt);
      //   // depthTextureHandle.fillColor();
      //   // var data = depthTextureHandle.getTextureBytes()!;
      //   // var pixels = data.bytes.cast<Float>().asTypedList(data.length ~/ 4);
      //   // expect(pixels.where((a) => a != 0).isNotEmpty, true);
      //   // print(pixels);
      // });
    });

    test('project texture & UV unwrap', () async {
      await testHelper.withViewer((viewer) async {
        final camera = await viewer.getMainCamera();
        final depthMaterial = await viewer.createMaterial(
          File(
            "/Users/nickfisher/Documents/thermion/materials/depthVisualizer.filamat",
          ).readAsBytesSync(),
        );
        final depthMaterialInstance = await depthMaterial.createInstance();
        await viewer.setPostProcessing(false);
        await withProjectionMaterial(viewer, (
          sampler,
          projectionMaterialInstance,
          rt,
          width,
          height,
        ) async {
          await withCube(viewer, (cube, ubershader, resetMaterial) async {
            var objects = {"cube": cube};

            await viewer.setPostProcessing(false);

            for (final entry in objects.entries) {
              final object = entry.value;
              final key = entry.key;

              await object.addToScene();

              var divisions = 8;
              for (int i = 0; i < divisions; i++) {
                await camera.lookAt(
                  Vector3(
                    sin(i / divisions * pi) * 3,
                    0,
                    cos(i / divisions * pi) * 3,
                  ),
                );

                await object.setMaterialInstanceAt(depthMaterialInstance);

                // final depthBuffer = await testHelper
                //     .capture(viewer, "depth_${key}_$i", renderTarget: rt);
                // final floatDepthBuffer = Float32List.fromList(
                //     depthBuffer.map((p) => p.toDouble() / 255.0).toList());
                // final depthTexture = await viewer.createTexture(width, height);
                // await depthTexture.setImage(
                //     0,
                //     floatDepthBuffer.buffer
                //         .asUint8List(floatDepthBuffer.offsetInBytes),
                //     width,
                //     height,
                //     4,
                //     PixelDataFormat.RGBA,
                //     PixelDataType.FLOAT);
                // var depthSampler = await viewer.createTextureSampler(
                //     minFilter: TextureMinFilter.NEAREST,
                //     magFilter: TextureMagFilter.NEAREST);
                // await projectionMaterialInstance.setParameterTexture(
                //     "depth", depthTexture, depthSampler);

                await object.setMaterialInstanceAt(ubershader);
                await testHelper.capture(
                  viewer,
                  "color_${key}_$i",
                  renderTarget: rt,
                );

                // final view = await viewer.getViewAt(0);
                // final vp = await view.getViewport();
                // final swapchain =
                //     await viewer.createHeadlessSwapChain(512, 512);

                // final rtTextureHandle2 =
                //     await testHelper.createTexture(512, 512);
                // final (viewportWidth, viewportHeight) = (vp.width, vp.height);

                // final rt2 = await viewer.createRenderTarget(viewportWidth,
                //     viewportHeight, rtTextureHandle2.metalTextureAddress);

                // await view.setRenderTarget(rt2);

                await object.setMaterialInstanceAt(projectionMaterialInstance);

                var projectionOutput = await testHelper.capture(
                  viewer,
                  "uv_capture_${key}_$i",
                  renderTarget: rt,
                  // renderTarget: rt2,
                  // swapChain: swapchain
                );

                // await view.setRenderTarget(rt);

                var floatPixelBuffer = Float32List.fromList(
                  projectionOutput.first
                      .map((p) => p.toDouble() / 255.0)
                      .toList(),
                );

                final projectedImage = await viewer.createImage(512, 512, 4);
                final data = await projectedImage.getData();
                data.setRange(0, data.length, floatPixelBuffer);
                final projectedTexture = await viewer.createTexture(
                  512,
                  512,
                  textureFormat: TextureFormat.RGBA32F,
                );
                await projectedTexture.setLinearImage(
                  projectedImage,
                  PixelDataFormat.RGBA,
                  PixelDataType.FLOAT,
                );

                await ubershader.setParameterTexture(
                  "baseColorMap",
                  projectedTexture,
                  sampler,
                );
                await object.setMaterialInstanceAt(ubershader);
                await testHelper.capture(
                  viewer,
                  "retextured_${key}_$i",
                  renderTarget: rt,
                );
                await resetMaterial();
              }
              await viewer.destroyAsset(object);
            }
          });
        });
      }, viewportDimensions: (width: 512, height: 512));
    });

    Future usingVDTM(
      ThermionViewer viewer,
      List<Vector3> cameraPositions,
      int width,
      int height,
      int channels,
      Future Function(Texture texture, MaterialInstance mi) fn,
    ) async {
      final sampler = await viewer.createTextureSampler();

      var texture = await viewer.createTexture(
        width,
        height,
        textureSamplerType: TextureSamplerType.SAMPLER_3D,
        depth: cameraPositions.length,
        textureFormat: TextureFormat.RGBA32F,
      );

      final vdtm = await viewer.createMaterial(
        File(
          "/Users/nickfisher/Documents/thermion/materials/vdtm.filamat",
        ).readAsBytesSync(),
      );

      final materialInstance = await vdtm.createInstance();

      await materialInstance.setParameterFloat3Array(
        "cameraPositions",
        cameraPositions,
      );
      await materialInstance.setParameterTexture(
        "perspectives",
        texture,
        sampler,
      );
      await fn(texture, materialInstance);

      await materialInstance.dispose();
      await vdtm.dispose();
      await texture.dispose();
      await sampler.dispose();
    }

    test('view dependent texture mapping (interpolated colors)', () async {
      await testHelper.withViewer((viewer) async {
        final cameraPositions = [
          Vector3(0, 0, 5),
          Vector3(5, 0, 0),
          Vector3(0, 0, -5),
        ];
        final camera = await viewer.getMainCamera();

        final (numCameraPositions, width, height, channels) = (
          cameraPositions.length,
          1,
          1,
          4,
        );

        await usingVDTM(viewer, cameraPositions, width, height, channels, (
          texture,
          materialInstance,
        ) async {
          for (int i = 0; i < numCameraPositions; i++) {
            final pixelBuffer = Float32List.fromList([
              1 - (i / numCameraPositions),
              i / numCameraPositions,
              0.0,
              1.0,
            ]);
            var byteBuffer = pixelBuffer.buffer.asUint8List(
              pixelBuffer.offsetInBytes,
            );
            await texture.setImage3D(
              0,
              0,
              0,
              i,
              width,
              height,
              channels,
              1,
              byteBuffer,
              PixelDataFormat.RGBA,
              PixelDataType.FLOAT,
            );
          }

          final cube = await viewer.createGeometry(
            GeometryHelper.cube(),
            materialInstances: [materialInstance],
          );

          for (int i = 0; i < 8; i++) {
            final cameraPosition = Vector3(
              sin(pi * (i / 7)) * 5,
              0,
              cos(pi * (i / 7)) * 5,
            );
            await camera.lookAt(cameraPosition);
            await testHelper.capture(
              viewer,
              "view_dependent_texture_mapping_$i",
            );
          }
        });
      }, viewportDimensions: (width: 512, height: 512));
    });

    test('VDTM + Texture Projection', () async {
      await testHelper.withViewer((viewer) async {
        final cameraPositions = [
          Vector3(0, 0, 5),
          Vector3(5, 0, 0),
          Vector3(0, 0, -5),
        ];

        final camera = await viewer.getMainCamera();

        await withProjectionMaterial(viewer, (
          TextureSampler projectionSampler,
          MaterialInstance projectionMaterialInstance,
          RenderTarget rt,
          int width,
          int height,
        ) async {
          await withCube(viewer, (cube, ubershader, resetMaterial) async {
            var pixelBuffers = <Float32List>[];
            for (int i = 0; i < cameraPositions.length; i++) {
              await camera.lookAt(cameraPositions[i]);

              await testHelper.capture(viewer, "vdtm_$i", renderTarget: rt);

              await cube.setMaterialInstanceAt(projectionMaterialInstance);

              var projectionOutput = await testHelper.capture(
                viewer,
                "vdtm_unwrapped_$i",
                renderTarget: rt,
              );

              var floatPixelBuffer = Float32List.fromList(
                projectionOutput.first
                    .map((p) => p.toDouble() / 255.0)
                    .toList(),
              );
              pixelBuffers.add(floatPixelBuffer);
              final projectedImage = await viewer.createImage(width, height, 4);
              final data = await projectedImage.getData();
              data.setRange(0, data.length, floatPixelBuffer);
              final projectedTexture = await viewer.createTexture(
                width,
                height,
                textureFormat: TextureFormat.RGBA32F,
              );
              await projectedTexture.setLinearImage(
                projectedImage,
                PixelDataFormat.RGBA,
                PixelDataType.FLOAT,
              );

              await ubershader.setParameterTexture(
                "baseColorMap",
                projectedTexture,
                projectionSampler,
              );
              await cube.setMaterialInstanceAt(ubershader);

              await testHelper.capture(
                viewer,
                "vdtm_projected_$i",
                renderTarget: rt,
              );

              await resetMaterial();
            }

            await usingVDTM(viewer, cameraPositions, width, height, 4, (
              vdtmTexture,
              vdtmMaterial,
            ) async {
              await cube.setMaterialInstanceAt(vdtmMaterial);
              for (int i = 0; i < cameraPositions.length; i++) {
                await vdtmTexture.setImage3D(
                  0,
                  0,
                  0,
                  i,
                  width,
                  height,
                  4,
                  1,
                  pixelBuffers[i].buffer.asUint8List(
                        pixelBuffers[i].offsetInBytes,
                      ),
                  PixelDataFormat.RGBA,
                  PixelDataType.FLOAT,
                );
              }

              for (int i = 0; i < 8; i++) {
                await camera.lookAt(
                  Vector3(sin(pi * (i / 7)) * 5, 0, cos(pi * (i / 7)) * 5),
                );
                await testHelper.capture(
                  viewer,
                  "vdtm_reprojected_$i",
                  renderTarget: rt,
                );
              }
            });
          });
        });
      }, viewportDimensions: (width: 512, height: 512));
    });
  });
}

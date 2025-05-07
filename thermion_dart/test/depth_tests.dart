@Timeout(const Duration(seconds: 600))
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/bindings.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_camera.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_swapchain.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void checkMinMaxPixelValues(Float32List pixelBuffer, int width, int height) {
  var minVal = 99999.0;
  var maxVal = 0.0;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      for (int i = 0; i < 3; i++) {
        final srcIndex = (y * width * 4) + (x * 4) + i;
        if (pixelBuffer[srcIndex] == 0) {
          continue;
        }
        minVal = min(minVal, pixelBuffer[srcIndex]);
        maxVal = max(maxVal, pixelBuffer[srcIndex]);
      }
    }
  }
  print("minVal $minVal maxVal $maxVal");
}

void main() async {
  final testHelper = TestHelper("depth");
  await testHelper.setup();

  test('write depth value to R32F texture', () async {
    final viewportDimensions = (width: 512, height: 512);
    var swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
        viewportDimensions.width, viewportDimensions.height) as FFISwapChain;

    var color = await FilamentApp.instance!
        .createTexture(viewportDimensions.width, viewportDimensions.height,
            flags: {
              TextureUsage.TEXTURE_USAGE_BLIT_SRC,
              TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
              TextureUsage.TEXTURE_USAGE_SAMPLEABLE
            },
            textureFormat: TextureFormat.R32F);

    var renderTarget = await FilamentApp.instance!.createRenderTarget(
            viewportDimensions.width, viewportDimensions.height, color: color)
        as FFIRenderTarget;

    var view = await FilamentApp.instance!.createView() as FFIView;
    await view.setPostProcessing(false);
    await view.setRenderTarget(renderTarget);

    await FilamentApp.instance!.setClearOptions(0.0, 1.0, 0.0, 1.0);
    var scene = await FilamentApp.instance!.createScene() as FFIScene;

    await view.setScene(scene);
    await view.setViewport(viewportDimensions.width, viewportDimensions.height);
    final camera = FFICamera(
        await withPointerCallback<TCamera>((cb) =>
            Engine_createCameraRenderThread(FilamentApp.instance!.engine, cb)),
        FilamentApp.instance! as FFIFilamentApp);

    await camera.setLensProjection();

    await view.setCamera(camera);

    await view.setFrustumCullingEnabled(false);
    await camera.setLensProjection(near: 0.5, far: 10);
    final dist = 2.0;
    await camera.lookAt(
      Vector3(
        -0.5,
        dist,
        dist,
      ),
    );

    var mat = await FilamentApp.instance!.createMaterial(
      File(
        "/Users/nickfisher/Documents/thermion/materials/linear_depth.filamat",
      ).readAsBytesSync(),
    );
    var mi = await mat.createInstance();
    await mi.setDepthCullingEnabled(true);
    await mi.setDepthWriteEnabled(true);
    await mi.setCullingMode(CullingMode.BACK);

    var umi = await FilamentApp.instance!
        .createUbershaderMaterialInstance(unlit: true);
    var cube = await FilamentApp.instance!
        .createGeometry(GeometryHelper.cube(), nullptr);
    await scene.add(cube as FFIAsset);
    await umi.setParameterFloat4("baseColorFactor", 1, 1, 1, 0);

    await cube.setTransform(
        Matrix4.compose(Vector3.zero(), Quaternion.identity(), Vector3.all(1)));
    await cube.setMaterialInstanceAt(mi as FFIMaterialInstance);
    await FilamentApp.instance!.register(swapChain, view);
    var pixelBuffers = await testHelper.capture(null, "linear_depth",
        swapChain: swapChain, pixelDataFormat: PixelDataFormat.R);
    checkMinMaxPixelValues(pixelBuffers[view]!.buffer.asFloat32List(),
        viewportDimensions.width, viewportDimensions.height);
  });

  test('check NDC depth value', () async {
    final viewportDimensions = (width: 512, height: 512);
    var swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
        viewportDimensions.width, viewportDimensions.height) as FFISwapChain;

    var color = await FilamentApp.instance!
        .createTexture(viewportDimensions.width, viewportDimensions.height,
            flags: {
              TextureUsage.TEXTURE_USAGE_BLIT_SRC,
              TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
              TextureUsage.TEXTURE_USAGE_SAMPLEABLE
            },
            textureFormat: TextureFormat.R32F);

    var renderTarget = await FilamentApp.instance!.createRenderTarget(
            viewportDimensions.width, viewportDimensions.height, color: color)
        as FFIRenderTarget;

    var view = await FilamentApp.instance!.createView() as FFIView;
    await view.setPostProcessing(false);
    await view.setRenderTarget(renderTarget);

    await FilamentApp.instance!.setClearOptions(0.0, 1.0, 0.0, 1.0);
    var scene = await FilamentApp.instance!.createScene() as FFIScene;

    await view.setScene(scene);
    await view.setViewport(viewportDimensions.width, viewportDimensions.height);
    final camera = FFICamera(
        await withPointerCallback<TCamera>((cb) =>
            Engine_createCameraRenderThread(FilamentApp.instance!.engine, cb)),
        FilamentApp.instance! as FFIFilamentApp);

    await camera.setLensProjection();

    await view.setCamera(camera);

    await view.setFrustumCullingEnabled(false);
    await camera.setLensProjection(near: 0.5, far: 10);
    final dist = 3.0;
    await camera.lookAt(
      Vector3(
        -0.5,
        dist,
        dist,
      ),
    );

    var mat = await FilamentApp.instance!.createMaterial(
      File(
        "/Users/nickfisher/Documents/thermion/materials/ndc_depth.filamat",
      ).readAsBytesSync(),
    );
    var mi = await mat.createInstance();
    await mi.setDepthCullingEnabled(true);
    await mi.setDepthWriteEnabled(true);
    await mi.setCullingMode(CullingMode.BACK);

    var umi = await FilamentApp.instance!
        .createUbershaderMaterialInstance(unlit: true);
    var cube = await FilamentApp.instance!
        .createGeometry(GeometryHelper.cube(), nullptr);
    await scene.add(cube as FFIAsset);
    await umi.setParameterFloat4("baseColorFactor", 1, 1, 1, 0);

    await cube.setTransform(
        Matrix4.compose(Vector3.zero(), Quaternion.identity(), Vector3.all(1)));
    await cube.setMaterialInstanceAt(mi as FFIMaterialInstance);
    await FilamentApp.instance!.register(swapChain, view);
    var pixelBuffers = await testHelper.capture(null, "ndc_depth",
        swapChain: swapChain, pixelDataFormat: PixelDataFormat.R);
    checkMinMaxPixelValues(pixelBuffers[view]!.buffer.asFloat32List(),
        viewportDimensions.width, viewportDimensions.height);
  });

  group('depth sampling', () {
    test("depth sampling", () async {
      await testHelper.withViewer((viewer) async {
        await FilamentApp.instance!.setClearOptions(0, 0, 0, 1,
            clearStencil: 0, discard: false, clear: true);
        final camera = await viewer.getActiveCamera();
        await camera.lookAt(Vector3(3, 3, 6));

        final view = await testHelper.createView(testHelper.swapChain);
        await testHelper.withCube(
          viewer,
          (cube) async {
            var mat = await FilamentApp.instance!.createMaterial(
              File(
                "/Users/nickfisher/Documents/thermion/materials/depth_sampler.filamat",
              ).readAsBytesSync(),
            );
            final mi = await mat.createInstance();

            await viewer.addToScene(cube);
            final secondScene = await view.getScene();
            await secondScene.add(cube);

            final sampler = await FilamentApp.instance!.createTextureSampler();
            final rt = await view.getRenderTarget();
            final color = await rt!.getColorTexture();
            final depth = await rt!.getDepthTexture();
            await mi.setParameterTexture(
              "depth",
              depth,
              await FilamentApp.instance!.createTextureSampler(
                compareMode: TextureCompareMode.COMPARE_TO_TEXTURE,
              ),
            );
            await cube.setMaterialInstanceAt(mi);

            await testHelper.capture(null, "depth_sampling1");
          },
        );
      }, createRenderTarget: true);
    });
  });
}
  

  // group('projection', () {
  //   test('project texture & UV unwrap', () async {
  //     await testHelper.withViewer((viewer) async {
  //       final camera = await viewer.getActiveCamera();
  //       await viewer.view.setFrustumCullingEnabled(false);
  //       await camera.setLensProjection(near: 0.01, far: 100);
  //       final dist = 26.0;
  //       await camera.lookAt(
  //         Vector3(
  //           -0.5,
  //           dist,
  //           dist,
  //         ),
  //       );
  //       await FilamentApp.instance!
  //           .unregister(testHelper.swapChain, viewer.view);

  //       await withView(testHelper.swapChain, viewer, (linearDepthView) async {
  //         await withView(testHelper.swapChain, viewer, (manualDepthView) async {
  //           await manualDepthView.setRenderOrder(1);
  //           await linearDepthView.setRenderOrder(0);

  //           await viewer.view.setRenderOrder(2);
  //           await withManualDepthMaterial(testHelper, viewer, (
  //             manualDepthMi,
  //           ) async {
  //             await withSampledDepthMaterial(testHelper, viewer, (
  //               sampledDepthMi,
  //             ) async {
  //               await sampledDepthMi.setParameterTexture(
  //                   "depth",
  //                   await (await manualDepthView.getRenderTarget())!
  //                       .getColorTexture(),
  //                   await FilamentApp.instance!.createTextureSampler());

  //               await withLinearDepthMaterial(testHelper, viewer, (
  //                 linearDepthMi,
  //               ) async {
  //                 await withProjectionMaterial(testHelper, viewer, (
  //                   projectMi,
  //                 ) async {
  //                   await FilamentApp.instance!.setClearOptions(0, 0, 0, 1,
  //                       clearStencil: 0, discard: false, clear: true);
  //                   await testHelper.withCube(viewer, (cube2) async {
  //                     var ubershader = await cube2.getMaterialInstanceAt();
  //                     (await manualDepthView.getScene()).remove(cube2);
  //                     await ubershader.setParameterFloat4(
  //                         "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
  //                     await cube2.setTransform(Matrix4.compose(
  //                         Vector3(-0.5, 0, -0.5),
  //                         Quaternion.identity(),
  //                         Vector3.all(1)));
  //                     await testHelper.withCube(viewer, (cube) async {
  //                       await cube.setTransform(Matrix4.compose(Vector3.zero(),
  //                           Quaternion.identity(), Vector3.all(1)));
  //                       var divisions = 1;
  //                       var ubershader = await cube.getMaterialInstanceAt();
  //                       await ubershader.setDepthCullingEnabled(true);
  //                       await ubershader.setDepthWriteEnabled(true);
  //                       await ubershader.setCullingMode(CullingMode.BACK);
  //                       await ubershader.setParameterInt("baseColorIndex", 0);

  //                       await ubershader.setParameterTexture(
  //                           "baseColorMap",
  //                           await createTextureFromImage(testHelper),
  //                           await FilamentApp.instance!.createTextureSampler());

  //                       // final color = await (await linearDepthView.getRenderTarget())!
  //                       //     .getColorTexture();
  //                       // final depth = await (await manualDepthView.getRenderTarget())!
  //                       //     .getColorTexture();

  //                       // await projectMi.setParameterTexture("color", color,
  //                       //     await FilamentApp.instance!.createTextureSampler());
  //                       // await projectMi.setParameterTexture("depth", depth,
  //                       //     await FilamentApp.instance!.createTextureSampler());
  //                       // await projectMi.setDepthCullingEnabled(true);
  //                       // await projectMi.setParameterBool("useDepth", true);

  //                       // for (int i = 0; i < divisions; i++) {
  //                       //   await camera.lookAt(
  //                       //     Vector3(
  //                       //       sin(i / divisions * pi) * dist,
  //                       //       dist,
  //                       //       cos(i / divisions * pi) * dist,
  //                       //     ),
  //                       //   );
  //                       //   await cube.setMaterialInstanceAt(manualDepthMi);

  //                       var pixelBuffers = await testHelper
  //                           .capture(null, "project_texture_color",
  //                               beforeRender: (view) async {
  //                         if (view == linearDepthView) {
  //                           await cube.setMaterialInstanceAt(linearDepthMi);
  //                         } else if (view == manualDepthView) {
  //                           await cube.setMaterialInstanceAt(manualDepthMi);
  //                         } else {
  //                           throw Exception();
  //                         }
  //                       });
  //                       // var comparison = comparePixelBuffers(
  //                       //     pixelBuffers[1], pixelBuffers[2], 512, 512);
  //                       // savePixelBufferToBmp(comparison, 512, 512, "cmparison");
  //                       // await cube.setMaterialInstanceAt(ubershader);
  //                       checkRedFromRGBAPixelBuffer(
  //                           pixelBuffers[manualDepthView]!
  //                               .buffer
  //                               .asFloat32List(),
  //                           512,
  //                           512);
  //                       // }
  //                     });
  //                   });
  //                 });
  //               });
  //             });
  //           });
  //         });
  //       });
  //     }, createRenderTarget: true);
  //   });
  // });
// }

//                   final projectedImage = await viewer.createImage(512, 512, 4);
//                   final data = await projectedImage.getData();
//                   data.setRange(0, data.length, floatPixelBuffer);
//                   final projectedTexture = await FilamentApp.instance!.createTexture(
//                     512,
//                     512,
//                     textureFormat: TextureFormat.RGBA32F,
//                   );
//                   await projectedTexture.setLinearImage(
//                     projectedImage,
//                     PixelDataFormat.RGBA,
//                     PixelDataType.FLOAT,
//                   );

//                   await ubershader.setParameterTexture(
//                     "baseColorMap",
//                     projectedTexture,
//                     sampler,
//                   );
//                   await object.setMaterialInstanceAt(ubershader);
//                   await testHelper.capture(
//                     viewer,
//                     "retextured_${key}_$i",
//                     renderTarget: rt,
//                   );
//                   await resetMaterial();
//                 }
//                 await viewer.destroyAsset(object);
//               }
//             });
//           });
//         });
//       });
//   });
// }

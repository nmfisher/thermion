@Timeout(const Duration(seconds: 600))
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:test/test.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/callbacks.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_asset.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_camera.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_filament_app.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_material.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_render_target.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_scene.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_swapchain.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_view.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

Future<Texture> createTextureFromImage(TestHelper testHelper) async {
  final image = await FilamentApp.instance!.decodeImage(
      File("${testHelper.testDir}/assets/cube_texture2_512x512.png")
          .readAsBytesSync());
  final texture = await FilamentApp.instance!
      .createTexture(await image.getWidth(), await image.getHeight());
  await texture.setLinearImage(
      image, PixelDataFormat.RGBA, PixelDataType.FLOAT);
  return texture;
}

Future<ThermionAsset> _makeCube(
    TestHelper testHelper, ThermionViewer viewer) async {
  final cube = await testHelper.createCube(viewer);
  var ubershader = await cube.getMaterialInstanceAt();
  await ubershader.setDepthCullingEnabled(true);
  await ubershader.setDepthWriteEnabled(true);
  await ubershader.setCullingMode(CullingMode.BACK);
  await ubershader.setParameterInt("baseColorIndex", 0);

  return cube;
}

void main() async {
  final testHelper = TestHelper("projection");
  await testHelper.setup();

  group('projection', () {
    test('project texture & UV unwrap', () async {
      await testHelper.withViewer((viewer) async {
        final camera = await viewer.getActiveCamera();
        await viewer.view.setFrustumCullingEnabled(false);
        await camera.setLensProjection(near: 0.75, far: 100);
        final dist = 5.0;
        await camera.lookAt(
          Vector3(
            -0.5,
            dist,
            dist,
          ),
        );

        final cube = await _makeCube(testHelper, viewer);
        final ubershader = await cube.getMaterialInstanceAt();
        final originalTexture = await createTextureFromImage(testHelper);
        final sampler =
            await FilamentApp.instance!.createTextureSampler();

        await ubershader.setParameterTexture("baseColorMap", originalTexture,
            sampler);

        final depthWriteView = await testHelper.createView(testHelper.swapChain,
            textureFormat: TextureFormat.R32F);
        final captureView = await testHelper.createView(testHelper.swapChain);
        await viewer.view.setRenderOrder(0);
        await depthWriteView.setRenderOrder(1);
        await captureView.setRenderOrder(2);

        for (var view in [captureView, depthWriteView]) {
          await view.setCamera(camera);
          await (view as FFIView)
              .setScene(await viewer.view.getScene() as FFIScene);
        }

        var depthWriteMat = await FilamentApp.instance!.createMaterial(
          File(
            "/Users/nickfisher/Documents/thermion/materials/linear_depth.filamat",
          ).readAsBytesSync(),
        );
        var depthWriteMi = await depthWriteMat.createInstance();

        var captureMat = await FilamentApp.instance!.createMaterial(
          File(
            "/Users/nickfisher/Documents/thermion/materials/capture_uv.filamat",
          ).readAsBytesSync(),
        );
        var captureMi = await captureMat.createInstance();

        final color =
            await (await viewer.view.getRenderTarget())!.getColorTexture();
        final depth =
            await (await depthWriteView.getRenderTarget())!.getColorTexture();
        await captureMi.setParameterBool("flipUVs", true);
        await captureMi.setParameterTexture(
            "color", color, await FilamentApp.instance!.createTextureSampler());
        await captureMi.setParameterTexture(
            "depth", depth, await FilamentApp.instance!.createTextureSampler());
        await captureMi.setParameterBool("useDepth", true);

        await FilamentApp.instance!.setClearOptions(0, 0, 0, 1,
            clearStencil: 0, discard: false, clear: true);

        final divisions = 8;
        final projectedImage =
            await FilamentApp.instance!.createImage(512, 512, 4);
        final projectedTexture = await FilamentApp.instance!.createTexture(
          512,
          512,
          textureFormat: TextureFormat.RGBA32F,
        );
        
        for (int i = 0; i < divisions; i++) {
          await camera.lookAt(
            Vector3(
              sin(i / divisions * pi) * dist,
              dist,
              cos(i / divisions * pi) * dist,
            ),
          );

          var pixelBuffers = await testHelper.capture(null, "capture_uv_$i",
              beforeRender: (view) async {
            if (view == viewer.view) {
                        await ubershader.setParameterTexture("baseColorMap", originalTexture,
            sampler);
              await cube.setMaterialInstanceAt(ubershader);
            } else if (view == depthWriteView) {
              await cube.setMaterialInstanceAt(depthWriteMi);
            } else if (view == captureView) {
              await cube.setMaterialInstanceAt(captureMi);
            }
          });
          await cube.setMaterialInstanceAt(ubershader);

          final data = await projectedImage.getData();
          data.setRange(0, data.length,
              pixelBuffers[captureView]!.buffer.asFloat32List());

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

          await testHelper.capture(viewer.view, "capture_uv_retextured_$i");

                                await ubershader.setParameterTexture("baseColorMap", originalTexture,
            sampler);
        }
      }, createRenderTarget: true);
    });
  });
}

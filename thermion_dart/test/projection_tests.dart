@Timeout(const Duration(seconds: 600))
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:test/test.dart';
import 'package:thermion_dart/src/utils/src/texture_projection.dart';
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
        final sampler = await FilamentApp.instance!.createTextureSampler();

        await ubershader.setParameterTexture(
            "baseColorMap", originalTexture, sampler);

        var textureProjection =
            await TextureProjection.create(viewer.view, testHelper.swapChain);

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

          await textureProjection.project(cube);
          final depth = textureProjection.getDepthWritePixelBuffer();
          await savePixelBufferToBmp(
              depth, 512, 512, "${testHelper.outDir.path}/depth_$i.bmp");
          final projected = textureProjection.getProjectedPixelBuffer();
          await savePixelBufferToBmp(
              depth, 512, 512, "${testHelper.outDir.path}/projected_$i.bmp");
          await cube.setMaterialInstanceAt(ubershader);

          final data = await projectedImage.getData();
          data.setRange(0, data.length, projected.buffer.asFloat32List());

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

          await ubershader.setParameterTexture(
              "baseColorMap", originalTexture, sampler);
        }
      }, createRenderTarget: true);
    });
  });
}

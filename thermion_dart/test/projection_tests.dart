@Timeout(const Duration(seconds: 600))
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:test/test.dart';
import 'package:thermion_dart/src/utils/src/texture_projection.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

Future<Texture> createTextureFromImage(TestHelper testHelper) async {
  final image = await FilamentApp.instance!.decodeImage(
      File("${testHelper.testDir}/assets/cube_texture_512x512.png")
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
        final vp = await viewer.view.getViewport();
        await camera.setLensProjection(
            near: 0.75, far: 100, aspect: vp.width / vp.height);

        final (width, height) = (vp.width, vp.height);
        final dist = 2.5;
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

        var textureProjection = await TextureProjection.create(viewer.view);

        await FilamentApp.instance!.setClearOptions(0, 0, 0, 1,
            clearStencil: 0, discard: false, clear: true);

        final divisions = 8;
        final projectedImage =
            await FilamentApp.instance!.createImage(width, height, 4);
        final projectedTexture = await FilamentApp.instance!.createTexture(
          width,
          height,
          textureFormat: TextureFormat.RGBA32F,
        );

        var images = <Float32List>[];

        for (int i = 0; i < divisions; i++) {
          await camera.lookAt(
            Vector3(
              sin(i / divisions * pi) * dist,
              dist,
              cos(i / divisions * pi) * dist,
            ),
          );

          final result = await textureProjection.project(
              await (await viewer.view.getRenderTarget())!.getColorTexture(),
              cube);
          final color = result.sourceView!;
          await savePixelBufferToBmp(
              color, width, height, "${testHelper.outDir.path}/color_$i.bmp");
          final depth = result.depth;
          await savePixelBufferToBmp(
              depth, width, height, "${testHelper.outDir.path}/depth_$i.bmp");
          final projected = result.projected;
          await savePixelBufferToBmp(projected, width, height,
              "${testHelper.outDir.path}/projected_$i.bmp");
          await cube.setMaterialInstanceAt(ubershader);

          final data = await projectedImage.getData();
          data.setRange(0, data.length, projected.buffer.asFloat32List());

          images.add(projected.buffer.asFloat32List());

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

        // Improved blending - treating black pixels as transparent
        final blendedImage = Float32List(width * height * 4);
        final weightSums = List<double>.filled(width * height, 0.0);

        // For each image
        for (final image in images) {
          // For each pixel in the image
          for (int p = 0; p < width * height; p++) {
            final baseIdx = p * 4;
            final r = image[baseIdx];
            final g = image[baseIdx + 1];
            final b = image[baseIdx + 2];
            final alpha = image[baseIdx + 3];

            // Check if pixel is black (all color channels near zero)
            final isBlack = (r < 0.01 && g < 0.01 && b < 0.01);

            // Only include pixels that are non-black AND have non-zero alpha
            if (!isBlack && alpha > 0) {
              // Weight contribution by alpha value
              final weight = alpha;
              blendedImage[baseIdx] += r * weight;
              blendedImage[baseIdx + 1] += g * weight;
              blendedImage[baseIdx + 2] += b * weight;
              blendedImage[baseIdx + 3] += weight;

              // Track total weights for normalization
              weightSums[p] += weight;
            }
          }
        }

        // Normalize by the accumulated weights
        for (int p = 0; p < width * height; p++) {
          final baseIdx = p * 4;
          final weightSum = weightSums[p];

          if (weightSum > 0) {
            blendedImage[baseIdx] /= weightSum;
            blendedImage[baseIdx + 1] /= weightSum;
            blendedImage[baseIdx + 2] /= weightSum;
            // Set alpha to full for pixels that had contributions
            blendedImage[baseIdx + 3] = 1.0;
          } else {
            // For pixels with no contributions, ensure they're fully transparent
            blendedImage[baseIdx] = 0;
            blendedImage[baseIdx + 1] = 0;
            blendedImage[baseIdx + 2] = 0;
            blendedImage[baseIdx + 3] = 0;
          }
        }
        // Set the blended data to the projectedImage
        final data = await projectedImage.getData();
        data.setRange(0, data.length, blendedImage);

        await savePixelBufferToBmp(blendedImage.buffer.asUint8List(), width,
            height, "${testHelper.outDir.path}/blended.bmp",
            hasAlpha: true, isFloat: true);

        // Update the texture with the blended image
        await projectedTexture.setLinearImage(
          projectedImage,
          PixelDataFormat.RGBA,
          PixelDataType.FLOAT,
        );

        // Set the blended texture as the material parameter
        await ubershader.setParameterTexture(
          "baseColorMap",
          projectedTexture,
          sampler,
        );

        // Capture 120 frames orbiting around the cube
        final orbitFrames = 120;
        for (int frame = 0; frame < orbitFrames; frame++) {
          // Calculate camera position based on frame
          final angle = frame / orbitFrames * 2 * pi;
          await camera.lookAt(
            Vector3(
              sin(angle) * dist,
              dist * 0.8, // Slightly lower height
              cos(angle) * dist,
            ),
          );

          // Capture each frame with a sequential number
          await testHelper.capture(viewer.view,
              "capture_uv_blended_orbit_${frame.toString().padLeft(3, '0')}");
        }
      },
          createRenderTarget: true,
          viewportDimensions: (height: 512, width: 1024));
    });
  });
}

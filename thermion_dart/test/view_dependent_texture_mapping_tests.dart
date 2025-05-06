@Timeout(const Duration(seconds: 600))
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:thermion_dart/src/utils/src/texture_projection.dart';
import 'package:thermion_dart/src/bindings/bindings.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

Future<(LinearImage, Texture, TextureSampler)> createTextureFromImage(
    TestHelper testHelper) async {
  final image = await FilamentApp.instance!.decodeImage(
      File("${testHelper.testDir}/assets/cube_texture2_512x512.png")
          .readAsBytesSync());
  final texture = await FilamentApp.instance!
      .createTexture(await image.getWidth(), await image.getHeight());
  await texture.setLinearImage(
      image, PixelDataFormat.RGBA, PixelDataType.FLOAT);

  return (image, texture, await FilamentApp.instance!.createTextureSampler());
}

Future<(MaterialInstance, Texture)> _makeVDTMMaterial(
  ThermionViewer viewer,
  List<Vector3> cameraForwardVectors,
  int width,
  int height,
  int channels,
) async {
  final sampler = await FilamentApp.instance!.createTextureSampler(
      compareMode: TextureCompareMode.COMPARE_TO_TEXTURE,
      compareFunc: TextureCompareFunc.GREATER);

  var texture = await FilamentApp.instance!.createTexture(
    width,
    height,
    textureSamplerType: TextureSamplerType.SAMPLER_3D,
    depth: cameraForwardVectors.length,
    textureFormat: TextureFormat.RGBA32F,
  );

  final vdtm = await FilamentApp.instance!.createMaterial(
    File(
      "/Users/nickfisher/Documents/thermion/materials/vdtm.filamat",
    ).readAsBytesSync(),
  );

  final materialInstance = await vdtm.createInstance();
  await materialInstance.setParameterBool("flipUVs", true);
  await materialInstance.setParameterFloat3Array(
    "cameraForwardVectors",
    cameraForwardVectors,
  );
  await materialInstance.setParameterTexture(
    "perspectives",
    texture,
    sampler,
  );
  return (materialInstance, texture);
}

Future<ThermionAsset> _makeCube(
    TestHelper testHelper, ThermionViewer viewer) async {
  final cube = await testHelper.createCube(viewer);
  var ubershader = await cube.getMaterialInstanceAt();
  await ubershader.setDepthCullingEnabled(true);
  await ubershader.setDepthWriteEnabled(true);
  await ubershader.setCullingMode(CullingMode.BACK);
  await ubershader.setParameterInt("baseColorIndex", 0);
  await ubershader.setParameterFloat4("baseColorFactor", 1.0, 1.0, 1.0, 0.0);

  return cube;
}

void main() async {
  final testHelper = TestHelper("vdtm");
  await testHelper.setup();
  test('basic color interpolation', () async {
    await testHelper.withViewer((viewer) async {
      final dist = 5.0;
      final numPositions = 3;
      final cameraPositions = List<Vector3>.generate(
        numPositions,
        (i) => Vector3(
          sin(i / numPositions * pi / 4) * dist,
          dist,
          cos(i / numPositions * pi / 4) * dist,
        ),
      );

      final cameraForwardVectors = cameraPositions.map((c) {
        var viewMatrix = makeViewMatrix(c, Vector3.zero(), Vector3(0, 1, 0));
        viewMatrix.invert();
        return -viewMatrix.forward;
      }).toList();

      final camera = await viewer.view.getCamera();

      final (numCameraPositions, width, height, channels) = (
        cameraPositions.length,
        1,
        1,
        4,
      );
      final (vdtmMi, texture) = await _makeVDTMMaterial(
          viewer, cameraForwardVectors, width, height, channels);

      await FilamentApp.instance!.flush();
      final cube = await _makeCube(testHelper, viewer);
      await cube.setMaterialInstanceAt(vdtmMi);
      for (int i = 0; i < numCameraPositions; i++) {
        await camera.lookAt(cameraPositions[i]);
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
        await testHelper.capture(viewer.view, "vdtm_interpolated_$i");
      }
    }, addSkybox: true);
  });

  test('static texture check', () async {
    await testHelper.withViewer((viewer) async {
      final dist = 5.0;
      final numPositions = 3;
      final cameraPositions = List<Vector3>.generate(
        numPositions,
        (i) => Vector3(
          sin(i / (numPositions - 1) * pi / 2) * dist,
          0,
          cos(i / (numPositions - 1) * pi / 2) * dist,
        ),
      );
      final cameraForwardVectors = cameraPositions.map((c) {
        var viewMatrix = makeViewMatrix(c, Vector3.zero(), Vector3(0, 1, 0));
        viewMatrix.invert();
        var forward = (-viewMatrix.forward).normalized();
        return forward;
      }).toList();

      final camera = await viewer.view.getCamera();
      final vp = await viewer.view.getViewport();
      final (width, height) = (vp.width, vp.height);

      final cube = await _makeCube(testHelper, viewer);
      final ubershader = await cube.getMaterialInstanceAt();

      final (image, originalTexture, sampler) =
          await createTextureFromImage(testHelper);
      await ubershader.setParameterTexture(
          "baseColorMap", originalTexture, sampler);

      await testHelper.capture(viewer.view, "vdtm_static_texture_initial");

      final (vdtmMi, texture) = await _makeVDTMMaterial(
          viewer,
          cameraForwardVectors,
          await image.getWidth(),
          await image.getHeight(),
          await image.getChannels());

      await cube.setMaterialInstanceAt(vdtmMi);

      final pixelData = (await image.getData()).buffer.asUint8List();
      for (int i = 0; i < cameraPositions.length; i++) {
        await camera.lookAt(cameraPositions[i]);
        await texture.setImage3D(
          0,
          0,
          0,
          i,
          await image.getWidth(),
          await image.getHeight(),
          await image.getChannels(),
          1,
          pixelData,
          PixelDataFormat.RGBA,
          PixelDataType.FLOAT,
        );
        await Future.delayed(Duration(milliseconds: 100));
        await testHelper.capture(viewer.view, "vdtm_static_texture_$i");
      }
    }, addSkybox: true);
  });

  test('VDTM + texture projection', () async {
    await testHelper.withViewer((viewer) async {
      final dist = 5.0;
      final numPositions = 3;
      final cameraPositions = List<Vector3>.generate(
        numPositions,
        (i) => Vector3(
          sin(i / numPositions * pi) * dist,
          dist,
          cos(i / numPositions * pi) * dist,
        ),
      );
      final cameraForwardVectors = cameraPositions.map((c) {
        var viewMatrix = makeViewMatrix(c, Vector3.zero(), Vector3(0, 1, 0));
        viewMatrix.invert();
        return -viewMatrix.forward;
      }).toList();
      final camera = await viewer.view.getCamera();
      await camera.setLensProjection(near: 0.75, far: 100);
      final vp = await viewer.view.getViewport();

      final (numCameraPositions, width, height, channels) = (
        cameraPositions.length,
        vp.width,
        vp.height,
        4,
      );

      final (image, originalTexture, sampler) =
          await createTextureFromImage(testHelper);

      final (vdtmMi, vdtmTexture) = await _makeVDTMMaterial(
          viewer, cameraForwardVectors, width, height, 4);

      await FilamentApp.instance!.flush();

      final cube = await _makeCube(testHelper, viewer);

      final ubershader = await cube.getMaterialInstanceAt();

      await ubershader.setParameterTexture(
          "baseColorMap", originalTexture, sampler);

      final textureProjection =
          await TextureProjection.create(viewer.view, testHelper.swapChain);

      await FilamentApp.instance!.setClearOptions(0, 0, 0, 1,
          clearStencil: 0, discard: false, clear: true);

      final projectedImage =
          await FilamentApp.instance!.createImage(width, height, 4);
      final projectedTexture = await FilamentApp.instance!.createTexture(
        width,
        height,
        textureFormat: TextureFormat.RGBA32F,
      );

      print(cameraForwardVectors[0].dot(cameraForwardVectors[1]));

      // capture the cube with its original texture from each camera position
      for (final entry in cameraPositions.asMap().entries) {
        var (i, position) = (entry.key, entry.value);
        await camera.lookAt(position);

        await textureProjection.project(cube);
        final projectedPixelBuffer =
            textureProjection.getProjectedPixelBuffer();
        await cube.setMaterialInstanceAt(ubershader);

        await savePixelBufferToBmp(textureProjection.getColorBuffer(), width,
            height, "${testHelper.outDir.path}/initial_$i.bmp");
        // await savePixelBufferToBmp(projectedPixelBuffer, width, height,
        //     "${testHelper.outDir.path}/initial_projected_uv_mapped_$i.bmp");

        await vdtmTexture.setImage3D(
            0,
            0,
            0,
            i,
            width,
            height,
            4,
            1,
            projectedPixelBuffer.buffer.asUint8List(),
            PixelDataFormat.RGBA,
            PixelDataType.FLOAT);

        final data = await projectedImage.getData();
        data.setRange(
            0, data.length, projectedPixelBuffer.buffer.asFloat32List());
        await projectedTexture.setLinearImage(
          projectedImage,
          PixelDataFormat.RGBA,
          PixelDataType.FLOAT,
        );
        await ubershader.setParameterTexture(
            "baseColorMap", projectedTexture, sampler);
        await cube.setMaterialInstanceAt(ubershader);
        // await testHelper.capture(viewer.view, "initial_reprojected_$i");

        await cube.setMaterialInstanceAt(vdtmMi);

        await testHelper.capture(viewer.view, "vdtm_$i");
        await cube.setMaterialInstanceAt(ubershader);
        await ubershader.setParameterTexture(
            "baseColorMap", originalTexture, sampler);
      }

      await cube.setMaterialInstanceAt(vdtmMi);

      // now check in between camera positions
      for (int i = 0; i < 6; i++) {
        final cameraPosition = Vector3(
          sin(i / 6 * pi / 4) * dist,
          dist,
          cos(i / 6 * pi / 4) * dist,
        );
        await camera.lookAt(cameraPosition);
        await testHelper.capture(viewer.view, "vdtm_interpolated_texture_$i");
      }
    }, createRenderTarget: true);
  });
}

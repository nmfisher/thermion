import 'dart:io';
import 'dart:math' as math;
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'package:image/image.dart' as img;
import 'helpers.dart';

void main() async {
  final helper = TestHelper('sss_demo_replacement');
  await helper.setup();
  test('render diagnostic sphere and animated mask', () async {
    final app = FilamentApp.instance!;
    await ViewerBuilder(helper)
        .setViewportDimensions(640, 640)
        .setBackgroundColor(img.ColorFloat32.rgba(0.025, 0.03, 0.045, 1))
        .setPostProcessing(true)
        .addSun(direction: Vector3(-0.6, -0.4, -1).normalized())
        .setCameraLookAt(Vector3(0, 0, 3.8), focus: Vector3.zero())
        .execute((result) async {
          final viewer = result.viewer;
          final material = await app.createUbershaderMaterialInstance();
          await material.setParameterFloat4('baseColorFactor', 1, 1, 1, 1);
          await material.setParameterFloat('roughnessFactor', 0.25);
          await material.setParameterFloat('metallicFactor', 0);
          await material.setParameterInt('baseColorIndex', 0);
          final texture = await app.createTexture(512, 256, textureFormat: TextureFormat.SRGB8_A8);
          final pixels = Uint8List(512 * 256 * 4);
          for (var y = 0; y < 256; y++) {
            for (var x = 0; x < 512; x++) {
              // Sharp albedo bands distinguish texture preservation from lighting diffusion.
              final dark = x % 64 < 5 || y % 48 < 3;
              final i = (y * 512 + x) * 4;
              pixels[i] = dark ? 102 : 222;
              pixels[i + 1] = dark ? 37 : 141;
              pixels[i + 2] = dark ? 27 : 104;
              pixels[i + 3] = 255;
            }
          }
          await texture.setImage(0, pixels, 512, 256, PixelDataFormat.RGBA, PixelDataType.UBYTE);
          final sampler = await app.createTextureSampler();
          await material.setParameterTexture('baseColorMap', texture, sampler);
          final sphere = await viewer.createGeometry(
            GeometryUtils.sphere(latitudeBands: 96, longitudeBands: 128),
            materialInstances: [material],
          );
          await helper.capture(viewer.view, 'sphere_off');
          await viewer.view.setSubsurfaceScatteringEnabled(true);
          final sss = viewer.view.getSubsurfaceScattering()!;
          await sss.addSkin(sphere);
          for (final (name, intensity, r, g, b) in [
            ('sphere_zero', 0.0, 0.6, 0.3, 0.15),
            ('sphere_default', 1.0, 0.6, 0.3, 0.15),
            ('sphere_wide', 1.0, 1.2, 0.6, 0.3),
          ]) {
            await sss.setParameters(
              SubsurfaceScatteringParameters(
                intensity: intensity,
                diffusionDistanceRedMm: r,
                diffusionDistanceGreenMm: g,
                diffusionDistanceBlueMm: b,
                metersPerUnit: 0.1,
              ),
            );
            await app.renderManager.render();
            await helper.capture(viewer.view, name);
          }
          await viewer.view.setSubsurfaceScatteringEnabled(false);
          await viewer.destroyAsset(sphere);
          await texture.destroy();
        });
    await ViewerBuilder(
      helper,
    ).setViewportDimensions(512, 512).setCameraLookAt(Vector3(3, 2, 6), focus: Vector3.zero()).execute((result) async {
      final asset = await result.viewer.loadGltf('${helper.assetsDir}/cube_with_morph_targets.glb');
      final morph = (await asset.getMorphTargetSets()).single;
      await result.viewer.view.setSubsurfaceScatteringEnabled(true);
      final sss = result.viewer.view.getSubsurfaceScattering()!;
      await sss.addSkin(asset);
      await sss.setParameters(
        const SubsurfaceScatteringParameters(debugOutput: SubsurfaceScatteringDebugOutput.coverage),
      );
      await app.renderableManager.setBonesFromMat4(morph.entity, [Matrix4.identity()]);
      await morph.setAllWeights([0]);
      await helper.capture(result.viewer.view, 'mask_rest');
      await morph.setAllWeights([1]);
      await helper.capture(result.viewer.view, 'mask_morphed');
      await morph.setAllWeights([0]);
      await app.renderableManager.setBonesFromMat4(morph.entity, [Matrix4.rotationY(math.pi / 4)]);
      await helper.capture(result.viewer.view, 'mask_bone');
    });
    expect(Directory(helper.outDirPath).listSync().length, greaterThanOrEqualTo(7));
  });
}

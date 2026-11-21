import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'helpers.dart';

void main() async {
  final helper = TestHelper('morph-diagnosis');
  await helper.setup();
  final run = Platform.environment['MORPH_TRIAL'] ?? '0';
  const original = 'cube_with_morph_targets';
  const explicit = 'probe_morph_explicit';
  const baked = 'probe_morph_baked';
  // Rotate allocation and test order in the independent Dart processes.
  final fixtures = run == '1' ? [explicit, original, baked] : [original, baked, explicit];
  for (final mode in ['off', 'split', 'shared']) {
    for (final fixture in fixtures) {
      test('morph lighting $mode $fixture', () async {
        await ViewerBuilder(
          helper,
          cameraPosition: Vector3(0, 0, 12),
        ).setRenderTargetEnabled(true).setStencilBufferEnabled(true).addSun().execute((result) async {
          final app = FilamentApp.instance!;
          final viewer = result.viewer;
          final view = viewer.view as FFIView;
          Texture? splitColor;
          RenderTarget? splitTarget;
          if (mode != 'off') {
            await view.setHighlightOverlayEnabled(true);
            if (mode == 'split') {
              splitColor = await app.createTexture(
                512,
                512,
                textureFormat: TextureFormat.RGBA32F,
                flags: {
                  TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
                  TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
                  TextureUsage.TEXTURE_USAGE_BLIT_SRC,
                },
              );
              splitTarget = await app.createRenderTarget(512, 512, color: splitColor);
              await view.getHighlightOverlay()!.overlayView.setRenderTarget(splitTarget);
            }
          }
          final cube = await viewer.loadGltf(p.join(helper.assetsDir, '$fixture.glb'), addToScene: true);
          final manager = app.renderableManager;
          final entity = (await cube.getChildEntities()).firstWhere(manager.isRenderable);
          if (mode != 'off') {
            await view.setStencilHighlight(cube, r: 0, g: 1, b: 0, outlineWidth: 4);
          }
          Future<void> read(String phase) async {
            final label = '${run}_${mode}_${fixture}_$phase';
            final captures = await helper.capture(view, label, captureRenderTarget: true, render: false);
            final b = captures[view]!;
            final pixels = Float32List.view(b.buffer, b.offsetInBytes, b.lengthInBytes ~/ 4);
            final i = 4 * (256 * 512 + 256);
            print('MORPH $label center=${pixels.sublist(i, i + 3)}');
          }

          await app.render();
          await read('rest');
          await manager.setBonesFromMat4(entity, [Matrix4.translation(Vector3(3, 0, 0))]);
          await app.render();
          await read('moved');
          await manager.setBonesFromMat4(entity, [Matrix4.identity()]);
          await app.render();
          await read('reset');
          if (fixture != baked) await manager.setMorphWeightAt(entity, 0, 1.0);
          await app.render();
          await read('morph');
          await app.render();
          await read('repeat');
          final normals = await app.createBuiltInMaterial(BuiltInMaterial.normalColor);
          final mi = await normals.createInstance();
          await cube.setMaterialInstanceForAll(mi);
          await app.render();
          await read('normal');
          if (mode != 'off') {
            await view.removeStencilHighlight(cube);
            await view.setHighlightOverlayEnabled(false);
          }
          await viewer.destroyAsset(cube);
          await mi.destroy();
          await normals.destroy();
          if (splitTarget != null) await splitTarget.destroy();
          if (splitColor != null) await splitColor.destroy();
        });
      });
    }
  }
}

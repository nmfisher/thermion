import 'dart:async';
import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("picking");
  await testHelper.setup();
  Logger.root.level = Level.ALL;

  test('pick opaque cube', () async {
    await ViewerBuilder(testHelper)
        .setRenderTargetEnabled(false)
        .setBackgroundColor(kGrey)
        // Camera looking at XZ plane from an angle
        .setCameraLookAt(Vector3(10, 10, 10), focus: Vector3(0, 0, 0))
        .execute((result) async {
          final viewer = result.viewer;
          final cube = await viewer.createGeometry(GeometryUtils.cube());
          final view = await viewer.view;
          final viewport = await view.getViewport();

          final completer = Completer<PickResult>();

          await view.pick(viewport.width ~/ 2, viewport.height ~/ 2, (result) {
            completer.complete(result);
          });

          for (int i = 0; i < 10; i++) {
            await testHelper.capture(viewer.view, "opaque_pick");
            if (completer.isCompleted) {
              break;
            }
          }

          expect(completer.isCompleted, true);
          var pickResult = await completer.future;
          expect(pickResult.entity, cube.entity);
        });
  });

  // Reinstated 2026-08-18: disabled in 1750c1a5 pending a Filament build with
  // the upstream transparent-picking fix; #241 bumped to v1.75.0 which has it.
  test('pick transparent cube with transparent picking disabled ', () async {
    await ViewerBuilder(testHelper)
        .setRenderTargetEnabled(false)
        .setCameraLookAt(Vector3(10, 10, 10), focus: Vector3(0, 0, 0))
        .execute((result) async {
      await FilamentApp.instance!.setClearOptions(0, 1, 0, 1);

      final viewer = result.viewer;

      final mi = await FilamentApp.instance!.createUbershaderMaterialInstance(
          alphaMode: AlphaMode.BLEND,
          unlit: true,
          hasVertexColors: false,
          hasNormalTexture: false,
          hasBaseColorTexture: false,
          hasClearCoat: false,
          hasIOR: false);
      await mi.setParameterFloat4("baseColorFactor", 1, 0, 0, 0.5);
      final cubeGeometry = GeometryUtils.cube();
      final cube =
          await viewer.createGeometry(cubeGeometry, materialInstances: [mi]);
      final view = await viewer.view;
      final viewport = await view.getViewport();
      await view.setTransparentPickingEnabled(false);

      final completer = Completer<PickResult>();

      await view.pick(viewport.width ~/ 2, viewport.height ~/ 2, (result) {
        completer.complete(result);
      });

      for (int i = 0; i < 10; i++) {
        await testHelper.capture(viewer.view, "transparent_pick_enabled");
        if (completer.isCompleted) {
          break;
        }
      }

      expect(completer.isCompleted, true); // callback is always called
      var pickResult = await completer.future;
      print("pickResult.entity ${pickResult.entity}");
      // With transparent picking disabled, the transparent cube should NOT be picked
      expect(pickResult.entity, isNot(equals(cube.entity)));
    });
  });
}

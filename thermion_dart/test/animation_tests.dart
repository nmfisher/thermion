import 'dart:async';
import 'dart:typed_data';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/bindings.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_viewer_ffi.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("animation");
  await testHelper.setup();
  group('morph animation tests', () {
    test('retrieve morph target names', () async {
      await testHelper.withViewer((viewer) async {
        final cube = await viewer.loadGltf(
            "${testHelper.testDir}/assets/cube_with_morph_targets.glb");
        final childEntities = await cube.getChildEntities();
        var morphTargets =
            await cube.getMorphTargetNames(entity: childEntities.first);
        expect(morphTargets.length, 1);
        expect(morphTargets.first, "Key 1");
      });
    });

    test('set morph target weights', () async {
      await testHelper.withViewer((viewer) async {
        final cube = await viewer.loadGltf(
            "${testHelper.testDir}/assets/cube_with_morph_targets.glb");
        print(await cube.getChildEntityNames());
        await viewer.addToScene(cube);
        await testHelper.capture(viewer.view, "cube_no_morph");

        final childEntities = await cube.getChildEntities();

        var morphData = MorphAnimationData(
            Float32List.fromList([1.0]), ["Key 1"],
            frameLengthInMs: 1000.0 / 60.0);
        await cube.addAnimationComponent(childEntities.first);
        await cube.setMorphAnimationData(morphData);
        await viewer.render(); 
        await testHelper.capture(viewer.view, "cube_with_morph");
      }, bg: kRed);
    });
  });
}

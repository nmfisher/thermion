import 'dart:async';
import 'dart:typed_data';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("animation");

  group('morph animation tests', () {
    test('set morph animation', () async {
      await testHelper.withViewer((viewer) async {
        final cube = await viewer.loadGlb(
            "${testHelper.testDir}/assets/cube_with_morph_targets.glb");
        var morphData = MorphAnimationData(
            Float32List.fromList(List<double>.generate(60, (i) => i / 60)),
            ["Key 1"]);

        await viewer.setMorphAnimationData(cube, morphData);
        for (int i = 0; i < 60; i++) {
          await viewer.requestFrame();
          await Future.delayed(Duration(milliseconds: 17));
        }

        await testHelper.capture(viewer, "morph_animation");
      });
    });
  });
}

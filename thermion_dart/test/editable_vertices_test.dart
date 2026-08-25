import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

void main() async {
  final testHelper = TestHelper('editable_vertices');
  await testHelper.setup();

  test('editable vertices preserve source topology and morph animation', () async {
    await testHelper.withViewer(
      (viewer) async {
        final path = '${testHelper.assetsDir}/cube_with_morph_targets.glb';
        final source = await FilamentApp.instance!.parseGltf(await File(path).readAsBytes());

        Future<({Float32List rest, Float32List morphed})> capture(ThermionAsset asset) async {
          final targets = (await asset.getMorphTargetSets()).single;
          await targets.setAllWeights([0.0]);
          final rest = _pixels(await testHelper.capture(viewer.view, null));
          await targets.setAllWeights([1.0]);
          final morphed = _pixels(await testHelper.capture(viewer.view, null));
          return (rest: rest, morphed: morphed);
        }

        final plain = await viewer.loadGltf(path);
        final plainPose = await capture(plain);
        await viewer.destroyAsset(plain);

        final editable = await viewer.loadGltf(path, editableVertices: true);
        expect(editable.getVertexBuffer()!.getVertexCount(), source.vertices.length ~/ 3);
        final editablePose = await capture(editable);

        expect(
          _meanAbsoluteDifference(editablePose.rest, editablePose.morphed),
          greaterThan(0.005),
          reason: 'morph weights must still deform editable geometry',
        );
        expect(_meanAbsoluteDifference(plainPose.rest, editablePose.rest), lessThan(0.02));
        expect(_meanAbsoluteDifference(plainPose.morphed, editablePose.morphed), lessThan(0.02));

        await viewer.destroyAsset(editable);
      },
      bg: kRed,
      cameraPosition: Vector3(3, 2, 6),
    );
  });

  test('editable and unwelded modes are mutually exclusive', () async {
    await testHelper.withViewer((viewer) async {
      expect(
        () => viewer.loadGltf(
          '${testHelper.assetsDir}/cube_with_morph_targets.glb',
          editableVertices: true,
          rebuildVertices: true,
        ),
        throwsArgumentError,
      );
    });
  });
}

Float32List _pixels(Map<View, Uint8List> captures) {
  final bytes = captures.values.single;
  return Float32List.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes ~/ 4);
}

double _meanAbsoluteDifference(Float32List left, Float32List right) {
  expect(left.length, right.length);
  var total = 0.0;
  for (var i = 0; i < left.length; i++) {
    total += (left[i] - right[i]).abs();
  }
  return total / left.length;
}

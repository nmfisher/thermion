import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("morph_animation");
  await testHelper.setup();

  test('discover morph targets', () async {
    await testHelper.withViewer((viewer) async {
      var cube = await viewer.loadGltf("${testHelper.assetsDir}/cube.glb");
      expect(await cube.getMorphTargetSets(), isEmpty);

      var childEntities = await cube.getChildEntities();
      var childEntity = childEntities.first;

      var morphTargets = await cube.getMorphTargets(childEntity);
      expect(morphTargets.targets, isEmpty);

      cube = await viewer.loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb");
      final morphTargetSets = await cube.getMorphTargetSets();
      expect(morphTargetSets, hasLength(1));
      expect(morphTargetSets.single.targets, hasLength(1));
      expect(morphTargetSets.single.targets.single.index, 0);
      expect(morphTargetSets.single.targets.single.name, "Key 1");
    });
  });

  test('set morph target weights', () async {
    await testHelper.withViewer(
      (viewer) async {
        final cube = await viewer.loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb");

        await viewer.addToScene(cube);

        await testHelper.capture(viewer.view, "cube_no_morph");

        final morphTargets = (await cube.getMorphTargetSets()).single;
        await morphTargets.setWeight("Key 1", 1.0);
        await testHelper.capture(viewer.view, "cube_with_morph");

        await morphTargets.setWeights({"Key 1": 0.5});
        await morphTargets.setWeightAt(0, 0.25);
        await morphTargets.setAllWeights([0.0]);

        await expectLater(morphTargets.setWeight("Missing", 1.0), throwsArgumentError);
        await expectLater(morphTargets.setAllWeights([]), throwsArgumentError);
      },
      bg: kRed,
      cameraPosition: Vector3(3, 2, 6),
    );
  });

  test('editable vertices support mutation and morph animation', () async {
    await testHelper.withViewer(
      (viewer) async {
        final path = '${testHelper.assetsDir}/cube_with_morph_targets.glb';
        final source = await FilamentApp.instance!.parseGltf(await File(path).readAsBytes());

        Future<({Uint8List rest, Uint8List morphed})> capture(ThermionAsset asset) async {
          final targets = (await asset.getMorphTargetSets()).single;
          await targets.setAllWeights([0.0]);
          final rest = (await testHelper.capture(viewer.view, null)).values.single;
          await targets.setAllWeights([1.0]);
          final morphed = (await testHelper.capture(viewer.view, null)).values.single;
          return (rest: rest, morphed: morphed);
        }

        final original = await viewer.loadGltf(path);
        final originalPose = await capture(original);
        await viewer.destroyAsset(original);

        final editable = await viewer.loadGltf(path, vertexBufferMode: VertexBufferMode.editable);
        final editableVertexBuffer = editable.getVertexBuffer()!;
        expect(editableVertexBuffer.supportsSetBufferAt, isTrue);
        expect(editableVertexBuffer.storageMode, VertexBufferStorageMode.direct);
        expect(editableVertexBuffer.ownsResource, isFalse);
        expect(editableVertexBuffer.getVertexCount(), source.vertices.length ~/ 3);

        final instanceVertexBuffer = (await editable.getInstance(0)).getVertexBuffer()!;
        expect(instanceVertexBuffer.storageMode, VertexBufferStorageMode.direct);
        expect(instanceVertexBuffer.ownsResource, isFalse);
        final editablePose = await capture(editable);

        expect(
          _meanAbsoluteDifference(editablePose.rest, editablePose.morphed),
          greaterThan(0.005),
          reason: 'morph weights must still deform editable geometry',
        );
        expect(_meanAbsoluteDifference(originalPose.rest, editablePose.rest), lessThan(0.02));
        expect(_meanAbsoluteDifference(originalPose.morphed, editablePose.morphed), lessThan(0.02));

        final targets = (await editable.getMorphTargetSets()).single;
        await targets.setAllWeights([0.0]);

        final editedPositions = Float32List.fromList(source.vertices);
        for (var i = 0; i < editedPositions.length; i += 3) {
          editedPositions[i] += 0.5;
        }

        await editableVertexBuffer.setBufferAt(0, editedPositions).timeout(const Duration(seconds: 5));
        final editedRest = (await testHelper.capture(viewer.view, null)).values.single;

        expect(
          _meanAbsoluteDifference(editablePose.rest, editedRest),
          greaterThan(0.005),
          reason: 'updating the editable position stream must change the rendered geometry',
        );

        await targets.setAllWeights([1.0]);
        final editedMorphed = (await testHelper.capture(viewer.view, null)).values.single;
        expect(
          _meanAbsoluteDifference(editedRest, editedMorphed),
          greaterThan(0.005),
          reason: 'morph weights must still deform geometry after editing its base positions',
        );

        await viewer.destroyAsset(editable);
      },
      bg: kRed,
      cameraPosition: Vector3(3, 2, 6),
    );
  });

  test('set morph target animation', () async {
    await testHelper.withViewer(
      (viewer) async {
        final cube = await viewer.loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb", addToScene: true);

        await testHelper.capture(viewer.view, "cube_morph_animation_0");

        var morphData = MorphAnimationData(Float32List.fromList(List<double>.generate(60, (i) => i / 60)), [
          "Key 1",
        ], frameLengthInMs: 1000.0 / 60.0);

        await cube.setMorphAnimationData(morphData, targetMeshNames: ["Cube"]);
        await FilamentApp.instance!.animationManager.update(1);
        await testHelper.capture(viewer.view, "cube_morph_animation_1");
        await FilamentApp.instance!.animationManager.update(500_000_000);
        await testHelper.capture(viewer.view, "cube_morph_animation_2");
      },
      bg: kRed,
      cameraPosition: Vector3(3, 2, -6),
    );
  });

  test('newer overlapping morph animation has priority', () async {
    await testHelper.withViewer(
      (viewer) async {
        final cube = await viewer.loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb", addToScene: true);
        final morphs = (await cube.getMorphTargetSets()).single;

        await morphs.setAllWeights([0.0]);
        final zeroPose = (await testHelper.capture(viewer.view, null)).values.single;
        await morphs.setAllWeights([1.0]);
        final onePose = (await testHelper.capture(viewer.view, null)).values.single;
        await morphs.setAllWeights([0.0]);

        await cube.setMorphAnimationData(
          MorphAnimationData(Float32List.fromList([0.0]), ["Key 1"], frameLengthInMs: 1000.0),
          targetMeshNames: ["Cube"],
        );
        await cube.setMorphAnimationData(
          MorphAnimationData(Float32List.fromList([1.0]), ["Key 1"], frameLengthInMs: 1000.0),
          targetMeshNames: ["Cube"],
        );

        final animationManager = FilamentApp.instance!.animationManager;
        await animationManager.update(1);
        await animationManager.update(2);
        final animatedPose = (await testHelper.capture(viewer.view, null)).values.single;

        expect(
          _meanAbsoluteDifference(animatedPose, onePose),
          lessThan(_meanAbsoluteDifference(animatedPose, zeroPose)),
        );
      },
      bg: kRed,
      cameraPosition: Vector3(3, 2, -6),
    );
  });

  test('reject malformed morph animation buffers', () async {
    await testHelper.withViewer((viewer) async {
      final cube = await viewer.loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb");
      final renderableManager = FilamentApp.instance!.renderableManager;
      final entity = (await cube.getChildEntities()).firstWhere(renderableManager.isRenderable);
      final animationManager = FilamentApp.instance!.animationManager;

      expect(() => animationManager.setMorphAnimation(entity, [0.0], [0], 1, 2, 16.0), throwsArgumentError);
      expect(() => animationManager.setMorphAnimation(entity, [0.0], [], 1, 1, 16.0), throwsArgumentError);
      expect(() => animationManager.setMorphAnimation(entity, [0.0], [0], 1, 1, 0.0), throwsArgumentError);
    });
  });
}

double _meanAbsoluteDifference(Uint8List left, Uint8List right) {
  final leftValues = Float32List.view(left.buffer, left.offsetInBytes, left.lengthInBytes ~/ 4);
  final rightValues = Float32List.view(right.buffer, right.offsetInBytes, right.lengthInBytes ~/ 4);
  expect(leftValues.length, rightValues.length);

  var total = 0.0;
  for (var i = 0; i < leftValues.length; i++) {
    total += (leftValues[i] - rightValues[i]).abs();
  }
  return total / leftValues.length;
}

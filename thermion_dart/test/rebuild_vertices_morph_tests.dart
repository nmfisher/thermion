import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

/// Verifies that `rebuildVertices: true` preserves morph targets: applying
/// identical weights must produce the same rendered pose as a normal load.
///
/// The unwelding in GltfSceneAsset::rebuildVertexBuffers replaces indexed
/// geometry with per-triangle vertices, which used to leave the
/// gltfio-created MorphTargetBuffer (sized for the original welded vertex
/// count) attached to the renderable — silently breaking morph animation.
/// The rebuild now duplicates morph deltas into a replacement
/// MorphTargetBuffer and re-attaches it by rebuilding the renderable.
void main() async {
  final testHelper = TestHelper("rebuild_vertices_morph");
  await testHelper.setup();

  /// Loads [assetName] (plain, then rebuilt with `rebuildVertices: true`),
  /// captures the zero-weight and full-weight poses for each load, and
  /// returns them.
  Future<({Float32List plainRest, Float32List plainFull, Float32List rebuiltRest, Float32List rebuiltFull})>
      capturePoses(
    ThermionViewer viewer,
    String assetName,
    List<double> fullWeights,
  ) async {
    Future<Float32List> captureWithWeights(
        ThermionAsset asset, List<double> weights) async {
      final morphSet = (await asset.getMorphTargetSets()).single;
      await morphSet.setAllWeights(weights);
      final pixels =
          (await testHelper.capture(viewer.view, null)).values.single;
      return Float32List.view(
          pixels.buffer, pixels.offsetInBytes, pixels.lengthInBytes ~/ 4);
    }

    final plain = await viewer.loadGltf("${testHelper.assetsDir}/$assetName");
    final plainRest = await captureWithWeights(
        plain, List.filled(fullWeights.length, 0.0));
    final plainFull = await captureWithWeights(plain, fullWeights);
    await viewer.destroyAsset(plain);

    final rebuilt =
        await viewer.loadGltf("${testHelper.assetsDir}/$assetName",
            rebuildVertices: true);
    final rebuiltRest = await captureWithWeights(
        rebuilt, List.filled(fullWeights.length, 0.0));
    final rebuiltFull = await captureWithWeights(rebuilt, fullWeights);
    await viewer.destroyAsset(rebuilt);

    return (
      plainRest: plainRest,
      plainFull: plainFull,
      rebuiltRest: rebuiltRest,
      rebuiltFull: rebuiltFull
    );
  }

  void expectPoseParity(
    String label,
    Float32List plainRest,
    Float32List plainFull,
    Float32List rebuiltRest,
    Float32List rebuiltFull, {
    double parityEpsilon = 0.02,
    double minEffect = 0.005,
  }) {
    // The morph must actually move vertices on both load paths (guards
    // against a silent no-op, e.g. a dropped or zeroed morph buffer).
    final plainEffect = _meanAbsoluteDifference(plainRest, plainFull);
    final rebuiltEffect = _meanAbsoluteDifference(rebuiltRest, rebuiltFull);
    expect(plainEffect, greaterThan(minEffect),
        reason: "$label: morph weights had no effect on the plain load");
    expect(rebuiltEffect, greaterThan(minEffect),
        reason: "$label: morph weights had no effect after rebuildVertices");

    // Identical weights must produce the same pose before and after the
    // rebuild (both at rest and fully morphed).
    expect(_meanAbsoluteDifference(plainRest, rebuiltRest), lessThan(parityEpsilon),
        reason: "$label: rest pose differs between plain and rebuilt loads");
    expect(
        _meanAbsoluteDifference(plainFull, rebuiltFull), lessThan(parityEpsilon),
        reason:
            "$label: morphed pose differs between plain and rebuilt loads");
  }

  test('dense morph deltas survive rebuildVertices (skinned cube)', () async {
    await testHelper.withViewer((viewer) async {
      final poses = await capturePoses(
          viewer, "cube_with_morph_targets.glb", [1.0]);
      expectPoseParity("dense", poses.plainRest, poses.plainFull,
          poses.rebuiltRest, poses.rebuiltFull);
    }, bg: kRed, cameraPosition: Vector3(3, 2, 6));
  });

  test('sparse morph deltas survive rebuildVertices', () async {
    await testHelper.withViewer((viewer) async {
      final poses =
          await capturePoses(viewer, "cube_with_morph_targets_sparse.glb", [1.0]);
      expectPoseParity("sparse", poses.plainRest, poses.plainFull,
          poses.rebuiltRest, poses.rebuiltFull);
    }, bg: kRed, cameraPosition: Vector3(3, 2, 6));
  });

  test('multi-primitive morph targets survive rebuildVertices', () async {
    await testHelper.withViewer((viewer) async {
      final poses = await capturePoses(
          viewer, "cube_with_morph_targets_two_prims.glb", [1.0, 0.0]);
      expectPoseParity("multi-primitive (Grow)", poses.plainRest,
          poses.plainFull, poses.rebuiltRest, poses.rebuiltFull);

      // "Shift" only carries deltas on the first primitive; the second
      // primitive's missing delta must behave as a zero delta.
      final posesShift = await capturePoses(
          viewer, "cube_with_morph_targets_two_prims.glb", [0.0, 1.0]);
      expectPoseParity("multi-primitive (Shift)", posesShift.plainRest,
          posesShift.plainFull, posesShift.rebuiltRest, posesShift.rebuiltFull);
    }, bg: kRed, cameraPosition: Vector3(0, 1.5, 5.5));
  });

  test('MorphTargetSet names and counts are preserved by rebuildVertices',
      () async {
    await testHelper.withViewer((viewer) async {
      final cube = await viewer.loadGltf(
          "${testHelper.assetsDir}/cube_with_morph_targets.glb",
          rebuildVertices: true);
      final sets = await cube.getMorphTargetSets();
      expect(sets, hasLength(1));
      expect(sets.single.targets, hasLength(1));
      expect(sets.single.targets.single.name, "Key 1");
      expect(sets.single.targets.single.index, 0);

      // Weight setters must still be accepted on the rebuilt renderable.
      await sets.single.setWeight("Key 1", 0.5);
      await sets.single.setAllWeights([0.0]);
      await viewer.destroyAsset(cube);
    }, bg: kRed, cameraPosition: Vector3(3, 2, 6));
  });

  test('morph targets survive rebuildVertices across instances', () async {
    await testHelper.withViewer((viewer) async {
      final cube = await viewer.loadGltf(
          "${testHelper.assetsDir}/cube_with_morph_targets.glb",
          rebuildVertices: true,
          initialInstances: 2);

      final instanceCount = await cube.getInstanceCount();
      expect(instanceCount, 2);

      for (final instanceIndex in [0, 1]) {
        final instance = await cube.getInstance(instanceIndex);
        final childEntities = await instance.getChildEntities();
        final renderableManager = FilamentApp.instance!.renderableManager;
        final entity =
            childEntities.firstWhere(renderableManager.isRenderable);
        final morphTargets = await cube.getMorphTargets(entity);
        expect(morphTargets.targets, hasLength(1),
            reason: "instance $instanceIndex lost its morph targets");
        expect(morphTargets.targets.single.name, "Key 1");
        await morphTargets.setWeightAt(0, 1.0);
        await morphTargets.setWeightAt(0, 0.0);
      }

      await viewer.destroyAsset(cube);
    }, bg: kRed, cameraPosition: Vector3(3, 2, 6));
  });
}

double _meanAbsoluteDifference(Float32List left, Float32List right) {
  expect(left.length, right.length);
  var total = 0.0;
  for (var i = 0; i < left.length; i++) {
    total += (left[i] - right[i]).abs();
  }
  return total / left.length;
}

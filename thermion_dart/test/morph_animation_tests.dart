import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("morph_animation");
  await testHelper.setup();

  test('get morph target names', () async {
    await testHelper.withViewer((viewer) async {
      var cube = await viewer.loadGltf("${testHelper.assetsDir}/cube.glb");
      var morphTargets = await cube.getMorphTargetNames();
      expect(morphTargets.length, 0);

      var childEntities = await cube.getChildEntities();
      var childEntity = childEntities.first;

      morphTargets = await cube.getMorphTargetNames(entity: childEntity);
      expect(morphTargets.length, 0);

      cube = await viewer.loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb");
      morphTargets = await cube.getMorphTargetNames();
      expect(morphTargets.length, 0);

      childEntities = await cube.getChildEntities();

      morphTargets = await cube.getMorphTargetNames(entity: childEntities.first);
      expect(morphTargets.length, 1);
      expect(morphTargets.first, "Key 1");
    });
  });

  test('set morph target weights', () async {
    await testHelper.withViewer(
      (viewer) async {
        final cube = await viewer.loadGltf("${testHelper.assetsDir}/cube_with_morph_targets.glb");

        await viewer.addToScene(cube);

        await testHelper.capture(viewer.view, "cube_no_morph");

        await cube.setMorphTargetWeights((await cube.getChildEntities()).first, [1.0]);
        await testHelper.capture(viewer.view, "cube_with_morph");
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

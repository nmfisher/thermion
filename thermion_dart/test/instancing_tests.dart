@Timeout(const Duration(seconds: 600))
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("instancing");
  await testHelper.setup();
  test('gltf assets always create one instance', () async {
    await testHelper.withViewer((viewer) async {
      var asset =
          await viewer.loadGltf("file://${testHelper.testDir}/assets/cube.glb");
      expect(await asset.getInstanceCount(), 1);
    });
  });

  test('create gltf instance', () async {
    await testHelper.withViewer((viewer) async {
      await viewer
          .loadIbl("file://${testHelper.testDir}/assets/default_env_ibl.ktx");
      await viewer.loadSkybox(
          "file://${testHelper.testDir}/assets/default_env_skybox.ktx");
      await viewer.setPostProcessing(true);
      await viewer.setAntiAliasing(false, true, false);

      var asset = await viewer.loadGltf(
          "file://${testHelper.testDir}/assets/cube.glb",
          numInstances: 2);

      await testHelper.capture(viewer.view, "gltf");
      var instance = await asset.createInstance();
      await viewer.addToScene(instance);
      print(instance.entity);
      print(await instance.getChildEntities());

      await instance.setTransform(Matrix4.translation(Vector3(1, 0, 0)));
      await testHelper.capture(viewer.view, "gltf_with_instance");
    });
  });
}

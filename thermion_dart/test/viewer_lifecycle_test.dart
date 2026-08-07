@Timeout(const Duration(seconds: 600))
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'helpers.dart';

// Minimal isolation repro: does PURE viewer create/destroy (no loadGltf,
// loadIbl, loadSkybox, no captures) accumulate stack depth across iterations
// so it eventually overflows? If yes, the per-test leak is in
// ViewerBuilder.execute() / createViewer / destroySwapChain. If no, the leak
// is upstream (assets/materials/IBL/skybox/etc.).
void main() async {
  final testHelper = TestHelper("viewer_lifecycle");

  await testHelper.setup();

  test('10 viewer lifecycles with capture', () async {
    for (var i = 0; i < 10; i++) {
      print('[iter] $i start');
      await ViewerBuilder(testHelper).execute((result) async {
        await testHelper.capture(result.viewer.view, null);
      });
      print('[iter] $i done');
    }
  });

  test('viewer disposal releases loaded scene resources and is idempotent', () async {
    await ViewerBuilder(testHelper)
        .setRenderTargetEnabled(true)
        .addDirectLight(DirectLight.sun(direction: Vector3(0.7, -1, -0.8).normalized()))
        .execute((result) async {
          await result.viewer.loadGltf('file://${testHelper.assetsDir}/cube.glb');
          await result.viewer.loadSkybox('file://${testHelper.assetsDir}/default_env_skybox.ktx');
          await result.viewer.loadIbl('file://${testHelper.assetsDir}/default_env_ibl.ktx');
          await result.viewer.createCamera();

          expect(result.viewer.getCameraCount(), 2);

          await result.viewer.dispose();
          await result.viewer.dispose();

          expect(result.viewer.getCameraCount(), 0);
        });
  });
}

@Timeout(const Duration(seconds: 600))
import 'package:test/test.dart';
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
}

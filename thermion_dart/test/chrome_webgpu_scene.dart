@TestOn('browser')
library;

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'helpers.dart';

void main() {
  test('WebGPU renders an unlit red cube in Chromium', () async {
    final helper = TestHelper('chrome_webgpu_scene', backend: Backend.WEBGPU);
    await helper.setup();
    final app = FilamentApp.instance!;
    final scene = ViewerBuilder(
      helper,
    ).setViewportDimensions(64, 64).setPostProcessing(false).setCameraLookAt(Vector3(0, 0, 5), focus: Vector3.zero());
    await scene.execute((result) async {
      final material = await app.createUbershaderMaterialInstance(unlit: true);
      await material.setParameterFloat4('baseColorFactor', 1, 0, 0, 1);
      final cube = await result.viewer.createGeometry(GeometryUtils.cube(), materialInstances: [material]);
      await result.viewer.addToScene(cube);

      final captures = await helper.capture(result.viewer.view, null, pixelDataType: PixelDataType.UBYTE);
      final pixels = captures.values.single;
      final center = (32 * 64 + 32) * 4;
      expect(pixels[center], greaterThan(100));
      expect(pixels[center + 1], lessThan(40));
      expect(pixels[center + 2], lessThan(40));
      await result.viewer.destroyAsset(cube);
    });
  });
}

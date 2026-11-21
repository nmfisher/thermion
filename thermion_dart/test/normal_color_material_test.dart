import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("normal_color_material");
  await testHelper.setup();

  test('apply normal color material to glTF asset', () async {
    await ViewerBuilder(testHelper).addSun().setCameraPosition(Vector3(0, 1, 1.5)).execute((result) async {
      final asset = await result.viewer.loadGltf(
        "file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf",
        addToScene: true,
      );

      await testHelper.capture(result.viewer.view, "before_normal_color");

      final material = await FilamentApp.instance!.createBuiltInMaterial(BuiltInMaterial.normalColor);
      addTearDown(material.destroy);
      final normalColor = await material.createInstance();
      addTearDown(normalColor.destroy);
      await normalColor.setDoubleSided(true);

      await asset.setMaterialInstanceForAll(normalColor);
      await testHelper.capture(result.viewer.view, "normal_color_default");

      // Switch to absolute value mode
      await normalColor.setParameterInt('useAbsoluteValue', 1);
      await testHelper.capture(result.viewer.view, "normal_color_absolute_value");

      // Test opacity
      await normalColor.setParameterFloat('opacity', 0.5);
      await testHelper.capture(result.viewer.view, "normal_color_half_opacity");

      await result.viewer.removeFromScene(asset);
    });
  });

  test('apply normal color material to cube', () async {
    await ViewerBuilder(testHelper).setCameraPosition(Vector3(2, 2, 2)).execute((result) async {
      final asset = await result.viewer.loadGltf("file://${testHelper.assetsDir}/cube.glb", addToScene: true);

      final material = await FilamentApp.instance!.createBuiltInMaterial(BuiltInMaterial.normalColor);
      addTearDown(material.destroy);
      final normalColor = await material.createInstance();
      addTearDown(normalColor.destroy);

      await asset.setMaterialInstanceForAll(normalColor);
      final reference = (await testHelper.capture(result.viewer.view, "cube_normal_color")).values.single;
      final pixels = Float32List.fromList(
        reference.buffer.asFloat32List(reference.offsetInBytes, reference.lengthInBytes ~/ 4),
      );
      var visiblePixels = 0;
      for (var i = 0; i < pixels.length; i += 4) {
        if (pixels[i] > 0.45) visiblePixels++;
      }
      expect(visiblePixels, greaterThan(100));

      // cube.glb has 24 authored vertices and 36 indices, with hard normal seams.
      await result.viewer.removeFromScene(asset);
      for (final capability in [
        SceneAssetGeometryCapability.preservedTopology,
        SceneAssetGeometryCapability.barycentrics,
      ]) {
        final rebuilt = await result.viewer.loadGltf(
          "file://${testHelper.assetsDir}/cube.glb",
          requiredGeometryCapabilities: {capability},
          addToScene: true,
        );
        expect(
          rebuilt.getVertexBuffer()!.getVertexCount(),
          capability == SceneAssetGeometryCapability.preservedTopology ? 24 : 36,
        );
        await rebuilt.setMaterialInstanceForAll(normalColor);
        final frame = (await testHelper.capture(result.viewer.view, null)).values.single;
        final actual = frame.buffer.asFloat32List(frame.offsetInBytes, frame.lengthInBytes ~/ 4);
        var error = 0.0;
        for (var i = 0; i < pixels.length; ++i) {
          error += (pixels[i] - actual[i]).abs();
        }
        expect(error / pixels.length, lessThan(0.01), reason: 'Rebuilding must preserve authored normal seams');
        await result.viewer.destroyAsset(rebuilt);
      }
      await result.viewer.addToScene(asset);

      await normalColor.setParameterInt('useAbsoluteValue', 1);
      await testHelper.capture(result.viewer.view, "cube_normal_color_absolute");

      await result.viewer.removeFromScene(asset);
    });
  });
}

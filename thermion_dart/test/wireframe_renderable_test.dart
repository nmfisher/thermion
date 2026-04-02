import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("wireframe_renderable");
  await testHelper.setup();

  test('apply wireframe barycentrics to loaded glTF asset', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      final asset = await result.viewer
          .loadGltf("file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf");

      // Add to scene and capture the original solid rendering
      await result.viewer.addToScene(asset);
      await testHelper.capture(result.viewer.view, "gltf_bary_before");

      // Unweld vertices and assign barycentric coords to CUSTOM0
      await asset.applyWireframeBarycentrics();

      // Create wireframe material
      var material = FFIMaterial(await withPointerCallback<TMaterial>(
        (callback) => Material_createWireframeMaterialRenderThread(
          FilamentApp.instance!.engine,
          callback,
        ),
      ));

      // Create and configure material instance
      final instance = await material!.createInstance();

      await instance.setParameterFloat4("edgeColor", 1.0, 0.0, 1.0, 1.0);
      await instance.setParameterFloat4("faceColor", 1.0, 0.0, 0.0, 1.0);
      await instance.setParameterFloat("edgeWidth", 3.0);

      await asset.setMaterialInstanceForAll(instance);

      // Capture the wireframe rendering
      await testHelper.capture(result.viewer.view, "gltf_bary_wireframe");
    });
  });
}

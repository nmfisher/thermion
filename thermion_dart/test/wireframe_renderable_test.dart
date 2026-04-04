import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_solid_overlay.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_wireframe_geometry.dart';
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

  test('create wireframe overlay from glTF asset', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      final asset = await result.viewer
          .loadGltf("file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf");

      await result.viewer.addToScene(asset);
      await testHelper.capture(result.viewer.view, "gltf_overlay_before");

      // Create wireframe overlay as separate entity
      final overlay = await FFIWireframeAsset.createOverlayFromAsset(asset);
      await result.viewer.addToScene(overlay);
      await testHelper.capture(result.viewer.view, "gltf_overlay_wireframe");

      // Remove overlay - original should remain
      await result.viewer.removeFromScene(overlay);
      await testHelper.capture(result.viewer.view, "gltf_overlay_removed");
    });
  });

  test('create wireframe overlay from instanced glTF asset', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      final asset = await result.viewer.loadGltf(
          "file://${testHelper.assetsDir}/cube.glb",
          addToScene: false,
          initialInstances: 2);

      // Add the default instance
      final defaultInstance = await asset.getInstance(0);
      await result.viewer.addToScene(defaultInstance);

      // Create a second instance offset to the right
      final instance = await asset.createInstance();
      await instance.setTransform(Matrix4.translation(Vector3(2, 0, 0)));
      await result.viewer.addToScene(instance);
      await testHelper.capture(result.viewer.view, "instanced_gltf_before");

      // Create wireframe overlay from the parent asset
      final overlay = await FFIWireframeAsset.createOverlayFromAsset(asset);
      await result.viewer.addToScene(overlay);
      await testHelper.capture(result.viewer.view, "instanced_gltf_wireframe");

      // Remove overlay - instances should remain
      await result.viewer.removeFromScene(overlay);
      await testHelper.capture(
          result.viewer.view, "instanced_gltf_overlay_removed");
    });
  });

  test('create solid overlay from glTF asset', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      final asset = await result.viewer.loadGltf(
          "file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf",
          addToScene: false);

      // Create solid overlay
      final overlay =
          await FFISolidOverlayAsset.createOverlayFromAsset(asset);
      await result.viewer.addToScene(overlay);
      await testHelper.capture(
          result.viewer.view, "solid_overlay");

      // Remove and verify clean removal
      await result.viewer.removeFromScene(overlay);
      await testHelper.capture(
          result.viewer.view, "solid_overlay_removed");
    });
  });
}

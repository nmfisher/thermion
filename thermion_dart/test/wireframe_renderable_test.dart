import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("wireframe_renderable");
  await testHelper.setup();

  test('load with preserveGeometry and apply wireframe material', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      final asset = await result.viewer.loadGltf(
          "file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf",
          preserveGeometry: true);

      await result.viewer.addToScene(asset);
      await testHelper.capture(result.viewer.view, "preserved_before");

      // Create wireframe material
      var material = FFIMaterial(await withPointerCallback<TMaterial>(
        (callback) => Material_createWireframeMaterialRenderThread(
          FilamentApp.instance!.engine,
          callback,
        ),
      ));

      final instance = await material!.createInstance();
      await instance.setParameterFloat4("edgeColor", 0.3, 0.3, 0.3, 1.0);
      await instance.setParameterFloat4("faceColor", 0.1, 0.1, 0.1, 1.0);
      await instance.setParameterFloat("edgeWidth", 0.5);
      await instance.setDoubleSided(true);

      await asset.setMaterialInstanceForAll(instance);
      await testHelper.capture(result.viewer.view, "preserved_wireframe");
    });
  });

  test('load with preserveGeometry and apply ubershader material', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      final asset = await result.viewer.loadGltf(
          "file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf",
          preserveGeometry: true);

      await result.viewer.addToScene(asset);

      // Use ubershader for solid shading look
      final instance = await FilamentApp.instance!
          .createUbershaderMaterialInstance(
        doubleSided: true,
      );

      await instance.setParameterFloat4("baseColorFactor", 0.8, 0.8, 0.8, 1.0);
      await instance.setParameterFloat("metallicFactor", 0.0);
      await instance.setParameterFloat("roughnessFactor", 1.0);

      await asset.setMaterialInstanceForAll(instance);
      await testHelper.capture(result.viewer.view, "preserved_solid");
    });
  });

  test('load with preserveGeometry on instanced glTF', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      final asset = await result.viewer.loadGltf(
          "file://${testHelper.assetsDir}/cube.glb",
          addToScene: false,
          initialInstances: 2,
          preserveGeometry: true);

      final defaultInstance = await asset.getInstance(0);
      await result.viewer.addToScene(defaultInstance);

      final instance2 = await asset.createInstance();
      await instance2.setTransform(Matrix4.translation(Vector3(2, 0, 0)));
      await result.viewer.addToScene(instance2);
      await testHelper.capture(
          result.viewer.view, "instanced_preserved_before");

      // Apply wireframe material
      var material = FFIMaterial(await withPointerCallback<TMaterial>(
        (callback) => Material_createWireframeMaterialRenderThread(
          FilamentApp.instance!.engine,
          callback,
        ),
      ));

      final wireframeInstance = await material.createInstance();
      await wireframeInstance.setParameterFloat4(
          "edgeColor", 1.0, 0.0, 1.0, 1.0);
      await wireframeInstance.setParameterFloat4(
          "faceColor", 0.0, 0.0, 0.0, 1.0);
      await wireframeInstance.setParameterFloat("edgeWidth", 1.0);
      await wireframeInstance.setDoubleSided(true);

      await asset.setMaterialInstanceForAll(wireframeInstance);
      await testHelper.capture(
          result.viewer.view, "instanced_preserved_wireframe");
    });
  });
}

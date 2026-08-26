import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("wireframe_renderable");
  await testHelper.setup();

  test('load glTF with unwelded vertex buffers and apply wireframe material', () async {
    await ViewerBuilder(testHelper).addSun().setCameraPosition(Vector3(0, 1, 1.5)).execute((result) async {
      final original = await result.viewer.loadGltf(
        "file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf",
        addToScene: true,
      );
      // Golden artifact names are stable IDs; keep the legacy names even when
      // the public API terminology changes.
      await testHelper.capture(result.viewer.view, "rebuildVertices_false");
      expect(original.geometryCapabilities, isEmpty);
      await result.viewer.removeFromScene(original);

      final rebuilt = await result.viewer.loadGltf(
        "file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf",
        requiredGeometryCapabilities: const {SceneAssetGeometryCapability.barycentrics},
        addToScene: true,
      );
      expect(
        rebuilt.geometryCapabilities,
        containsAll(const {
          SceneAssetGeometryCapability.flatShading,
          SceneAssetGeometryCapability.barycentrics,
          SceneAssetGeometryCapability.preservedGeometry,
        }),
      );
      expect(rebuilt.geometryCapabilities, isNot(contains(SceneAssetGeometryCapability.writableVertices)));
      expect(rebuilt.geometryCapabilities, contains(SceneAssetGeometryCapability.uniqueTriangleCorners));

      final unweldedVertexBuffer = rebuilt.getVertexBuffer()!;
      expect(unweldedVertexBuffer.supportsSetBufferAt, isFalse);
      await expectLater(
        unweldedVertexBuffer.setBufferAt(0, Float32List(0)),
        throwsA(isA<StateError>().having((error) => error.toString(), 'message', contains('writableVertices'))),
      );

      await testHelper.capture(result.viewer.view, "rebuildVertices_true");

      // Use typed wireframe wrapper
      final wireframe = await FilamentApp.instance!.createWireframeMaterialInstance();
      await wireframe.setEdgeColor(0.3, 0.3, 0.3, 1.0);
      await wireframe.setFaceColor(0.1, 0.1, 0.1, 1.0);
      await wireframe.setEdgeWidth(0.5);
      await wireframe.setDoubleSided(true);

      await rebuilt.setMaterialInstanceForAll(wireframe.materialInstance);
      await testHelper.capture(result.viewer.view, "rebuildVertices_true_wireframe");

      final ubershader = await FilamentApp.instance!.createUbershaderMaterial(doubleSided: true);

      await ubershader.setBaseColorFactor(0.8, 0.8, 0.8, 1.0);
      await ubershader.setMetallicFactor(0.0);
      await ubershader.setRoughnessFactor(1.0);

      await rebuilt.setMaterialInstanceForAll(ubershader.materialInstance);
      await testHelper.capture(result.viewer.view, "rebuildVertices_true_ubershader");

      await result.viewer.removeFromScene(rebuilt);

      final flatAsset = await result.viewer.loadGltf(
        "file://${testHelper.assetsDir}/FlightHelmet/FlightHelmet.gltf",
        requiredGeometryCapabilities: const {SceneAssetGeometryCapability.flatShading},
        addToScene: true,
      );

      await flatAsset.setFlatShading(true);

      await testHelper.capture(result.viewer.view, "flat_shading_default");

      final flatUbershader = await FilamentApp.instance!.createUbershaderMaterial(doubleSided: true);
      await flatUbershader.setBaseColorFactor(0.8, 0.8, 0.8, 1.0);
      await flatUbershader.setMetallicFactor(0.0);
      await flatUbershader.setRoughnessFactor(1.0);
      await flatAsset.setMaterialInstanceForAll(flatUbershader.materialInstance);
      await testHelper.capture(result.viewer.view, "flat_shading_ubershader");
    });
  });

  test('load glTF with unwelded vertex buffers and create instance', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      final asset = await result.viewer.loadGltf(
        "file://${testHelper.assetsDir}/cube.glb",
        addToScene: true,
        initialInstances: 2,
        requiredGeometryCapabilities: const {SceneAssetGeometryCapability.barycentrics},
      );

      final instance2 = await asset.createInstance();
      await instance2.setTransform(Matrix4.translation(Vector3(2, 0, 0)));
      await result.viewer.addToScene(instance2);
      await testHelper.capture(result.viewer.view, "instanced_preserved_before");

      // Use typed wireframe wrapper
      final wireframe = await FilamentApp.instance!.createWireframeMaterialInstance();
      await wireframe.setEdgeColor(1.0, 0.0, 1.0, 1.0);
      await wireframe.setFaceColor(0.0, 0.0, 0.0, 1.0);
      await wireframe.setEdgeWidth(1.0);
      await wireframe.setDoubleSided(true);

      await instance2.setMaterialInstanceForAll(wireframe.materialInstance);
      await testHelper.capture(result.viewer.view, "instanced_preserved_wireframe");
    });
  });
}

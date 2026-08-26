import 'dart:convert';

import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("wireframe_renderable");
  await testHelper.setup();

  test('required geometry capabilities reject unsupported primitives', () async {
    await testHelper.withViewer((viewer) async {
      final binary = ByteData(28)
        ..setFloat32(12, 1.0, Endian.little)
        ..setUint16(26, 1, Endian.little);
      final jsonBytes = utf8.encode(
        jsonEncode({
          'asset': {'version': '2.0'},
          'buffers': [
            {'byteLength': 28},
          ],
          'bufferViews': [
            {'buffer': 0, 'byteOffset': 0, 'byteLength': 24, 'target': 34962},
            {'buffer': 0, 'byteOffset': 24, 'byteLength': 4, 'target': 34963},
          ],
          'accessors': [
            {
              'bufferView': 0,
              'componentType': 5126,
              'count': 2,
              'type': 'VEC3',
              'min': [0, 0, 0],
              'max': [1, 0, 0],
            },
            {'bufferView': 1, 'componentType': 5123, 'count': 2, 'type': 'SCALAR'},
          ],
          'meshes': [
            {
              'primitives': [
                {
                  'attributes': {'POSITION': 0},
                  'indices': 1,
                  'mode': 1,
                },
              ],
            },
          ],
          'nodes': [
            {'mesh': 0},
          ],
          'scenes': [
            {
              'nodes': [0],
            },
          ],
          'scene': 0,
        }),
      );
      final paddedJsonLength = (jsonBytes.length + 3) & ~3;
      final totalLength = 12 + 8 + paddedJsonLength + 8 + 28;
      final glbData = ByteData(totalLength)
        ..setUint32(0, 0x46546c67, Endian.little)
        ..setUint32(4, 2, Endian.little)
        ..setUint32(8, totalLength, Endian.little)
        ..setUint32(12, paddedJsonLength, Endian.little)
        ..setUint32(16, 0x4e4f534a, Endian.little);
      final glb = glbData.buffer.asUint8List();
      glb.setRange(20, 20 + jsonBytes.length, jsonBytes);
      glb.fillRange(20 + jsonBytes.length, 20 + paddedJsonLength, 0x20);
      final binaryHeaderOffset = 20 + paddedJsonLength;
      glbData
        ..setUint32(binaryHeaderOffset, 28, Endian.little)
        ..setUint32(binaryHeaderOffset + 4, 0x004e4942, Endian.little);
      glb.setRange(binaryHeaderOffset + 8, totalLength, binary.buffer.asUint8List());

      await expectLater(
        viewer.loadGltfFromBuffer(
          glb,
          requiredGeometryCapabilities: const {SceneAssetGeometryCapability.writableVertices},
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  test('geometry requirements are snapshotted when loading begins', () async {
    await testHelper.withViewer((viewer) async {
      final requirements = <SceneAssetGeometryCapability>{SceneAssetGeometryCapability.writableVertices};
      final load = viewer.loadGltf(
        "file://${testHelper.assetsDir}/cube.glb",
        requiredGeometryCapabilities: requirements,
      );
      requirements
        ..clear()
        ..add(SceneAssetGeometryCapability.barycentrics);

      final asset = await load;
      expect(asset.geometryCapabilities, contains(SceneAssetGeometryCapability.writableVertices));
      expect(asset.geometryCapabilities, isNot(contains(SceneAssetGeometryCapability.barycentrics)));
    });
  });

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
          SceneAssetGeometryCapability.barycentrics,
          SceneAssetGeometryCapability.accessibleGeometryBuffers,
        }),
      );
      expect(rebuilt.supportsFlatShading, isTrue);
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
        requiredGeometryCapabilities: const {SceneAssetGeometryCapability.uniqueTriangleCorners},
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
      expect(instance2.supportsFlatShading, isTrue);
      await instance2.setFlatShading(true);
      await instance2.setFlatShading(false);
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

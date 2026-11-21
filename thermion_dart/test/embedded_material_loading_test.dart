@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:test/test.dart';
import 'package:thermion_dart/src/bindings/bindings.dart' show readEmbeddedMaterial;
import 'package:thermion_dart/thermion_dart.dart';
import 'package:web/web.dart' as web;

import 'helpers.dart';

void main() async {
  final helper = TestHelper('embedded_material_loading');
  await helper.setup();

  test('renders with an embedded material without a second download', () async {
    await ViewerBuilder(helper).execute((result) async {
      final app = FilamentApp.instance!;
      final material = await app.createBuiltInMaterial(BuiltInMaterial.sharpEdge);
      addTearDown(material.destroy);
      final instance = await material.createInstance();
      addTearDown(instance.destroy);
      final triangle = GeometryUtils.duplicateVerticesWithBarycentrics(
        Float32List.fromList([-0.7, -0.7, 0, 0.7, -0.7, 0, -0.7, 0.7, 0]),
        [0, 1, 2],
      );
      final asset = await result.viewer.createGeometry(triangle, materialInstances: [instance]);
      await result.viewer.addToScene(asset);
      // The main-thread engine relies on its host to drive frames.
      for (var i = 0; i < 8; i++) {
        await app.render();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(await app.getFrameInfoHistory(), isNotEmpty);
      await result.viewer.destroyAsset(asset);
      expect(readEmbeddedMaterial('thermion.material.missing'), isNull);
      final paths = web.window.performance
          .getEntriesByType('resource')
          .toDart
          .map((entry) => Uri.parse(entry.name).path);
      expect(paths.where((path) => path.endsWith('/thermion_dart.wasm')), hasLength(1));
      expect(paths.where((path) => path.endsWith('.filamat')), isEmpty);
    });
  });
}

import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

void main() async {
  final testHelper = TestHelper("all_materials");
  await testHelper.setup();

  test('every built-in ID resolves to a usable material package', () async {
    for (final key in BuiltInMaterial.values) {
      // Hook-managed, compiled only into features.gltf: false builds
      // (exercised there by slim_build_test.dart).
      if (key == BuiltInMaterial.unlitFallback) continue;
      final material = await FilamentApp.instance!.createBuiltInMaterial(key);
      final instance = await material.createInstance();
      await instance.destroy();
      await material.destroy();
    }
  });

  test('instantiate all live materials and render one frame', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      final viewer = result.viewer;
      final app = FilamentApp.instance!;

      // gizmo + bone_overlay are created directly through the app.
      expect(await app.createGizmoMaterial(), isNotNull);
      expect(await app.createBoneOverlayMaterial(), isNotNull);

      // wireframe is applied to a mesh; cube.glb is loaded with
      // unwelded vertex buffers so it also has the preserved geometry that the
      // stencil highlight path below needs.
      final cube = await viewer.loadGltf(
        "file://${testHelper.assetsDir}/cube.glb",
        requiredGeometryCapabilities: const {SceneAssetGeometryCapability.barycentrics},
        addToScene: true,
      );
      final wireframe = await app.createWireframeMaterialInstance();
      await cube.setMaterialInstanceForAll(wireframe.materialInstance);

      // grid + translation_axis are created by their overlay helpers.
      await viewer.setGridOverlayVisibility(true);
      await viewer.setTranslationAxisVisibility(true, origin: Vector3.zero(), axis: Axis.X);

      // image backs the background quad.
      await viewer.setBackgroundImage("file://${testHelper.assetsDir}/background.ktx");

      // silhouette + edge_outline back the two-pass highlight overlay.
      await viewer.view.setHighlightOverlayEnabled(true);
      await viewer.view.setStencilHighlight(cube, r: 1.0, g: 0.5, b: 0.0, outlineWidth: 3.0);

      await testHelper.capture(viewer.view, "all_materials");
    });
  });
}

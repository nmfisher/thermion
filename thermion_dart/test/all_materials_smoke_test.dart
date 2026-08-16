import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

/// Smoke test for the per-platform material split (see materials/build.sh).
///
/// Each material is embedded as a backend-specific .c file selected at build
/// time, so a material whose matc flags don't match the active backend only
/// fails when it is instantiated at runtime. CI otherwise exercises the image
/// material alone (image_tests), so a broken variant in any of the other seven
/// would go unnoticed until a user hits it.
///
/// The eight live materials: image, grid, translation_axis, wireframe, gizmo,
/// bone_overlay, silhouette, edge_outline.
void main() async {
  final testHelper = TestHelper("all_materials");
  await testHelper.setup();

  test('instantiate all live materials and render one frame', () async {
    await ViewerBuilder(testHelper).addSun().execute((result) async {
      final viewer = result.viewer;
      final app = FilamentApp.instance!;

      // gizmo + bone_overlay are created directly through the app.
      expect(await app.createGizmoMaterial(), isNotNull);
      expect(await app.createBoneOverlayMaterial(), isNotNull);

      // wireframe is applied to a mesh; cube.glb is loaded with
      // rebuildVertices so it also has the preserved geometry that the
      // stencil highlight path below needs.
      final cube = await viewer.loadGltf(
        "file://${testHelper.assetsDir}/cube.glb",
        rebuildVertices: true,
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

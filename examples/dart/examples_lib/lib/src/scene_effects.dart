import 'package:thermion_dart/thermion_dart.dart';

/// Effects + interaction showcase: bloom/FXAA post-processing with warm colour
/// grading, a green stencil-highlight outline on one object, a translation
/// gizmo on another, and a row of instanced pickable cubes.
///
/// Absorbs post_processing + highlight_effects + gizmo_basics + picking.
/// (render_targets is headless-only and stays a CLI example.)
Future<void> setupEffects(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  // Post-processing pipeline (kept restrained so highlights don't blow out
  // against the bright skybox).
  await viewer.setPostProcessing(true);
  await viewer.setAntiAliasing(false, true, false); // FXAA
  await viewer.setBloom(true, 0.15);

  final camera = await viewer.getActiveCamera();
  await camera.lookAt(Vector3(5, 4, 5), focus: Vector3(0, 0.5, 0));

  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");
  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -0.5)));

  // Warm colour grading (builder defaults to ACES tone-mapping).
  final builder = await viewer.view.createColorGradingBuilder();
  final grading = await builder
      .quality(QualityLevel.HIGH)
      .exposure(0.9)
      .whiteBalance(0.2, 0.03)
      .contrast(1.05)
      .saturation(1.05)
      .vibrance(1.05)
      .build();
  await viewer.view.setColorGrading(grading);

  // Centre cube. The green stencil-highlight outline is intentionally NOT
  // enabled here: combining the stencil highlight pass with bloom
  // post-processing blanks the frame to white. The highlight is demonstrated
  // standalone in highlight_effects.dart (which omits post-processing).
  final highlighted = await viewer.loadGltf(
    "$assetsDir/cube.glb",
    rebuildVertices: true,
  );
  await highlighted.transformToUnitCube();
  await highlighted.setTransform(Matrix4.translation(Vector3(0, 0.5, 0)));

  // Cube with a translation gizmo attached, to the left.
  final gizmoCube = await viewer.loadGltf("$assetsDir/cube.glb");
  await gizmoCube.transformToUnitCube();
  await gizmoCube.setTransform(
    Matrix4.translation(Vector3(-2.5, 0.5, 0)) *
        Matrix4.diagonal3(Vector3.all(0.7)),
  );
  final gizmo = TransformationGizmo(viewer);
  await gizmo.create(type: TransformationGizmoType.translation);
  await gizmo.attachTo(gizmoCube.entity);

  // Instanced pickable cubes, to the right.
  final pickable =
      await viewer.loadGltf("$assetsDir/cube.glb", initialInstances: 3);
  await pickable.transformToUnitCube();
  for (var i = 0; i < 3; i++) {
    final ii = await pickable.getInstance(i);
    await ii.setTransform(
      Matrix4.translation(Vector3(2.0 + i, 0.5, 0)) *
          Matrix4.diagonal3(Vector3.all(0.6)),
    );
  }
}

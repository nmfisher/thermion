import 'package:thermion_dart/thermion_dart.dart';

/// Loads the BusterDrone with a green stencil highlight outline, demonstrating
/// the highlight overlay system.
///
/// NOTE: The original CLI example also demonstrated posterize, polychromatic,
/// and internal edge detection effects. Those APIs (`setPosterizeEnabled`,
/// `setPolychromaticEnabled`, `setInternalEdgeParams`) are not available on the
/// current branch and have been omitted.
///
/// The asset is loaded with [vertexBufferMode: VertexBufferMode.unwelded] so the stencil highlight
/// can render correctly with barycentric-aware vertex buffers.
Future<void> setupHighlightEffects(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100.0,
    aspect: 1.0,
    focalLength: 28.0,
  );
  await camera.lookAt(Vector3(3, 2, 3), focus: Vector3(0, 0, 0));

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, 0)));
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");

  final asset = await viewer.loadGltf(
    "$assetsDir/BusterDrone/scene.gltf",
    vertexBufferMode: VertexBufferMode.unwelded,
  );
  await asset.transformToUnitCube();

  await viewer.view.setHighlightOverlayEnabled(true);
  await viewer.view.setStencilBufferEnabled(true);
  await viewer.view.setStencilHighlight(
    asset,
    r: 0.0,
    g: 1.0,
    b: 0.0,
    outlineWidth: 3.0,
  );
}

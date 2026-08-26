import 'package:thermion_dart/thermion_dart.dart';

/// Shows two cubes side-by-side: a wireframe-shaded cube (left) and a
/// flat-shaded cube (right), demonstrating material overrides via
/// [setMaterialInstanceForAll] and [setFlatShading].
///
/// Both assets are loaded with [vertexBufferMode: VertexBufferMode.unwelded] so their vertex buffers
/// include barycentric coordinates required by the wireframe material.
Future<void> setupWireframeAndFlatShading(
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
  await camera.lookAt(Vector3(3, 3, 3), focus: Vector3(0, 0, 0));

  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));
  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");

  // Wireframe cube on the left.
  final wireframe =
      await viewer.loadGltf("$assetsDir/cube.glb", vertexBufferMode: VertexBufferMode.unwelded);
  await wireframe.transformToUnitCube();
  await wireframe.setTransform(Matrix4.translation(Vector3(-1, 0, 0)));

  final wireframeMat = await viewer.app.createWireframeMaterialInstance();
  await wireframeMat.setEdgeColor(0.3, 0.3, 0.3, 1.0);
  await wireframeMat.setFaceColor(0.1, 0.1, 0.1, 1.0);
  await wireframeMat.setEdgeWidth(1.0);
  await wireframe.setMaterialInstanceForAll(wireframeMat.materialInstance);

  // Flat-shaded cube on the right.
  final flat =
      await viewer.loadGltf("$assetsDir/cube.glb", vertexBufferMode: VertexBufferMode.unwelded);
  await flat.transformToUnitCube();
  await flat.setTransform(Matrix4.translation(Vector3(1, 0, 0)));
  await flat.setFlatShading(true);
}

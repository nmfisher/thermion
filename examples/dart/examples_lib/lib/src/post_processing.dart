import 'package:thermion_dart/thermion_dart.dart';

/// Loads the BusterDrone with post-processing enabled: FXAA anti-aliasing,
/// bloom, and a warm colour-grading LUT.
Future<void> setupPostProcessing(
  ThermionViewer viewer, {
  required String assetsDir,
}) async {
  await viewer.setPostProcessing(true);
  await viewer.setAntiAliasing(false, true, false);
  await viewer.setBloom(true, 0.5);

  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100.0,
    aspect: 1.0,
    focalLength: 28.0,
  );
  await camera.lookAt(Vector3(3, 2, 3), focus: Vector3(0, 0, 0));

  await viewer.loadSkybox("$assetsDir/default_env_skybox.ktx");
  await viewer.loadIbl("$assetsDir/default_env_ibl.ktx");
  await viewer.addDirectLight(DirectLight.sun(direction: Vector3(0, -1, -1)));

  await viewer.loadGltf("$assetsDir/BusterDrone/scene.gltf");

  // Warm colour grading (skips toneMapper -- the builder defaults to
  // ACESLegacy when toneMapper is not explicitly set).
  final builder = await viewer.view.createColorGradingBuilder();
  final grading = await builder
      .quality(QualityLevel.HIGH)
      .exposure(1.2)
      .whiteBalance(0.3, 0.05)
      .contrast(1.1)
      .saturation(1.1)
      .vibrance(1.2)
      .build();
  await builder.dispose();
  await viewer.view.setColorGrading(grading);
}

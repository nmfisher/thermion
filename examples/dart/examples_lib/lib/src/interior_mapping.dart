import 'package:thermion_dart/thermion_dart.dart';

/// Twelve procedural rooms rendered on one two-triangle facade.
///
/// Drag the camera in the web gallery to reveal side walls, floors and ceilings.
/// Room surfaces and the furniture cutout plane are computed by the material;
/// they have no geometry, collision, or scene-light shadows. UV cells correspond
/// to 1 x 1.2 world units on this facade, matching the material's roomSize.xy.
/// Glass reflects the skybox environment, not other scene objects. Set
/// [glassStrength] to zero to compare with open windows.
Future<void> setupInteriorMapping(
  ThermionViewer viewer, {
  required String assetsDir,
  double glassStrength = 1.0,
}) async {
  final app = FilamentApp.instance!;
  final viewport = await viewer.view.getViewport();
  final camera = await viewer.getActiveCamera();
  await camera.setLensProjection(
    near: 0.1,
    far: 100,
    aspect: viewport.height > 0 ? viewport.width / viewport.height : 1,
    focalLength: 32,
  );
  await camera.lookAt(Vector3(3.6, 1.6, 7.8), focus: Vector3.zero());
  // Borrow the viewer-owned skybox texture for the glass. Keep that skybox
  // alive while these material instances use it; rebind if it is replaced.
  final skybox = await viewer.loadSkybox('$assetsDir/interior_environment.ktx');
  final reflectionTexture = skybox.getTexture()!;
  final reflectionSampler = await app.createTextureSampler(
    minFilter: TextureMinFilter.LINEAR,
    magFilter: TextureMagFilter.LINEAR,
    wrapS: TextureWrapMode.CLAMP_TO_EDGE,
    wrapT: TextureWrapMode.CLAMP_TO_EDGE,
    wrapR: TextureWrapMode.CLAMP_TO_EDGE,
  );

  final material = await app.createMaterial(
      await app.loadResource('$assetsDir/interior_mapping.filamat'));
  final instance = await material.createInstance();
  await instance.setParameterFloat2('roomGrid', 4, 3);
  await instance.setParameterFloat3('roomSize', 1, 1.2, 1.6);
  await instance.setParameterFloat('parallaxStrength', 1);
  await instance.setParameterFloat('frameWidth', 0.085);
  await instance.setParameterFloat('interiorBrightness', 1.25);
  await instance.setParameterTexture(
      'reflectionMap', reflectionTexture, reflectionSampler);
  await instance.setParameterFloat('glassStrength', glassStrength);
  await instance.setParameterFloat('glassReflectance', 0.04);
  await instance.setParameterFloat3('glassTint', 0.93, 0.98, 1.0);
  await instance.setParameterFloat('reflectionBrightness', 1.0);
  await instance.setParameterInt('debugView', 0);
  await viewer.createGeometry(
    Geometry(
      Float32List.fromList([-2, -1.8, 0, 2, -1.8, 0, 2, 1.8, 0, -2, 1.8, 0]),
      [0, 1, 2, 0, 2, 3],
      normals: Float32List.fromList([0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1]),
      uvs: Float32List.fromList([0, 0, 1, 0, 1, 1, 0, 1]),
    ),
    materialInstances: [instance],
  );
}

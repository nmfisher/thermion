import 'package:thermion_dart/thermion_dart.dart';
import 'package:test/test.dart';
import 'helpers.dart';

/// Runtime material compilation (filamat) is opt-in via the
/// `runtime_materials` user define; the CI workflow runs this file in a leg
/// that appends `runtime_materials: true` to the consuming package's
/// pubspec.yaml before building. In the default leg the test asserts the
/// feature is reported unsupported and the API throws UnsupportedError.
void main() async {
  final testHelper = TestHelper("runtime_material");
  await testHelper.setup();

  final app = FilamentApp.instance!;

  const source = '''
void material(inout MaterialInputs material) {
  prepareMaterial(material);
  material.baseColor.rgb = float3(1.0, 0.0, 0.0);
  material.roughness = 0.5;
  material.metallic = 0.0;
}
''';

  test('runtimeMaterialsSupported is a bool', () async {
    // Trivial smoke check; the value itself depends on the build flag.
    expect(app.runtimeMaterialsSupported, isA<bool>());
  });

  test('compileMaterialSource compiles, validates, and instantiates', () async {
    if (!app.runtimeMaterialsSupported) {
      // Default build (no runtime_materials flag): must throw, not crash.
      expect(() => app.compileMaterialSource('runtime_test', source), throwsUnsupportedError);
      return;
    }
    final material = await app.compileMaterialSource('runtime_test', source, shading: MaterialShading.lit);
    addTearDown(material.destroy);

    // createMaterial already verified the package version while building
    // (Material_getPackageVersion == Material_getSupportedVersion), so
    // reaching here proves the filamat-produced package is loadable.
    expect(await material.hasParameter('baseColorIndex'), isFalse);

    final instance = await material.createInstance();
    addTearDown(instance.destroy);
    await instance.setDepthWriteEnabled(true);
  });

  test('empty source is rejected before any native work', () async {
    if (!app.runtimeMaterialsSupported) {
      expect(() => app.compileMaterialSource('runtime_test', ''), throwsUnsupportedError);
      return;
    }
    expect(() => app.compileMaterialSource('runtime_test', ''), throwsArgumentError);
  });
}

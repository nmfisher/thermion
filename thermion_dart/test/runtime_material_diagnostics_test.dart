import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'src/test_io.dart';

void main() {
  late FFIFilamentApp app;
  setUpAll(() async {
    await FFIFilamentApp.create(
      config: FFIFilamentConfig(loadResource: loadResourceBytes, backend: defaultTestBackend),
    );
    app = FilamentApp.instance! as FFIFilamentApp;
  });
  tearDownAll(() => app.destroy());

  test('diagnostic suite requires the enabled compiler', () {
    expect(app.runtimeMaterialsSupported, isTrue);
  });

  test('parser errors identify the invalid block in the public StateError', () async {
    await expectLater(
      app.compileMaterialPackage('parse_diagnostic', 'unexpectedBlock {}'),
      throwsA(isA<StateError>().having((error) => error.message, 'parser diagnostic', contains('unexpectedBlock'))),
    );
  });

  test('include errors identify the missing include in the public StateError', () async {
    await expectLater(
      app.compileMaterialPackage('include_diagnostic', '#include "missing_shader.glsl"'),
      throwsA(
        isA<StateError>().having((error) => error.message, 'include diagnostic', contains('missing_shader.glsl')),
      ),
    );
  });

  test('shader-source failure retains the shader log guidance', () async {
    await expectLater(
      app.compileMaterialSource('shader_diagnostic', 'void material(inout MaterialInputs material) { broken syntax; }'),
      throwsA(isA<StateError>().having((error) => error.message, 'shader diagnostic', contains('Filament rejected'))),
    );
  });

  test('error results own their text and legacy functions still return null', () {
    final name = 'owned_error'.toNativeUtf8().cast<Char>();
    final firstSource = 'firstInvalidBlock {}'.toNativeUtf8().cast<Char>();
    final secondSource = 'secondInvalidBlock {}'.toNativeUtf8().cast<Char>();
    final first = MaterialCompiler_compileMaterialPackageWithDiagnostics(
      app.jobThreadHandle,
      app.engine,
      name,
      firstSource,
      nullptr,
    );
    final second = MaterialCompiler_compileMaterialPackageWithDiagnostics(
      app.jobThreadHandle,
      app.engine,
      name,
      secondSource,
      nullptr,
    );
    try {
      expect(first, isNot(nullptr));
      expect(second, isNot(nullptr));
      expect(MaterialCompiler_getPackageSize(first), 0);
      expect(MaterialCompiler_getPackageError(first).cast<Utf8>().toDartString(), contains('firstInvalidBlock'));
      expect(MaterialCompiler_getPackageError(second).cast<Utf8>().toDartString(), contains('secondInvalidBlock'));
      expect(
        MaterialCompiler_compileMaterialPackage(app.jobThreadHandle, app.engine, name, firstSource, nullptr),
        nullptr,
      );
    } finally {
      MaterialCompiler_destroyPackage(first);
      MaterialCompiler_destroyPackage(second);
      free(name);
      free(firstSource);
      free(secondSource);
    }
  });

  test('successful compilation recovers after diagnostic failures', () async {
    final material = await app.compileMaterialPackage('after_errors', '''
material { name : AfterErrors, shadingModel : unlit }
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(1.0);
    }
}
''');
    final instance = await material.createInstance();
    await instance.destroy();
    await material.destroy();
  });
}

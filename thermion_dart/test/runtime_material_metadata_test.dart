import 'dart:convert';
import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'src/test_io.dart';

void main() {
  late FFIFilamentApp app;
  setUpAll(() async {
    await initTestBindings();
    await FFIFilamentApp.create(
      config: FFIFilamentConfig(loadResource: loadResourceBytes, backend: defaultTestBackend),
    );
    app = FilamentApp.instance! as FFIFilamentApp;
  });
  tearDownAll(() => app.destroy());

  Map<String, Uint8List> compileChunks(String source, {required bool fullPackage}) {
    final name = 'metadata_test'.toNativeUtf8().cast<Char>();
    final text = source.toNativeUtf8().cast<Char>();
    final package = fullPackage
        ? MaterialCompiler_compileMaterialPackage(app.jobThreadHandle, app.engine, name, text, nullptr)
        : MaterialCompiler_compileMaterialSource(app.jobThreadHandle, app.engine, name, text, TShading.SHADING_UNLIT);
    free(name);
    free(text);
    expect(package, isNot(nullptr));
    try {
      final size = MaterialCompiler_getPackageSize(package);
      final data = MaterialCompiler_getPackagePtr(package);
      expect(data, isNot(nullptr));
      final bytes = Uint8List.fromList(data.asTypedList(size));
      final view = ByteData.sublistView(bytes);
      final chunks = <String, Uint8List>{};
      for (var offset = 0; offset < size;) {
        final tag = ascii.decode(bytes.sublist(offset, offset + 8).reversed.toList());
        final length = view.getUint32(offset + 8, Endian.little);
        chunks[tag] = Uint8List.sublistView(bytes, offset + 12, offset + 12 + length);
        offset += 12 + length;
      }
      return chunks;
    } finally {
      MaterialCompiler_destroyPackage(package);
    }
  }

  void expectMetadata(Map<String, Uint8List> chunks) {
    final flags = utf8.decode(chunks['MAT_CPRM']!).replaceAll('\u0000', '');
    expect(flags, startsWith('-O -p '));
    expect(flags, contains('-a '));
    expect(chunks['MAT_SRC '], isNotEmpty);
  }

  test('source API embeds flags and shader source', () {
    expect(app.runtimeMaterialsSupported, isTrue);
    expectMetadata(
      compileChunks('''
void material(inout MaterialInputs material) {
    prepareMaterial(material);
    material.baseColor = vec4(1.0);
}
''', fullPackage: false),
    );
  });

  test('package API embeds flags and resolved package source', () {
    expect(app.runtimeMaterialsSupported, isTrue);
    expectMetadata(
      compileChunks('''
material { name : RuntimeMetadata, shadingModel : unlit }
fragment {
    void material(inout MaterialInputs material) {
        prepareMaterial(material);
        material.baseColor = vec4(1.0);
    }
}
''', fullPackage: true),
    );
  });
}

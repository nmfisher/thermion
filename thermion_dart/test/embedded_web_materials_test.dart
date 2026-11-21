@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/interface/built_in_material.dart';
import 'package:thermion_dart/src/hooks/built_in_materials.dart';

void main() {
  test('embeds named packages and restores the pristine engine when the selection is cleared', () async {
    final root = Directory.systemTemp.createTempSync('thermion-embedded-test-');
    addTearDown(() => root.deleteSync(recursive: true));
    final engine = Directory.fromUri(root.uri.resolve('engine/'))..createSync();
    final output = Directory.fromUri(root.uri.resolve('web/'));
    final base = File.fromUri(engine.uri.resolve('thermion_dart.wasm'));
    const wasmHeader = [0, 97, 115, 109, 1, 0, 0, 0];
    base.writeAsBytesSync(wasmHeader);
    File.fromUri(engine.uri.resolve('thermion_dart.js')).writeAsStringSync('loader');
    final data = List<int>.generate(17000, (i) => i & 255);
    final package = File.fromUri(root.uri.resolve('normal_color.filamat'))..writeAsBytesSync(data);
    final built = File.fromUri(output.uri.resolve('thermion_dart.wasm'));
    final name = utf8.encode('thermion.material.normal_color');
    // The 17,031-byte payload length occupies three unsigned LEB128 bytes.
    final expected = [...wasmHeader, 0, 0x87, 0x85, 0x01, name.length, ...name, ...data];
    Future<void> stage(Map<BuiltInMaterial, File> files) => stageWebEngine(engine, output, files, onLog: (_) {});
    final authoredStage = Directory.fromUri(output.uri.resolve('.staging-thermion-materials-user/'))
      ..createSync(recursive: true);
    await stage({BuiltInMaterial.normalColor: package});
    expect(built.readAsBytesSync(), expected);
    await stage({BuiltInMaterial.normalColor: package});
    expect(built.readAsBytesSync(), expected);
    expect(base.readAsBytesSync(), wasmHeader);
    expect(authoredStage.existsSync(), isTrue);
    await expectLater(
      stage({BuiltInMaterial.sharpEdge: File.fromUri(root.uri.resolve('missing'))}),
      throwsA(isA<FileSystemException>()),
    );
    expect(built.readAsBytesSync(), expected);
    await stage({});
    expect(built.readAsBytesSync(), wasmHeader);
    expect(File.fromUri(output.uri.resolve('thermion_dart.js')).readAsStringSync(), 'loader');
    expect(Directory.fromUri(output.uri.resolve('thermion_materials/')).existsSync(), isFalse);
  });
}

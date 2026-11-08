@TestOn('vm')
library;

import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('every guarded C export is generated as a non-leaf FFI call', () {
    final guarded = <String>{};
    final export = RegExp(r'EMSCRIPTEN_KEEPALIVE\s+[^;{}]*?\b(\w+)\s*\([^;{}]*\)\s*\{\s*THERMION_ENGINE_API_GUARD\s*;');
    for (final file in Directory('native/src').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.cpp')) continue;
      for (final match in export.allMatches(file.readAsStringSync())) {
        guarded.add(match[1]!);
      }
    }
    expect(guarded.length, greaterThanOrEqualTo(470));
    // Some legacy C++ exports have no public header and thus no Dart binding.
    final publicNames = <String>{};
    for (final file in Directory('native/include/c_api').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.h')) continue;
      for (final match in RegExp(r'\b(\w+)\s*\(').allMatches(file.readAsStringSync())) {
        publicNames.add(match[1]!);
      }
    }
    final callable = guarded.intersection(publicNames);
    expect(callable.length, greaterThan(400));
    final generated = File('lib/src/bindings/src/thermion_dart_ffi.g.dart').readAsStringSync();
    final annotations = <String, String>{};
    final declaration = RegExp(r'@ffi\.Native<(.*?)external\s+[^;]*?\b(\w+)\s*\(', dotAll: true);
    for (final match in declaration.allMatches(generated)) {
      annotations[match[2]!] = match[1]!;
    }
    for (final name in {...callable, 'JobThread_destroy', 'FrameScheduler_stop'}) {
      expect(annotations, contains(name), reason: 'Missing native binding for $name');
      expect(annotations[name], isNot(contains('isLeaf: true')), reason: '$name can block');
    }
    // Queue submissions snapshot borrowed typed data synchronously and retain
    // their leaf contract; pure CPU matrix/package helpers do too.
    for (final name in [
      'TransformManager_setTransformFromBufferJobThread',
      'Mat4_getData',
      'Material_getPackageVersion',
    ]) {
      expect(annotations[name], contains('isLeaf: true'), reason: '$name must retain its borrowing contract');
    }
  });
}

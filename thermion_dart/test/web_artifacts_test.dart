import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:thermion_dart/src/filament/src/interface/built_in_material.dart';
import 'package:thermion_dart/src/hooks/built_in_materials.dart';
import 'package:thermion_dart/src/hooks/web_artifacts.dart';

void main() {
  test('each built-in requires its own true key', () {
    final warnings = <String>[];
    expect(selectBuiltInMaterials(null, onWarning: warnings.add), isEmpty);
    for (final material in BuiltInMaterial.values.where((m) => m != BuiltInMaterial.unlitFallback)) {
      expect(selectBuiltInMaterials({material.key: true}, onWarning: warnings.add), [material]);
    }
    expect(warnings, isEmpty);

    // unlit_fallback is hook-managed (features.gltf: false builds only),
    // never a user-selectable materials.* key.
    expect(selectBuiltInMaterials({BuiltInMaterial.unlitFallback.key: true}, onWarning: warnings.add), isEmpty);
    expect(warnings.single, contains('unlit_fallback'));
    warnings.clear();

    final selection = selectBuiltInMaterials({
      'include_defaults': true,
      'backends': {'android': 'vulkan'},
      'image': false,
      'gizmo': true,
    }, onWarning: warnings.add);
    expect(selection, [BuiltInMaterial.gizmo]);
    expect(warnings.single, contains('include_defaults'));
  });

  group('resolveWebVariant', () {
    test('null → default (no warning)', () {
      final r = resolveWebVariant(null);
      expect(r.zipSuffix, '');
      expect(r.cacheSuffix, '');
      expect(r.warnings, isEmpty);
    });

    test('unset-ish raw values → default (no warning)', () {
      for (final raw in ['', ' ', 'worker', 'default']) {
        final r = resolveWebVariant(raw);
        expect(r.zipSuffix, '', reason: 'raw=$raw');
        expect(r.cacheSuffix, '');
        expect(r.warnings, isEmpty, reason: 'raw=$raw');
      }
    });

    test('main_thread (string, case/whitespace-insensitive)', () {
      for (final raw in ['main_thread', 'Main_Thread', ' main_thread ']) {
        final r = resolveWebVariant(raw);
        expect(r.zipSuffix, '-main-thread', reason: 'raw=$raw');
        expect(r.cacheSuffix, '-main-thread');
        expect(r.warnings, isEmpty);
      }
    });

    test('non-string truthy values (bool/int) are not main_thread', () {
      // `web_variant` is a string define, unlike web_local. A stray
      // `web_variant: true` must not silently select the variant — and,
      // matching resolveMaterialBackend's lenient handling of odd input,
      // must not crash either. Warn and fall back to the default.
      for (final raw in [true, 1]) {
        final r = resolveWebVariant(raw);
        expect(r.zipSuffix, '', reason: 'raw=$raw');
        expect(r.cacheSuffix, '');
        expect(r.warnings, hasLength(1), reason: 'raw=$raw');
      }
    });

    test('unknown values → warning + fallback to default', () {
      final r = resolveWebVariant('mono_thread');
      expect(r.zipSuffix, '');
      expect(r.cacheSuffix, '');
      expect(r.warnings, hasLength(1));
      expect(r.warnings.single, contains('mono_thread'));
      expect(r.warnings.single, contains('main_thread'));
    });
  });

  group('naming', () {
    test('zip names for both variants', () {
      expect(webArtifactZipName('9a8bbe3bf', ''), 'thermion_dart-9a8bbe3bf-web.zip');
      expect(webArtifactZipName('9a8bbe3bf', '-main-thread'), 'thermion_dart-9a8bbe3bf-web-main-thread.zip');
    });

    test('URLs compose with the R2 base', () {
      expect(
        webArtifactUrl('9a8bbe3bf', ''),
        'https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/thermion_dart-9a8bbe3bf-web.zip',
      );
      expect(
        webArtifactUrl('9a8bbe3bf', '-main-thread'),
        'https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/thermion_dart-9a8bbe3bf-web-main-thread.zip',
      );
    });

    test('webLocalBuildDir maps variant to its build directory', () {
      expect(webLocalBuildDir(''), 'build');
      expect(webLocalBuildDir('-main-thread'), 'build-main-thread');
      expect(webLocalBuildDir('-runtime-materials'), 'build-runtime-materials');
      expect(webLocalBuildDir('-main-thread-runtime-materials'), 'build-main-thread-runtime-materials');
    });

    test('main_thread resolution round-trips through naming helpers', () {
      final r = resolveWebVariant('main_thread');
      expect(webArtifactZipName('v', r.zipSuffix), 'thermion_dart-v-web-main-thread.zip');
      expect(webLocalBuildDir(r.zipSuffix), 'build-main-thread');
    });

    test('CLI variant keys resolve to the same suffixes as the hook', () async {
      // bin/download_web.dart's _variants map mirrors these suffixes but
      // stays dependency-free so it cannot import this library. Parse the
      // map out of its source and pin it to the library's resolution, so a
      // rename on either side fails this test instead of shipping mismatched
      // artifact names. Resolved via package: URI so it works regardless of
      // the runner's working directory (Platform.script points at the test
      // runner's snapshot, not this file).
      final rootUri = await Isolate.resolvePackageUri(Uri.parse('package:thermion_dart/src/hooks/web_artifacts.dart'));
      final source = File('${rootUri!.resolve('../../../bin/download_web.dart').toFilePath()}').readAsStringSync();
      final mapStart = source.indexOf('const _variants = {');
      expect(mapStart, greaterThanOrEqualTo(0), reason: '_variants map not found');
      final mapEnd = source.indexOf('};', mapStart);
      final mapBody = source.substring(mapStart, mapEnd);
      const cliVariants = {
        'default': '',
        'worker': '',
        'main_thread': '-main-thread',
        'runtime-materials': '-runtime-materials',
        'main-thread-runtime-materials': '-main-thread-runtime-materials',
      };
      for (final entry in cliVariants.entries) {
        expect(
          mapBody,
          contains("'${entry.key}': '${entry.value}'"),
          reason: "bin/download_web.dart must map '${entry.key}' to '${entry.value}'",
        );
      }
      // The map must not have keys the library cannot resolve.
      final keyCount = mapBody.split('\n').where((l) => l.trim().startsWith("'")).length;
      expect(keyCount, cliVariants.length);
    });
  });

  group('withRuntimeMaterials', () {
    test('disabled by default / explicit false / falsy strings', () {
      for (final raw in [null, false, 'false', 0, '0']) {
        final r = withRuntimeMaterials(resolveWebVariant(null), raw);
        expect(r.zipSuffix, '', reason: 'raw=$raw');
        expect(r.cacheSuffix, '');
        expect(r.warnings, isEmpty);
      }
    });

    test('enabled forms append the suffix', () {
      for (final raw in [true, 'true', 1, '1']) {
        final r = withRuntimeMaterials(resolveWebVariant(null), raw);
        expect(r.zipSuffix, '-runtime-materials', reason: 'raw=$raw');
        expect(r.cacheSuffix, '-runtime-materials');
        expect(r.warnings, isEmpty);
      }
    });

    test('composes with main_thread', () {
      final r = withRuntimeMaterials(resolveWebVariant('main_thread'), true);
      expect(r.zipSuffix, '-main-thread-runtime-materials');
      expect(r.cacheSuffix, '-main-thread-runtime-materials');
      expect(webArtifactZipName('v', r.zipSuffix), 'thermion_dart-v-web-main-thread-runtime-materials.zip');
      expect(webLocalBuildDir(r.zipSuffix), 'build-main-thread-runtime-materials');
      expect(r.warnings, isEmpty);
    });

    test('combined resolution matches the CI artifact and build dir', () {
      // End-to-end: raw user defines → zip name on R2, cache segment, and
      // web_local build dir, exactly as CI builds/uploads them (see the
      // "Compile web (main-thread runtime-materials)" and upload steps in
      // regenerate-bindings-and-materials.yml).
      final r = withRuntimeMaterials(resolveWebVariant('Main_Thread'), 'true');
      expect(r.zipSuffix, '-main-thread-runtime-materials');
      expect(
        webArtifactZipName('9a8bbe3bf', r.zipSuffix),
        'thermion_dart-9a8bbe3bf-web-main-thread-runtime-materials.zip',
      );
      expect(
        webArtifactUrl('v', r.zipSuffix),
        'https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/thermion_dart-v-web-main-thread-runtime-materials.zip',
      );
      // Cache path the hook uses:
      // .dart_tool/thermion_dart/web/<version><cacheSuffix>
      expect(r.cacheSuffix, '-main-thread-runtime-materials');
      expect(webLocalBuildDir(r.zipSuffix), 'build-main-thread-runtime-materials');
    });

    test('combined variant is distinct from its single-feature variants', () {
      final combined = withRuntimeMaterials(resolveWebVariant('main_thread'), true);
      final mainThreadOnly = resolveWebVariant('main_thread');
      final runtimeMaterialsOnly = withRuntimeMaterials(resolveWebVariant(null), true);
      expect(combined.zipSuffix, isNot(mainThreadOnly.zipSuffix));
      expect(combined.zipSuffix, isNot(runtimeMaterialsOnly.zipSuffix));
      expect(combined.cacheSuffix, isNot(mainThreadOnly.cacheSuffix));
      expect(combined.cacheSuffix, isNot(runtimeMaterialsOnly.cacheSuffix));
    });

    test('preserves warnings from the underlying variant', () {
      final base = resolveWebVariant('mono_thread');
      final r = withRuntimeMaterials(base, true);
      // Unknown web_variant already warned; the resolution is the default
      // engine, so runtime-materials still composes onto it.
      expect(r.warnings, hasLength(1));
      expect(r.zipSuffix, '-runtime-materials');
    });

    test('naming round-trip for the plain runtime-materials variant', () {
      final r = withRuntimeMaterials(resolveWebVariant(null), true);
      expect(webArtifactZipName('v', r.zipSuffix), 'thermion_dart-v-web-runtime-materials.zip');
      expect(webLocalBuildDir(r.zipSuffix), 'build-runtime-materials');
      expect(
        webArtifactUrl('v', r.zipSuffix),
        'https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev/thermion_dart-v-web-runtime-materials.zip',
      );
    });
  });

  group('withWebBackend', () {
    test('webgpu and hybrid append the -webgpu suffix', () {
      for (final backend in ['webgpu', 'hybrid']) {
        final r = withWebBackend(resolveWebVariant(null), backend);
        expect(r.zipSuffix, '-webgpu', reason: 'backend=$backend');
        expect(r.cacheSuffix, '-webgpu');
        expect(r.warnings, isEmpty);
      }
    });

    test('native and webgl2 keep the default engine', () {
      for (final backend in ['native', 'webgl2']) {
        final r = withWebBackend(resolveWebVariant(null), backend);
        expect(r.zipSuffix, '', reason: 'backend=$backend');
        expect(r.cacheSuffix, '');
        expect(r.warnings, isEmpty);
      }
    });

    test('explicit main_thread uses the published WebGPU alias', () {
      for (final backend in ['webgpu', 'hybrid']) {
        final r = withWebBackend(resolveWebVariant('main_thread'), backend);
        expect(r.zipSuffix, '-main-thread-webgpu');
        expect(r.cacheSuffix, '-main-thread-webgpu');
        expect(webArtifactZipName('v', r.zipSuffix), 'thermion_dart-v-web-main-thread-webgpu.zip');
      }
    });

    test('runtime materials with WebGPU or hybrid fail before looking up an archive', () {
      for (final variant in [null, 'main_thread']) {
        final r = withRuntimeMaterials(resolveWebVariant(variant), true);
        for (final backend in ['webgpu', 'hybrid']) {
          expect(
            () => withWebBackend(r, backend),
            throwsA(isA<FormatException>().having((error) => error.message, 'message', contains('Choose WebGL2'))),
          );
        }
      }
    });

    test('both WebGPU archive names use the same local build directory', () {
      expect(webLocalBuildDir('-webgpu'), 'build-webgpu');
      expect(webLocalBuildDir('-main-thread-webgpu'), 'build-webgpu');
    });

    test('preserves warnings from the underlying variant', () {
      final base = resolveWebVariant('mono_thread');
      final r = withWebBackend(base, 'webgpu');
      expect(r.warnings, hasLength(1));
      expect(r.zipSuffix, '-webgpu');
    });
  });

  test('browser material formats match the engine choice', () {
    expect(defaultWebBackend, 'webgl2');
    expect(webMaterialBackends(defaultWebBackend), ['opengl']);
    expect(webMaterialBackends('native'), ['opengl']);
    expect(webMaterialBackends('webgpu'), ['webgpu']);
    expect(webMaterialBackends('hybrid'), ['opengl', 'webgpu']);
  });
}

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:thermion_dart/src/hooks/material_tools.dart';

/// Builds an in-memory zip from [entries] (path -> bytes) and writes it to
/// [destination], standing in for the R2 download in tests.
UrlDownloader zipDownloader(Map<String, List<int>> entries) {
  return (url, destination) async {
    final archive = Archive();
    for (final entry in entries.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    destination.writeAsBytesSync(ZipEncoder().encode(archive));
  };
}

/// A fake matc/resgen pair driven by [ToolProcess] injection. Binaries are
/// plain files (never executed); a matc "supports WebGPU" iff its file
/// content is [workingMatcContent] — capabilities travel with the binary,
/// so a freshly extracted cache dir works without any registration. Any
/// other content (stale caches, broken zips) fails the smoke test like the
/// official Filament release matc would.
const String workingMatcContent = 'works';

class FakeTools {
  FakeTools();

  int downloadCount = 0;
  final List<String> matcCompiles = [];

  bool matcWorks(String executable) {
    final file = File(executable);
    return file.existsSync() && file.readAsStringSync() == workingMatcContent;
  }

  late final ToolProcess run = (executable, args) async {
    if (executable.endsWith('matc') || executable.endsWith('matc.exe')) {
      final source = args.last;
      final works = matcWorks(executable);
      if (p.basename(source) == 'smoke.mat') {
        if (!works) {
          return (exitCode: 1, stdout: '', stderr: 'unknown backend: webgpu');
        }
        final out = args[args.indexOf('-o') + 1];
        File(out).writeAsBytesSync([1, 2, 3]);
        return (exitCode: 0, stdout: '', stderr: '');
      }
      if (!works) {
        return (exitCode: 1, stdout: '', stderr: 'unknown backend');
      }
      matcCompiles.add('${args.take(args.indexOf('-o')).join(' ')} ${p.basename(source)}');
      final out = args[args.indexOf('-o') + 1];
      // Encode the arch flags in the bytes so variants differ.
      File(out).writeAsBytesSync(args.take(args.indexOf('-o')).join(' ').codeUnits);
      return (exitCode: 0, stdout: '', stderr: '');
    }
    // resgen: -c -p <name> -x <dir>/ <filamat>
    final name = args[args.indexOf('-p') + 1];
    final outDir = args[args.indexOf('-x') + 1].replaceAll(RegExp(r'[/\\]$'), '');
    final upper = name.toUpperCase();
    File(p.join(outDir, '$name.c')).writeAsStringSync(
      '#include <stdint.h>\nconst uint8_t ${upper}_PACKAGE[] = { 0x00 };\n',
    );
    File(p.join(outDir, '$name.h')).writeAsStringSync(
      '#ifndef ${upper}_H_\n'
      '#define ${upper}_H_\n'
      '\n'
      '#include <stdint.h>\n'
      '\n'
      'extern "C" {\n'
      '    extern const uint8_t ${upper}_PACKAGE[];\n'
      '}\n'
      '\n'
      '#define ${upper}_DATA (${upper}_PACKAGE + 0)\n'
      '\n'
      '#endif\n',
    );
    File(p.join(outDir, '$name.S')).writeAsStringSync('// $name\n');
    File(p.join(outDir, '$name.bin')).writeAsBytesSync([0x00]);
    return (exitCode: 0, stdout: '', stderr: '');
  };

  /// A downloader that serves a zip whose bin/matc works (or not).
  UrlDownloader downloader({bool zipMatcWorks = true}) {
    return (url, destination) async {
      downloadCount++;
      final suffix = url.toString().contains('windows') ? '.exe' : '';
      final matc = zipMatcWorks ? workingMatcContent : 'built-without-webgpu';
      await zipDownloader({
        'bin/matc$suffix': utf8Bytes(matc),
        'bin/resgen$suffix': utf8Bytes('resgen'),
        'lib/libfilament.a': utf8Bytes('not extracted'),
        'include/filament/Material.h': utf8Bytes('not extracted'),
      })(url, destination);
    };
  }
}

List<int> utf8Bytes(String s) => s.codeUnits;

void main() {
  final tempDir = Directory.systemTemp.createTempSync('material_tools_test_');
  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  int dirCounter = 0;

  /// A fresh subdirectory of the shared temp dir. Creates parents, so it is
  /// safe even when an earlier test's cleanup removed the shared root.
  Directory freshDir(String label) {
    final dir = Directory(
      p.join(tempDir.path, '${label}_${dirCounter++}_${DateTime.now().microsecondsSinceEpoch}'),
    );
    dir.createSync(recursive: true);
    return dir;
  }

  group('resolveMaterialToolsSpec', () {
    test('resolves linux x64', () {
      final spec = resolveMaterialToolsSpec(version: 'v1.77.2', hostOS: 'linux', hostArch: 'x64');
      expect(spec.hostPlatform, 'linux');
      expect(spec.zipName, 'filament-v1.77.2-linux-release.zip');
      expect(spec.url, '$materialToolsR2BaseUrl/filament-v1.77.2-linux-release.zip');
      expect(spec.cacheDirName, 'filament-v1.77.2-webgpu-linux');
      expect(spec.exeSuffix, '');
    });

    test('resolves linux arm64 variants of the arch spelling', () {
      for (final arch in ['arm64', 'aarch64']) {
        final spec = resolveMaterialToolsSpec(version: 'v1.77.2', hostOS: 'linux', hostArch: arch);
        expect(spec.hostPlatform, 'linux-arm64');
        expect(spec.zipName, 'filament-v1.77.2-linux-arm64-release.zip');
        expect(spec.cacheDirName, 'filament-v1.77.2-webgpu-linux-arm64');
      }
    });

    test('resolves macos and windows hosts', () {
      final macos = resolveMaterialToolsSpec(version: 'v1.77.2', hostOS: 'macos', hostArch: 'arm64');
      expect(macos.hostPlatform, 'macos');
      expect(macos.zipName, 'filament-v1.77.2-macos-release.zip');
      expect(macos.exeSuffix, '');

      final windows = resolveMaterialToolsSpec(version: 'v1.77.2', hostOS: 'windows', hostArch: 'x64');
      expect(windows.hostPlatform, 'windows');
      expect(windows.zipName, 'filament-v1.77.2-windows-release.zip');
      expect(windows.exeSuffix, '.exe');
      expect(windows.cacheDirName, 'filament-v1.77.2-webgpu-windows');
    });

    test('rejects non-host platforms and unknown linux archs', () {
      expect(
        () => resolveMaterialToolsSpec(version: 'v1.77.2', hostOS: 'android', hostArch: 'arm64'),
        throwsA(isA<MaterialToolsError>()),
      );
      expect(
        () => resolveMaterialToolsSpec(version: 'v1.77.2', hostOS: 'ios', hostArch: 'arm64'),
        throwsA(isA<MaterialToolsError>()),
      );
      expect(
        () => resolveMaterialToolsSpec(version: 'v1.77.2', hostOS: 'linux', hostArch: 'riscv64'),
        throwsA(isA<MaterialToolsError>()),
      );
    });
  });

  group('defaultMaterialToolsCacheRoot', () {
    test('prefers XDG_CACHE_HOME, then HOME/.cache', () {
      expect(defaultMaterialToolsCacheRoot({'XDG_CACHE_HOME': '/xdg', 'HOME': '/home/u'}), p.join('/xdg', 'thermion', 'filament-tools'));
      expect(defaultMaterialToolsCacheRoot({'HOME': '/home/u'}), p.join('/home/u', '.cache', 'thermion', 'filament-tools'));
    });

    test('returns null when neither is set', () {
      expect(defaultMaterialToolsCacheRoot({}), isNull);
      expect(defaultMaterialToolsCacheRoot({'XDG_CACHE_HOME': '', 'HOME': ''}), isNull);
    });
  });

  group('fingerprint', () {
    test('is stable across insertion order and changes with inputs', () {
      final a = computeMaterialsFingerprint(
        version: 'v1.77.2',
        hostPlatform: 'linux',
        sourceHashes: {'a.mat': 'aaa', 'b.mat': 'bbb', 'shared.h': 'ccc'}.entries,
      );
      final b = computeMaterialsFingerprint(
        version: 'v1.77.2',
        hostPlatform: 'linux',
        sourceHashes: {'shared.h': 'ccc', 'b.mat': 'bbb', 'a.mat': 'aaa'}.entries,
      );
      expect(a, b);

      expect(
        computeMaterialsFingerprint(version: 'v1.77.3', hostPlatform: 'linux', sourceHashes: {'a.mat': 'aaa'}.entries),
        isNot(a),
      );
      expect(
        computeMaterialsFingerprint(version: 'v1.77.2', hostPlatform: 'macos', sourceHashes: {'a.mat': 'aaa'}.entries),
        isNot(a),
      );
      expect(
        computeMaterialsFingerprint(version: 'v1.77.2', hostPlatform: 'linux', sourceHashes: {'a.mat': 'changed'}.entries),
        isNot(a),
      );
    });

    test('manifest roundtrip, corrupt and schema-mismatch are misses', () {
      final manifest = File(p.join(tempDir.path, 'manifest.json'));
      expect(manifestFingerprint(manifest), isNull);

      writeMaterialManifest(manifest, fingerprint: 'fp', toolHashes: {'matc': 'm'});
      expect(manifestFingerprint(manifest), 'fp');

      manifest.writeAsStringSync('{not json');
      expect(manifestFingerprint(manifest), isNull);

      manifest.writeAsStringSync('{"schema": 99, "fingerprint": "fp"}');
      expect(manifestFingerprint(manifest), isNull);
    });
  });

  group('hashMaterialSources', () {
    test('includes .mat and .h, excludes .filamat and scripts', () {
      final dir = Directory(p.join(tempDir.path, 'hash_sources'))..createSync(recursive: true);
      File(p.join(dir.path, 'image.mat')).writeAsStringSync('material {}');
      File(p.join(dir.path, 'shared.h')).writeAsStringSync('#pragma once');
      File(p.join(dir.path, 'image.filamat')).writeAsBytesSync([1]);
      File(p.join(dir.path, 'build.sh')).writeAsStringSync('#!/bin/bash');

      final hashes = hashMaterialSources(dir);
      expect(hashes.keys.toSet(), {'image.mat', 'shared.h'});

      expect(hashMaterialSources(Directory(p.join(tempDir.path, 'missing'))), isEmpty);
    });
  });

  group('extractToolBinaries', () {
    test('extracts only bin/* entries', () {
      final archive = Archive()
        ..addFile(ArchiveFile('bin/matc', 2, [1, 2]))
        ..addFile(ArchiveFile('bin/resgen', 2, [3, 4]))
        ..addFile(ArchiveFile('bin/nested/tool', 2, [5, 6]))
        ..addFile(ArchiveFile('lib/libfilament.a', 4, [7, 8, 9, 10]))
        ..addFile(ArchiveFile('include/filament/Material.h', 3, [1, 2, 3]));
      final dest = Directory(p.join(tempDir.path, 'extract'))..createSync(recursive: true);
      final written = extractToolBinaries(archive, dest);

      expect(written, unorderedEquals(['bin/matc', 'bin/resgen', 'bin/nested/tool']));
      expect(File(p.join(dest.path, 'bin', 'matc')).readAsBytesSync(), [1, 2]);
      expect(File(p.join(dest.path, 'bin', 'nested', 'tool')).existsSync(), isTrue);
      expect(File(p.join(dest.path, 'lib', 'libfilament.a')).existsSync(), isFalse);
      expect(File(p.join(dest.path, 'include', 'filament', 'Material.h')).existsSync(), isFalse);
    });
  });

  group('smokeTestMatc', () {
    test('passes for a working matc and fails for a broken one', () async {
      final tools = FakeTools();
      final dir = freshDir('smoke');
      final good = File(p.join(dir.path, 'good_matc'))..writeAsStringSync(workingMatcContent);
      final bad = File(p.join(dir.path, 'bad_matc'))..writeAsStringSync('built-without-webgpu');

      expect(await smokeTestMatc(good, runProcess: tools.run), isTrue);
      expect(await smokeTestMatc(bad, runProcess: tools.run), isFalse);
    });
  });

  group('ensureMaterialTools', () {
    test('reuses a cache that passes the smoke test without downloading', () async {
      final tools = FakeTools();
      final spec = resolveMaterialToolsSpec(version: 'v1.77.2', hostOS: 'linux', hostArch: 'x64');
      final cacheRoot = Directory(p.join(tempDir.path, 'cache_hit'));
      final binDir = Directory(p.join(cacheRoot.path, spec.cacheDirName, 'bin'))..createSync(recursive: true);
      final matc = File(p.join(binDir.path, 'matc'))..writeAsStringSync(workingMatcContent);
      File(p.join(binDir.path, 'resgen')).writeAsStringSync('');

      final result = await ensureMaterialTools(spec: spec, cacheRoot: cacheRoot, download: tools.downloader(), runProcess: tools.run);
      expect(result.downloaded, isFalse);
      expect(result.matc.path, matc.path);
      expect(tools.downloadCount, 0);
    });

    test('re-downloads a cache whose matc fails the smoke test', () async {
      final tools = FakeTools();
      final spec = resolveMaterialToolsSpec(version: 'v1.77.2', hostOS: 'linux', hostArch: 'x64');
      final cacheRoot = Directory(p.join(tempDir.path, 'cache_stale'));
      final binDir = Directory(p.join(cacheRoot.path, spec.cacheDirName, 'bin'))..createSync(recursive: true);
      // A stale, non-WebGPU matc: present, but fails the smoke test.
      File(p.join(binDir.path, 'matc')).writeAsStringSync('stale-non-webgpu-matc');

      final result = await ensureMaterialTools(
        spec: spec,
        cacheRoot: cacheRoot,
        download: tools.downloader(zipMatcWorks: true),
        runProcess: tools.run,
      );
      expect(result.downloaded, isTrue);
      expect(tools.downloadCount, 1);
      expect(await smokeTestMatc(result.matc, runProcess: tools.run), isTrue);
      // The stale binary was replaced by the downloaded one.
      expect(result.matc.readAsStringSync(), workingMatcContent);
    });

    test('fails clearly when the zip carries no tools', () async {
      final tools = FakeTools();
      final spec = resolveMaterialToolsSpec(version: 'v1.77.2', hostOS: 'macos', hostArch: 'arm64');
      final cacheRoot = Directory(p.join(tempDir.path, 'cache_no_tools'));

      await expectLater(
        ensureMaterialTools(
          spec: spec,
          cacheRoot: cacheRoot,
          download: zipDownloader({'lib/libfilament.a': utf8Bytes('only libs')}),
          runProcess: tools.run,
        ),
        throwsA(isA<MaterialToolsError>().having((e) => e.message, 'message', contains('compile_materials'))),
      );
    });

    test('fails clearly and drops the cache when the downloaded matc cannot compile webgpu', () async {
      final tools = FakeTools();
      final spec = resolveMaterialToolsSpec(version: 'v1.77.2', hostOS: 'windows', hostArch: 'x64');
      final cacheRoot = Directory(p.join(tempDir.path, 'cache_bad_zip'));

      await expectLater(
        ensureMaterialTools(
          spec: spec,
          cacheRoot: cacheRoot,
          download: tools.downloader(zipMatcWorks: false),
          runProcess: tools.run,
        ),
        throwsA(isA<MaterialToolsError>().having((e) => e.message, 'message', contains('FILAMENT_SUPPORTS_WEBGPU'))),
      );
      // The bad cache must not survive: the next attempt re-downloads.
      expect(Directory(p.join(cacheRoot.path, spec.cacheDirName)).existsSync(), isFalse);
    });
  });

  group('generateEmbeddedMaterials', () {
    late Directory packageRoot;
    late Directory materialsDir;
    late FakeTools tools;
    late File matc;
    late File resgen;

    setUp(() {
      packageRoot = Directory(p.join(tempDir.path, 'pkg_${DateTime.now().microsecondsSinceEpoch}'));
      materialsDir = Directory(p.join(packageRoot.path, 'materials'))..createSync(recursive: true);
      for (final name in [...embeddedMaterials, gizmoMaterialName]) {
        File(p.join(materialsDir.path, '$name.mat')).writeAsStringSync('material { name : $name }');
      }
      File(p.join(materialsDir.path, 'shared.h')).writeAsStringSync('#pragma once');

      tools = FakeTools();
      final binDir = Directory(p.join(packageRoot.path, 'tools'))..createSync(recursive: true);
      matc = File(p.join(binDir.path, 'matc'))..writeAsStringSync(workingMatcContent);
      resgen = File(p.join(binDir.path, 'resgen'))..writeAsStringSync('');
    });

    test('produces every variant with build.sh-compatible rewriting', () async {
      final outRoot = Directory(p.join(packageRoot.path, 'out'));
      final sourceHashes = hashMaterialSources(materialsDir);
      final fingerprint = computeMaterialsFingerprint(
        version: 'v1.77.2',
        hostPlatform: 'linux',
        sourceHashes: sourceHashes.entries,
      );
      await generateEmbeddedMaterials(
        sourceDir: materialsDir,
        outputRoot: outRoot,
        matc: matc,
        resgen: resgen,
        fingerprint: fingerprint,
        runProcess: tools.run,
      );

      final materialDir = Directory(p.join(outRoot.path, 'material'));
      expect(generatedMaterialsComplete(materialDir), isTrue);
      // 11 materials x 8 variants, plus forwarding headers and resgen
      // byproducts.
      final cFiles = materialDir.listSync().whereType<File>().map((f) => p.basename(f.path)).where((n) => n.endsWith('.c')).toList();
      expect(cFiles.length, 11 * 8);

      // .c: prepended include + resgen body.
      final imageApple = File(p.join(materialDir.path, 'image_apple.c')).readAsStringSync();
      expect(imageApple, startsWith('#include "image_apple.h"\n#include <stdint.h>\n'));

      // .h: variant guard + __cplusplus extern guards.
      final imageAppleH = File(p.join(materialDir.path, 'image_apple.h')).readAsStringSync();
      expect(imageAppleH, startsWith('#ifndef IMAGE_APPLE_H_\n#define IMAGE_APPLE_H_\n'));
      expect(imageAppleH, contains('#ifdef __cplusplus\nextern "C" {\n#endif\n    extern const uint8_t IMAGE_PACKAGE[];\n#ifdef __cplusplus\n}\n#endif'));

      // gizmo keeps the GIZMO_* symbols but is renamed gizmo_material_*.
      final gizmoH = File(p.join(materialDir.path, 'gizmo_material_webgpu.h')).readAsStringSync();
      expect(gizmoH, startsWith('#ifndef GIZMO_MATERIAL_WEBGPU_H_'));
      expect(gizmoH, contains('extern const uint8_t GIZMO_PACKAGE[];'));

      // Forwarding headers are byte-identical to the committed ones.
      final committedBoneOverlay = File(p.join(Directory.current.path, 'native', 'include', 'material', 'bone_overlay.h')).readAsStringSync();
      expect(forwardingHeaderSource(name: 'bone_overlay', fileStem: 'bone_overlay'), committedBoneOverlay);
      final committedGizmo = File(p.join(Directory.current.path, 'native', 'include', 'material', 'gizmo.h')).readAsStringSync();
      expect(forwardingHeaderSource(name: 'gizmo', fileStem: gizmoFileStem), committedGizmo);

      // The manifest gate was written.
      expect(manifestFingerprint(File(p.join(outRoot.path, materialManifestName))), fingerprint);

      // matc saw the exact build.sh flag table, in build.sh order.
      expect(
        tools.matcCompiles.where((c) => c.endsWith(' image.mat')).toList(),
        [
          '-a metal image.mat',
          '-a vulkan -a opengl image.mat',
          '-a vulkan -a opengl image.mat',
          '-a opengl image.mat',
          '-a vulkan image.mat',
          '-a webgpu image.mat',
          '-a opengl image.mat',
          '-a opengl -a webgpu image.mat',
        ],
      );
    });

    test('a failing matc leaves the previous artifact set untouched', () async {
      final outRoot = Directory(p.join(packageRoot.path, 'out2'));
      final fingerprint = computeMaterialsFingerprint(
        version: 'v1.77.2',
        hostPlatform: 'linux',
        sourceHashes: hashMaterialSources(materialsDir).entries,
      );
      await generateEmbeddedMaterials(
        sourceDir: materialsDir,
        outputRoot: outRoot,
        matc: matc,
        resgen: resgen,
        fingerprint: fingerprint,
        runProcess: tools.run,
      );
      final before = File(p.join(outRoot.path, 'material', 'image_apple.c')).readAsStringSync();

      // Now break matc (e.g. a tool cache overwritten with garbage).
      matc.writeAsStringSync('broken-matc');
      await expectLater(
        generateEmbeddedMaterials(
          sourceDir: materialsDir,
          outputRoot: outRoot,
          matc: matc,
          resgen: resgen,
          fingerprint: 'different-fingerprint-after-source-edit',
          runProcess: tools.run,
        ),
        throwsA(isA<MaterialGenerationError>()),
      );

      // The old, complete set is still in place and no staging dirs remain.
      expect(File(p.join(outRoot.path, 'material', 'image_apple.c')).readAsStringSync(), before);
      expect(generatedMaterialsComplete(Directory(p.join(outRoot.path, 'material'))), isTrue);
      expect(
        outRoot.listSync().whereType<Directory>().where((d) => p.basename(d.path).contains('staging')).toList(),
        isEmpty,
      );
    });
  });

  group('ensureGeneratedMaterials', () {
    Directory makePackage() {
      final packageRoot = Directory(p.join(tempDir.path, 'ensure_${DateTime.now().microsecondsSinceEpoch}'));
      final materialsDir = Directory(p.join(packageRoot.path, 'materials'))..createSync(recursive: true);
      for (final name in [...embeddedMaterials, gizmoMaterialName]) {
        File(p.join(materialsDir.path, '$name.mat')).writeAsStringSync('material { name : $name }');
      }
      return packageRoot;
    }

    test('compiles on first call, then skips on fingerprint hit, then regenerates on .mat change', () async {
      final packageRoot = makePackage();
      final tools = FakeTools();
      final toolsCache = Directory(p.join(packageRoot.path, 'tools_cache'));

      var result = await ensureGeneratedMaterials(
        packageRoot: packageRoot,
        version: 'v1.77.2',
        hostOS: 'linux',
        hostArch: 'x64',
        toolsCacheRoot: toolsCache.path,
        download: tools.downloader(),
        runProcess: tools.run,
      );
      expect(result.regenerated, isTrue);
      expect(tools.downloadCount, 1);
      expect(generatedMaterialsComplete(result.materialDir), isTrue);

      // Second call: fingerprint hit — no tools needed at all.
      result = await ensureGeneratedMaterials(
        packageRoot: packageRoot,
        version: 'v1.77.2',
        hostOS: 'linux',
        hostArch: 'x64',
        toolsCacheRoot: toolsCache.path,
        download: tools.downloader(),
        runProcess: tools.run,
      );
      expect(result.regenerated, isFalse);
      expect(tools.downloadCount, 1);

      // Editing a .mat invalidates the fingerprint and regenerates.
      File(p.join(packageRoot.path, 'materials', 'image.mat')).writeAsStringSync('material { name : Image, changed }');
      result = await ensureGeneratedMaterials(
        packageRoot: packageRoot,
        version: 'v1.77.2',
        hostOS: 'linux',
        hostArch: 'x64',
        toolsCacheRoot: toolsCache.path,
        download: tools.downloader(),
        runProcess: tools.run,
      );
      expect(result.regenerated, isTrue);
      // Tools came from cache: still only the one download.
      expect(tools.downloadCount, 1);
    });

    test('a partially deleted cache regenerates despite a matching manifest', () async {
      final packageRoot = makePackage();
      final tools = FakeTools();
      final toolsCache = Directory(p.join(packageRoot.path, 'tools_cache2'));
      final run = () => ensureGeneratedMaterials(
            packageRoot: packageRoot,
            version: 'v1.77.2',
            hostOS: 'linux',
            hostArch: 'x64',
            toolsCacheRoot: toolsCache.path,
            download: tools.downloader(),
            runProcess: tools.run,
          );

      expect((await run()).regenerated, isTrue);
      // Delete one variant file but keep the manifest: must not be trusted.
      File(
        p.join(generatedMaterialsRoot(packageRoot, 'v1.77.2').path, 'material', 'gizmo_material_webgpu.c'),
      ).deleteSync();
      expect((await run()).regenerated, isTrue);
    });

    test('fails clearly without material sources', () async {
      final packageRoot = Directory(p.join(tempDir.path, 'no_sources_${DateTime.now().microsecondsSinceEpoch}'))..createSync(recursive: true);
      final tools = FakeTools();
      await expectLater(
        ensureGeneratedMaterials(
          packageRoot: packageRoot,
          version: 'v1.77.2',
          hostOS: 'linux',
          hostArch: 'x64',
          toolsCacheRoot: p.join(packageRoot.path, 'tools'),
          download: tools.downloader(),
          runProcess: tools.run,
        ),
        throwsA(isA<MaterialToolsError>().having((e) => e.message, 'message', contains('No .mat sources'))),
      );
    });
  });
}

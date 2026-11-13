import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:thermion_dart/src/hooks/material_tools.dart';

/// Builds an in-memory zip from [entries] (path -> bytes) and writes it to
/// [destination], standing in for the R2 download in tests. No network.
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
  FakeTools({this.failMatcFor, this.failResgenFor});

  /// Basenames of .mat inputs the fake matc should fail on (non-zero exit).
  final Set<String>? failMatcFor;

  /// Basenames of .mat inputs the fake resgen should fail on.
  final Set<String>? failResgenFor;

  int downloadCount = 0;

  /// One entry per real (non-smoke) matc invocation:
  /// '<-a flags joined> <input basename>'.
  final List<String> matcCompiles = [];

  /// One entry per resgen invocation: '<prefix> <filamat basename>'.
  final List<String> resgenRuns = [];

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
      if (!works || (failMatcFor?.contains(p.basename(source)) ?? false)) {
        return (exitCode: 1, stdout: '', stderr: 'matc: fake compile error for ${p.basename(source)}');
      }
      final flags = args.take(args.indexOf('-o')).join(' ');
      matcCompiles.add('$flags ${p.basename(source)}');
      final out = args[args.indexOf('-o') + 1];
      // Encode the flags in the bytes so different backend sets differ.
      File(out).writeAsBytesSync(flags.codeUnits);
      return (exitCode: 0, stdout: '', stderr: '');
    }
    // resgen: -c -p <prefix> -x <dir>/ <filamat>
    final prefix = args[args.indexOf('-p') + 1];
    final outDir = args[args.indexOf('-x') + 1].replaceAll(RegExp(r'[/\\]$'), '');
    final filamat = args.last;
    if (failResgenFor?.contains(p.basename(filamat)) ?? false) {
      return (exitCode: 2, stdout: '', stderr: 'resgen: fake failure for ${p.basename(filamat)}');
    }
    resgenRuns.add('$prefix ${p.basename(filamat)}');
    final upper = prefix.toUpperCase();
    File(
      p.join(outDir, '$prefix.c'),
    ).writeAsStringSync('#include <stdint.h>\nconst uint8_t ${upper}_PACKAGE[] = { 0x00 };\n');
    File(p.join(outDir, '$prefix.h')).writeAsStringSync(
      '#ifndef ${upper}_H_\n#define ${upper}_H_\n#include <stdint.h>\n'
      'extern const uint8_t ${upper}_PACKAGE[];\n#endif\n',
    );
    File(p.join(outDir, '$prefix.S')).writeAsStringSync('// $prefix\n');
    File(p.join(outDir, '$prefix.bin')).writeAsBytesSync([0x00]);
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

List<int> utf8Bytes(String s) => utf8.encode(s);

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
    final dir = Directory(p.join(tempDir.path, '${label}_${dirCounter++}_${DateTime.now().microsecondsSinceEpoch}'));
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
      expect(
        defaultMaterialToolsCacheRoot({'XDG_CACHE_HOME': '/xdg', 'HOME': '/home/u'}),
        p.join('/xdg', 'thermion', 'filament-tools'),
      );
      expect(
        defaultMaterialToolsCacheRoot({'HOME': '/home/u'}),
        p.join('/home/u', '.cache', 'thermion', 'filament-tools'),
      );
    });

    test('returns null when neither is set', () {
      expect(defaultMaterialToolsCacheRoot({}), isNull);
      expect(defaultMaterialToolsCacheRoot({'XDG_CACHE_HOME': '', 'HOME': ''}), isNull);
    });
  });

  group('parseMaterialCompilationConfig', () {
    test('absent define means the feature is off', () {
      expect(parseMaterialCompilationConfig(null), isNull);
    });

    test('defaults: all backends, resgen off', () {
      final warnings = <String>[];
      final config = parseMaterialCompilationConfig({
        'inputs': ['materials/skin.mat'],
        'output': 'build/materials',
      }, onLog: warnings.add)!;
      expect(config.inputs, ['materials/skin.mat']);
      expect(config.output, 'build/materials');
      expect(config.backends, allMaterialBackends);
      expect(config.isAllBackends, isTrue);
      expect(config.resgen, isFalse);
      expect(config.resgenPrefixes, isEmpty);
      expect(warnings, isEmpty);
    });

    test('backends presets and explicit lists', () {
      String backendsFor(Object? raw) => parseMaterialCompilationConfig({
        'inputs': ['a.mat'],
        'output': 'o',
        'backends': raw,
      })!.backends.join(',');

      expect(backendsFor(null), 'metal,vulkan,opengl,webgpu');
      expect(backendsFor('all'), 'metal,vulkan,opengl,webgpu');
      expect(backendsFor('native'), 'metal,vulkan,opengl');
      expect(backendsFor('web'), 'opengl,webgpu');
      expect(backendsFor(['vulkan', 'OpenGL']), 'vulkan,opengl');
      expect(backendsFor(['vulkan', 'vulkan']), 'vulkan');
    });

    test('resgen flag and prefix overrides parse', () {
      final config = parseMaterialCompilationConfig({
        'inputs': ['materials/skin.mat'],
        'output': 'build/materials',
        'resgen': true,
        'resgen_prefixes': {'skin': 'MY_SKIN'},
      })!;
      expect(config.resgen, isTrue);
      expect(config.resgenPrefixes, {'skin': 'MY_SKIN'});
    });

    test('unknown keys warn, everything else fails loudly', () {
      final warnings = <String>[];
      parseMaterialCompilationConfig({
        'inputs': ['a.mat'],
        'output': 'o',
        'typo_key': 1,
      }, onLog: warnings.add);
      expect(warnings.single, contains('typo_key'));

      MaterialToolsError errorMessage(Object? raw) =>
          (throwingOf(() => parseMaterialCompilationConfig(raw)) as MaterialToolsError);

      expect(errorMessage('nope').message, contains('material_compilation must be a map'));
      expect(errorMessage({'output': 'o'}).message, contains('inputs must be a non-empty list'));
      expect(errorMessage({'inputs': [], 'output': 'o'}).message, contains('inputs must be a non-empty list'));
      expect(
        errorMessage({
          'inputs': ['a.mat'],
        }).message,
        contains('output must be a non-empty'),
      );
      expect(
        errorMessage({
          'inputs': ['a.mat'],
          'output': 'o',
          'resgen': 'yes',
        }).message,
        contains('resgen must be true or false'),
      );
      expect(
        errorMessage({
          'inputs': ['a.mat'],
          'output': 'o',
          'backends': 'd3d',
        }).message,
        contains("Unknown backends preset 'd3d'"),
      );
      expect(
        errorMessage({
          'inputs': ['a.mat'],
          'output': 'o',
          'backends': ['dx12'],
        }).message,
        contains("Unknown backend 'dx12'"),
      );
      expect(
        errorMessage({
          'inputs': ['a.mat'],
          'output': 'o',
          'backends': [],
        }).message,
        contains('empty list'),
      );
      expect(
        errorMessage({
          'inputs': [1],
          'output': 'o',
        }).message,
        contains('non-empty strings'),
      );
    });
  });

  group('expandMaterialInputs', () {
    late Directory appRoot;

    setUp(() {
      appRoot = freshDir('app');
      Directory(p.join(appRoot.path, 'materials', 'eye')).createSync(recursive: true);
      File(p.join(appRoot.path, 'materials', 'skin.mat')).writeAsStringSync('material {}');
      File(p.join(appRoot.path, 'materials', 'eye', 'iris.mat')).writeAsStringSync('material {}');
      File(p.join(appRoot.path, 'materials', 'eye', 'note.txt')).writeAsStringSync('not a material');
      File(p.join(appRoot.path, 'materials', 'skin.filamat')).writeAsBytesSync([1]);
    });

    List<String> expand(List<String> inputs) => expandMaterialInputs(
      appRoot: appRoot,
      inputs: inputs,
    ).map((f) => p.relative(f.path, from: appRoot.path)).toList();

    test('file inputs', () {
      expect(expand(['materials/skin.mat']), ['materials/skin.mat']);
    });

    test('directory inputs recurse and keep only .mat files, sorted', () {
      expect(expand(['materials']), ['materials/eye/iris.mat', 'materials/skin.mat']);
    });

    test('glob inputs match .mat files only', () {
      expect(expand(['materials/*.mat']), ['materials/skin.mat']);
      expect(expand(['materials/**/*.mat']), ['materials/eye/iris.mat', 'materials/skin.mat']);
    });

    test('duplicate inputs are deduplicated', () {
      expect(expand(['materials/skin.mat', 'materials', 'materials/*.mat']), [
        'materials/eye/iris.mat',
        'materials/skin.mat',
      ]);
    });

    test('missing inputs and non-.mat files fail with the input named', () {
      expect(
        () => expand(['materials/nope.mat']),
        throwsA(isA<MaterialToolsError>().having((e) => e.message, 'message', contains('materials/nope.mat'))),
      );
      expect(
        () => expand(['materials/skin.filamat']),
        throwsA(isA<MaterialToolsError>().having((e) => e.message, 'message', contains('not a .mat file'))),
      );
      expect(
        () => expand(['materials/*.glb']),
        throwsA(isA<MaterialToolsError>().having((e) => e.message, 'message', contains('no .mat files'))),
      );
    });
  });

  group('output stems', () {
    test('sanitizes to C-safe identifiers', () {
      expect(materialOutputStem(File('/app/my-skin.mat')), 'my_skin');
      expect(materialOutputStem(File('/app/Skin 2.mat')), 'Skin_2');
    });

    test('rejects collisions between distinct inputs', () {
      expect(
        () => checkOutputStems([File('/app/a/skin.mat'), File('/app/b/skin.mat')]),
        throwsA(isA<MaterialToolsError>().having((e) => e.message, 'message', contains('skin'))),
      );
      // The same file twice (dedup happens on path upstream) is fine.
      expect(checkOutputStems([File('/app/a/skin.mat'), File('/app/a/skin.mat')]).values.toSet(), {'skin'});
    });
  });

  group('matcId', () {
    test('is stable and changes with every identity component', () {
      String id({
        String filament = 'v1.77.2',
        String pkg = '0.6.0-pre.0',
        String host = 'linux',
        String arch = 'x64',
      }) => computeMatcId(filamentVersion: filament, packageVersion: pkg, hostPlatform: host, hostArch: arch);

      final base = id();
      expect(id(), base);
      expect(id(filament: 'v1.78.0'), isNot(base));
      expect(id(pkg: '0.7.0'), isNot(base));
      expect(id(host: 'macos'), isNot(base));
      expect(id(arch: 'arm64'), isNot(base));
    });
  });

  group('manifest roundtrip', () {
    test('encode/read roundtrip; missing, corrupt and stale schema are misses', () {
      final file = File(p.join(tempDir.path, 'm', materialManifestName));
      expect(readMaterialsManifest(file), isNull);

      file.parent.createSync(recursive: true);
      file.writeAsStringSync('{not json');
      expect(readMaterialsManifest(file), isNull);

      file.writeAsStringSync(
        encodeMaterialsManifest(
          matcId: 'abc',
          matcSha256: 'def',
          backends: ['metal', 'vulkan'],
          resgen: true,
          inputs: {'a.mat': 'h1'},
          outputs: {
            'a.mat': ['a.filamat', 'a.c', 'a.h'],
          },
        ),
      );
      final manifest = readMaterialsManifest(file)!;
      expect(manifest.matcId, 'abc');
      expect(manifest.matcSha256, 'def');
      expect(manifest.backends, ['metal', 'vulkan']);
      expect(manifest.resgen, isTrue);
      expect(manifest.inputs, {'a.mat': 'h1'});
      expect(manifest.outputs['a.mat'], ['a.filamat', 'a.c', 'a.h']);

      // A schema from another pipeline version is a miss, not an error.
      final decoded = (jsonDecode(file.readAsStringSync()) as Map<String, dynamic>)..['schema'] = 99;
      file.writeAsStringSync(jsonEncode(decoded));
      expect(readMaterialsManifest(file), isNull);
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

      final result = await ensureMaterialTools(
        spec: spec,
        cacheRoot: cacheRoot,
        download: tools.downloader(),
        runProcess: tools.run,
      );
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
        throwsA(isA<MaterialToolsError>().having((e) => e.message, 'message', contains(spec.url))),
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

    test('no network and no cache fails with the URL and version named', () async {
      final spec = resolveMaterialToolsSpec(version: 'v1.77.2', hostOS: 'linux', hostArch: 'x64');
      final cacheRoot = Directory(p.join(tempDir.path, 'cache_offline'));

      await expectLater(
        ensureMaterialTools(
          spec: spec,
          cacheRoot: cacheRoot,
          download: (url, destination) async {
            throw Exception('SocketException: offline');
          },
          runProcess: FakeTools().run,
        ),
        throwsA(
          isA<MaterialToolsError>()
              .having((e) => e.message, 'message', contains(spec.url))
              .having((e) => e.message, 'message', contains('offline'))
              .having((e) => e.message, 'message', contains(spec.zipName)),
        ),
      );
    });
  });

  group('planMaterialCompilation', () {
    late Directory appRoot;
    late Directory outputDir;
    late File skin;
    late File eye;

    setUp(() {
      appRoot = freshDir('plan_app');
      outputDir = Directory(p.join(appRoot.path, 'build', 'materials'));
      skin = File(p.join(appRoot.path, 'materials', 'skin.mat'))..createSync(recursive: true);
      skin.writeAsStringSync('material { name : skin }');
      eye = File(p.join(appRoot.path, 'materials', 'eye', 'iris.mat'))..createSync(recursive: true);
      eye.writeAsStringSync('material { name : iris }');
    });

    String contentId(File file) => sha256.convert(file.readAsBytesSync()).toString();

    Map<File, String> hashesFor(List<File> inputs) => {for (final input in inputs) input: contentId(input)};

    MaterialCompilePlan planFor({
      required List<File> inputs,
      String? matcId,
      List<String> backends = allMaterialBackends,
      bool resgen = false,
    }) {
      return planMaterialCompilation(
        appRoot: appRoot,
        inputs: inputs,
        inputHashes: hashesFor(inputs),
        outputDir: outputDir,
        matcId: matcId ?? 'id-1',
        backends: backends,
        resgen: resgen,
      );
    }

    test('no manifest compiles everything', () {
      final plan = planFor(inputs: [skin, eye]);
      expect(plan.toCompile, [skin, eye]);
      expect(plan.reason, contains('no manifest'));
    });

    test('matching manifest skips everything', () {
      outputDir.createSync(recursive: true);
      File(p.join(outputDir.path, materialManifestName)).writeAsStringSync(
        encodeMaterialsManifest(
          outputHashes: {
            'skin.filamat': sha256Content([1]),
            'iris.filamat': sha256Content([1]),
          },
          matcId: 'id-1',
          matcSha256: null,
          backends: allMaterialBackends,
          resgen: false,
          inputs: {'materials/skin.mat': contentId(skin), 'materials/eye/iris.mat': contentId(eye)},
          outputs: {
            'materials/skin.mat': ['skin.filamat'],
            'materials/eye/iris.mat': ['iris.filamat'],
          },
        ),
      );
      File(p.join(outputDir.path, 'skin.filamat')).writeAsBytesSync([1]);
      File(p.join(outputDir.path, 'iris.filamat')).writeAsBytesSync([1]);

      final plan = planFor(inputs: [skin, eye]);
      expect(plan.toCompile, isEmpty);
      expect(plan.skipped.keys, containsAll([skin, eye]));
    });

    test('a changed, added or missing-output input recompiles just that input', () {
      outputDir.createSync(recursive: true);
      File(p.join(outputDir.path, materialManifestName)).writeAsStringSync(
        encodeMaterialsManifest(
          outputHashes: {
            'skin.filamat': sha256Content([1]),
            'iris.filamat': sha256Content([1]),
          },
          matcId: 'id-1',
          matcSha256: null,
          backends: allMaterialBackends,
          resgen: false,
          inputs: {'materials/skin.mat': contentId(skin)},
          outputs: {
            'materials/skin.mat': ['skin.filamat'],
          },
        ),
      );

      // Same hash, but the output file is missing -> recompile.
      expect(planFor(inputs: [skin]).toCompile, [skin]);

      File(p.join(outputDir.path, 'skin.filamat')).writeAsBytesSync([1]);
      // Up to date -> skip; new input -> compile.
      final plan = planFor(inputs: [skin, eye]);
      expect(plan.toCompile, [eye]);
      expect(plan.skipped.keys, [skin]);

      // Changed hash -> recompile.
      skin.writeAsStringSync('material { name : skin, changed }');
      expect(planFor(inputs: [skin, eye]).toCompile, containsAll([skin, eye]));
    });

    test('a matcId change recompiles EVERYTHING even with unchanged .mat files', () {
      outputDir.createSync(recursive: true);
      File(p.join(outputDir.path, materialManifestName)).writeAsStringSync(
        encodeMaterialsManifest(
          matcId: 'id-1',
          matcSha256: null,
          backends: allMaterialBackends,
          resgen: false,
          inputs: {'materials/skin.mat': contentId(skin), 'materials/eye/iris.mat': contentId(eye)},
          outputs: const {},
        ),
      );
      File(p.join(outputDir.path, 'skin.filamat')).writeAsBytesSync([1]);
      File(p.join(outputDir.path, 'iris.filamat')).writeAsBytesSync([1]);

      final plan = planFor(inputs: [skin, eye], matcId: 'id-2-filament-bump');
      expect(plan.toCompile, [skin, eye]); // nothing changed on disk
      expect(plan.reason, contains('matcId changed'));
    });

    test('backends/resgen changes recompile everything; removed inputs are stale', () {
      outputDir.createSync(recursive: true);
      File(p.join(outputDir.path, materialManifestName)).writeAsStringSync(
        encodeMaterialsManifest(
          matcId: 'id-1',
          matcSha256: null,
          backends: ['opengl'],
          resgen: false,
          inputs: {'materials/skin.mat': contentId(skin), 'materials/eye/iris.mat': contentId(eye)},
          outputs: {
            'materials/skin.mat': ['skin.filamat'],
            'materials/eye/iris.mat': ['iris.filamat'],
          },
        ),
      );

      // backends differ (manifest says opengl-only, config now wants all)
      // -> full rebuild; eye removed from the config -> stale.
      var plan = planFor(inputs: [skin]);
      expect(plan.toCompile, [skin]);
      expect(plan.reason, contains('backends changed'));
      expect(plan.staleOutputs, ['iris.filamat']);

      // resgen differs -> full rebuild.
      plan = planFor(inputs: [skin, eye], backends: ['opengl'], resgen: true);
      expect(plan.toCompile, [skin, eye]);
      expect(plan.reason, contains('resgen changed'));
    });
  });

  group('compileUserMaterials', () {
    late Directory appRoot;
    late Directory toolsCache;

    setUp(() {
      appRoot = freshDir('app');
      toolsCache = freshDir('tools_cache');
      Directory(p.join(appRoot.path, 'materials')).createSync(recursive: true);
      File(p.join(appRoot.path, 'materials', 'skin.mat')).writeAsStringSync('material { name : skin }');
      File(p.join(appRoot.path, 'materials', 'my-eye.mat')).writeAsStringSync('material { name : eye }');
    });

    Future<UserMaterialsResult> run({
      required FakeTools tools,
      Object? rawConfig,
      String filamentVersion = 'v1.77.2',
      String packageVersion = '0.6.0-pre.0',
    }) {
      final config = parseMaterialCompilationConfig(
        rawConfig ??
            {
              'inputs': ['materials'],
              'output': 'build/materials',
            },
      )!;
      return compileUserMaterials(
        appRoot: appRoot,
        config: config,
        filamentVersion: filamentVersion,
        packageVersion: packageVersion,
        hostOS: 'linux',
        hostArch: 'x64',
        toolsCacheRoot: toolsCache.path,
        download: tools.downloader(),
        runProcess: tools.run,
      );
    }

    Directory outputDir() => Directory(p.join(appRoot.path, 'build', 'materials'));

    test('first run downloads tools once and emits one blended package per material', () async {
      final tools = FakeTools();
      final result = await run(tools: tools);

      expect(result.compiled, 2);
      expect(result.skipped, 0);
      expect(result.toolsDownloaded, isTrue);
      expect(tools.downloadCount, 1);

      // Blended: ONE matc invocation per material carrying every backend.
      expect(
        tools.matcCompiles,
        unorderedEquals([
          '-a metal -a vulkan -a opengl -a webgpu skin.mat',
          '-a metal -a vulkan -a opengl -a webgpu my-eye.mat',
        ]),
      );

      // One stable .filamat per material, sanitised stem, no variants.
      expect(File(p.join(outputDir().path, 'skin.filamat')).existsSync(), isTrue);
      expect(File(p.join(outputDir().path, 'my_eye.filamat')).existsSync(), isTrue);
      expect(outputDir().listSync().whereType<File>().map((f) => p.basename(f.path)).toSet(), {
        materialManifestName,
        '.thermion-materials.lock',
        'skin.filamat',
        'my_eye.filamat',
      });

      // The manifest gate was written last with the recorded identity.
      final manifest = readMaterialsManifest(File(p.join(outputDir().path, materialManifestName)))!;
      expect(manifest.matcId, isNotEmpty);
      expect(manifest.matcSha256, sha256Content(workingMatcContent.codeUnits));
      expect(manifest.inputs.keys, {'materials/skin.mat', 'materials/my-eye.mat'});
      expect(manifest.backends, allMaterialBackends);
    });

    test('second run is a no-op: no download, no matc run', () async {
      final tools = FakeTools();
      await run(tools: tools);
      final matcRunsAfterFirst = tools.matcCompiles.length;

      final result = await run(tools: tools);
      expect(result.compiled, 0);
      expect(result.skipped, 2);
      expect(result.toolsDownloaded, isFalse);
      expect(tools.downloadCount, 1);
      expect(tools.matcCompiles.length, matcRunsAfterFirst);
    });

    test('an edited .mat recompiles only that material', () async {
      final tools = FakeTools();
      await run(tools: tools);
      File(p.join(appRoot.path, 'materials', 'skin.mat')).writeAsStringSync('material { name : skin, edited }');

      final result = await run(tools: tools);
      expect(result.compiled, 1);
      expect(result.skipped, 1);
      expect(tools.matcCompiles.last, endsWith(' skin.mat'));
    });

    test('a Filament version bump (new matcId) recompiles everything, unchanged .mat or not', () async {
      final tools = FakeTools();
      await run(tools: tools);
      final matcRunsAfterFirst = tools.matcCompiles.length;

      final result = await run(tools: tools, filamentVersion: 'v1.78.0');
      expect(result.compiled, 2);
      expect(result.skipped, 0);
      expect(tools.matcCompiles.length, matcRunsAfterFirst + 2);
      // A different package version has the same effect.
      final result2 = await run(tools: tools, packageVersion: '0.7.0');
      expect(result2.compiled, 2);
    });

    test('a replaced matc binary in the cache recompiles everything', () async {
      final tools = FakeTools();
      await run(tools: tools);
      final matcRunsAfterFirst = tools.matcCompiles.length;

      // Same version + same content -> no change.
      expect((await run(tools: tools)).compiled, 0);

      // Re-uploaded artifact for the same version: different bytes.
      final matcFile = File(
        p.join(
          toolsCache.path,
          resolveMaterialToolsSpec(version: 'v1.77.2', hostOS: 'linux', hostArch: 'x64').cacheDirName,
          'bin',
          'matc',
        ),
      );
      matcFile.writeAsStringSync('works-but-rebuilt');
      final result = await run(tools: tools);
      expect(result.compiled, 2);
      expect(tools.matcCompiles.length, matcRunsAfterFirst + 2);
    });

    test('narrowing backends recompiles with the requested flags only', () async {
      final tools = FakeTools();
      await run(tools: tools);

      final result = await run(
        tools: tools,
        rawConfig: {
          'inputs': ['materials'],
          'output': 'build/materials',
          'backends': 'web',
        },
      );
      expect(result.compiled, 2);
      final thisRun = tools.matcCompiles.sublist(tools.matcCompiles.length - 2);
      expect(thisRun, everyElement(startsWith('-a opengl -a webgpu ')));
    });

    test('resgen: true emits one .c/.h per material with a sanitized prefix, overridable', () async {
      final tools = FakeTools();
      final result = await run(
        tools: tools,
        rawConfig: {
          'inputs': ['materials'],
          'output': 'build/materials',
          'resgen': true,
          'resgen_prefixes': {'skin': 'APP_SKIN'},
        },
      );
      expect(result.compiled, 2);

      expect(File(p.join(outputDir().path, 'APP_SKIN.c')).readAsStringSync(), contains('APP_SKIN_PACKAGE'));
      expect(File(p.join(outputDir().path, 'APP_SKIN.h')).readAsStringSync(), contains('APP_SKIN_PACKAGE'));
      // my-eye.mat -> my_eye prefix; no rename/sed pipeline, no variants.
      expect(File(p.join(outputDir().path, 'my_eye.c')).readAsStringSync(), contains('MY_EYE_PACKAGE'));
      expect(File(p.join(outputDir().path, 'my_eye.h')).readAsStringSync(), contains('MY_EYE_PACKAGE'));
      // One .c per material: blended package means no per-variant collisions.
      expect(outputDir().listSync().whereType<File>().where((f) => f.path.endsWith('.c')).length, 2);
      expect(tools.resgenRuns, unorderedEquals(['APP_SKIN skin.filamat', 'my_eye my_eye.filamat']));
    });

    test('an input removed from the config drops its outputs without downloading tools', () async {
      final tools = FakeTools();
      await run(
        tools: tools,
        rawConfig: {
          'inputs': ['materials'],
          'output': 'build/materials',
          'resgen': true,
        },
      );
      expect(File(p.join(outputDir().path, 'my_eye.filamat')).existsSync(), isTrue);
      final downloads = tools.downloadCount;

      final result = await run(
        tools: tools,
        rawConfig: {
          'inputs': ['materials/skin.mat'],
          'output': 'build/materials',
          'resgen': true,
        },
      );
      expect(result.compiled, 0);
      expect(tools.downloadCount, downloads); // no tools needed for cleanup
      expect(File(p.join(outputDir().path, 'my_eye.filamat')).existsSync(), isFalse);
      expect(File(p.join(outputDir().path, 'my_eye.c')).existsSync(), isFalse);
      expect(File(p.join(outputDir().path, 'my_eye.h')).existsSync(), isFalse);
      // Still listed? No: the manifest only knows the remaining inputs.
      expect(readMaterialsManifest(File(p.join(outputDir().path, materialManifestName)))!.inputs.keys, [
        'materials/skin.mat',
      ]);
    });

    test('matc failure surfaces stderr and leaves outputs and manifest untouched', () async {
      final tools = FakeTools();
      await run(tools: tools);
      final manifestBefore = File(p.join(outputDir().path, materialManifestName)).readAsStringSync();
      final skinBefore = File(p.join(outputDir().path, 'skin.filamat')).readAsBytesSync();
      final matcRunsBefore = tools.matcCompiles.length;

      File(p.join(appRoot.path, 'materials', 'skin.mat')).writeAsStringSync('material { name : skin, broken }');
      final failing = FakeTools(failMatcFor: {'skin.mat'});
      await expectLater(
        run(tools: failing),
        throwsA(isA<MaterialGenerationError>().having((e) => e.message, 'message', contains('fake compile error'))),
      );

      // Old outputs intact, manifest not rewritten, no staging leftovers.
      expect(File(p.join(outputDir().path, 'skin.filamat')).readAsBytesSync(), skinBefore);
      expect(File(p.join(outputDir().path, materialManifestName)).readAsStringSync(), manifestBefore);
      expect(
        outputDir().listSync().whereType<Directory>().where((d) => p.basename(d.path).startsWith('.staging-')).toList(),
        isEmpty,
      );
      expect(outputDir().listSync().whereType<File>().where((f) => f.path.endsWith('.tmp')).toList(), isEmpty);
      // The tools were reused from cache: no extra download.
      expect(tools.downloadCount, 1);
      expect(tools.matcCompiles.length, matcRunsBefore);
    });

    test('resgen failure surfaces stderr too', () async {
      final tools = FakeTools(failResgenFor: {'skin.filamat'});
      await expectLater(
        run(
          tools: tools,
          rawConfig: {
            'inputs': ['materials'],
            'output': 'build/materials',
            'resgen': true,
          },
        ),
        throwsA(isA<MaterialGenerationError>().having((e) => e.message, 'message', contains('fake failure'))),
      );
      // Nothing was published: only staging was used and cleaned up.
      expect(File(p.join(outputDir().path, materialManifestName)).existsSync(), isFalse);
    });

    test('no network and no cached tools fails naming the URL and version', () async {
      final offline = FakeTools();
      await expectLater(
        compileUserMaterials(
          appRoot: appRoot,
          config: parseMaterialCompilationConfig({
            'inputs': ['materials'],
            'output': 'build/materials',
          })!,
          filamentVersion: 'v1.77.2',
          packageVersion: '0.6.0-pre.0',
          hostOS: 'linux',
          hostArch: 'x64',
          toolsCacheRoot: toolsCache.path,
          download: (url, destination) async {
            throw Exception('SocketException: offline');
          },
          runProcess: offline.run,
        ),
        throwsA(
          isA<MaterialToolsError>()
              .having(
                (e) => e.message,
                'message',
                contains('$materialToolsR2BaseUrl/filament-v1.77.2-linux-release.zip'),
              )
              .having((e) => e.message, 'message', contains('filament-v1.77.2-linux-release.zip')),
        ),
      );
      // Lock metadata may exist, but no material or manifest was published.
      expect(File(p.join(outputDir().path, materialManifestName)).existsSync(), isFalse);
      expect(outputDir().listSync().whereType<File>().map((f) => p.basename(f.path)), ['.thermion-materials.lock']);
    });

    test('the output directory is created when missing, also outside the app root', () async {
      final tools = FakeTools();
      final outside = freshDir('outside');
      final result = await compileUserMaterials(
        appRoot: appRoot,
        config: parseMaterialCompilationConfig({
          'inputs': ['materials/skin.mat'],
          'output': p.join(outside.path, 'nested', 'out'),
        })!,
        filamentVersion: 'v1.77.2',
        packageVersion: '0.6.0-pre.0',
        hostOS: 'linux',
        hostArch: 'x64',
        toolsCacheRoot: toolsCache.path,
        download: tools.downloader(),
        runProcess: tools.run,
      );
      expect(result.compiled, 1);
      expect(File(p.join(outside.path, 'nested', 'out', 'skin.filamat')).existsSync(), isTrue);
    });
  });
}

Object throwingOf(void Function() f) {
  try {
    f();
  } catch (e) {
    return e;
  }
  throw StateError('did not throw');
}

String sha256Content(List<int> bytes) => sha256.convert(bytes).toString();

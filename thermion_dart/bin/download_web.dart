import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:thermion_dart/src/filament/src/interface/built_in_material.dart';
import 'package:thermion_dart/src/hooks/built_in_materials.dart';
import 'package:thermion_dart/src/hooks/web_artifacts.dart';

/// CLI variant selectors → the artifact zip suffix used on R2 (mirrors
/// lib/src/hooks/web_artifacts.dart).
const _variants = {
  'default': '',
  'worker': '',
  'main_thread': '-main-thread',
  'runtime-materials': '-runtime-materials',
  'main-thread-runtime-materials': '-main-thread-runtime-materials',
};

Future<String> _getPackageRoot() async {
  final resolved = await Isolate.resolvePackageUri(Uri.parse('package:thermion_dart/'));
  if (resolved == null) {
    stderr.writeln('Could not resolve package:thermion_dart');
    exit(1);
  }
  return path.dirname(path.normalize(resolved.toFilePath().replaceAll(RegExp(r'[\\/]$'), '')));
}

Future<String> _getWebVersion(String packageRoot) async {
  final versionPath = path.join(packageRoot, 'native', 'web', 'web.version');
  final versionFile = File(versionPath);
  if (!versionFile.existsSync()) {
    stderr.writeln('Could not find web.version at $versionPath');
    stderr.writeln(
      'Ensure you are on a branch where web artifacts have been '
      'built by CI.',
    );
    exit(1);
  }
  return versionFile.readAsStringSync().trim();
}

Future<Directory> _downloadToCache(String version, String zipSuffix, Directory cacheDir) async {
  final successToken = File(path.join(cacheDir.path, 'success'));
  if (successToken.existsSync()) {
    stdout.writeln('Web artifacts already cached at ${cacheDir.path}');
    return cacheDir;
  }

  final zipName = webArtifactZipName(version, zipSuffix);
  final url = webArtifactUrl(version, zipSuffix);
  final zipFile = File(path.join(cacheDir.path, zipName));

  if (!cacheDir.existsSync()) {
    cacheDir.createSync(recursive: true);
  }

  stdout.writeln('Downloading $url ...');
  final request = await HttpClient().getUrl(Uri.parse(url));
  final response = await request.close();

  if (response.statusCode != 200) {
    stderr.writeln('Failed to download: HTTP ${response.statusCode}');
    stderr.writeln('URL: $url');
    exit(1);
  }

  await response.pipe(zipFile.openWrite());

  final bytes = await zipFile.readAsBytes();
  stdout.writeln('Downloaded ${bytes.length} bytes (md5: ${md5.convert(bytes)})');

  final archive = ZipDecoder().decodeBytes(bytes);
  for (final file in archive) {
    final filePath = path.join(cacheDir.path, file.name);
    if (file.isFile) {
      final f = File(filePath);
      await f.create(recursive: true);
      await f.writeAsBytes(file.content as List<int>);
    } else {
      await Directory(filePath).create(recursive: true);
    }
  }

  successToken.writeAsStringSync('SUCCESS');
  stdout.writeln('Extracted web artifacts to ${cacheDir.path}');
  return cacheDir;
}

List<BuiltInMaterial> _parseMaterials(String raw) {
  // unlit_fallback is hook-managed (native features.gltf: false builds only),
  // never a user-selectable helper key.
  final byKey = {
    for (final m in BuiltInMaterial.values)
      if (m != BuiltInMaterial.unlitFallback) m.key: m,
  };
  final selected = <BuiltInMaterial>{};
  for (final token in raw.split(',')) {
    final key = token.trim();
    if (key.isEmpty) continue;
    final material = byKey[key];
    if (material == null) {
      stderr.writeln("Unknown material '$key'. Valid keys: ${byKey.keys.join(', ')}");
      exit(1);
    }
    selected.add(material);
  }
  return selected.toList();
}

void main(List<String> args) async {
  String outputDir = 'web';
  String variant = 'default';
  String backend = defaultWebBackend;
  String? materialsArg;

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '-o' || args[i] == '--output') {
      if (i + 1 < args.length) {
        outputDir = args[++i];
      }
    } else if (args[i] == '--variant') {
      if (i + 1 < args.length) {
        variant = args[++i];
      }
    } else if (args[i] == '--backend') {
      if (i + 1 >= args.length || !const ['webgl2', 'webgpu', 'hybrid'].contains(args[i + 1])) {
        stderr.writeln('--backend requires webgl2, webgpu or hybrid.');
        exit(64);
      }
      backend = args[++i];
    } else if (args[i] == '--materials') {
      if (i + 1 >= args.length) {
        stderr.writeln('--materials requires a material list.');
        exit(64);
      }
      materialsArg = args[++i];
    } else if (args[i] == '-h' || args[i] == '--help') {
      stdout.writeln(
        'Usage: dart run thermion_dart:download_web [-o <dir>] [--variant <name>] [--backend <name>] [--materials <list>]',
      );
      stdout.writeln('  -o, --output   Output directory (default: web/)');
      stdout.writeln('  --variant      Engine variant: ${_variants.keys.join(', ')} (default: default)');
      stdout.writeln('                runtime-materials = filamat-enabled engine for');
      stdout.writeln('                runtime material compilation (~20 MB larger).');
      stdout.writeln('                main-thread-runtime-materials = both combined.');
      stdout.writeln('  --backend NAME  Browser engine and optional built-in material formats');
      stdout.writeln('                  webgl2 (default)  WebGL2 engine with GLSL');
      stdout.writeln('                  webgpu            WebGPU-capable engine with WGSL');
      stdout.writeln('                  hybrid            WebGPU-capable engine with GLSL and WGSL');
      stdout.writeln('                  WebGPU and hybrid use the main-thread engine with precompiled materials.');
      stdout.writeln('  --materials    Comma-separated helper keys, for example gizmo,image.');
      stdout.writeln(
        '                 Available keys: '
        '${BuiltInMaterial.values.where((m) => m != BuiltInMaterial.unlitFallback).map((m) => m.key).join(', ')}',
      );
      return;
    }
  }

  final variantSuffix = _variants[variant];
  if (variantSuffix == null) {
    stderr.writeln("Unknown variant '$variant'. Valid: ${_variants.keys.join(', ')}");
    exit(1);
  }
  final String zipSuffix;
  try {
    zipSuffix = withWebBackend((
      zipSuffix: variantSuffix,
      cacheSuffix: variantSuffix,
      warnings: const [],
    ), backend).zipSuffix;
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exit(64);
  }

  final materials = materialsArg == null ? const <BuiltInMaterial>[] : _parseMaterials(materialsArg);

  final packageRoot = await _getPackageRoot();
  final version = await _getWebVersion(packageRoot);
  stdout.writeln('Web artifact version: $version (variant: $variant)');

  outputDir = path.normalize(outputDir);

  // Cache under .dart_tool/thermion_dart/web/{version}{suffix}/ — variants
  // never share a directory (the success token would mask the wrong files).
  final cacheDir = Directory(path.join('.dart_tool', 'thermion_dart', 'web', '$version$zipSuffix'));

  await _downloadToCache(version, zipSuffix, cacheDir);
  await publishWebMaterials(
    root: Directory(packageRoot),
    engineDir: cacheDir,
    webDir: Directory(outputDir),
    materials: materials,
    backend: backend,
    onLog: stdout.writeln,
  );

  stdout.writeln('Done.');
}

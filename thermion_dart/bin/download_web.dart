import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

const _r2BaseUrl =
    'https://pub-c8b6266320924116aaddce03b5313c0a.r2.dev';

Future<String> _getWebVersion() async {
  // Resolve package:thermion_dart/ to its lib/ directory so we can locate
  // native/web/web.version regardless of how this script was invoked.
  final resolved =
      await Isolate.resolvePackageUri(Uri.parse('package:thermion_dart/'));
  if (resolved == null) {
    stderr.writeln('Could not resolve package:thermion_dart');
    exit(1);
  }
  final packageRoot = path.dirname(
      path.normalize(resolved.toFilePath().replaceAll(RegExp(r'[\\/]$'), '')));
  final versionPath =
      path.join(packageRoot, 'native', 'web', 'web.version');
  final versionFile = File(versionPath);
  if (!versionFile.existsSync()) {
    stderr.writeln('Could not find web.version at $versionPath');
    stderr.writeln(
        'Ensure you are on a branch where web artifacts have been '
        'built by CI.');
    exit(1);
  }
  return versionFile.readAsStringSync().trim();
}

Future<Directory> _downloadToCache(String version, Directory cacheDir) async {
  final successToken = File(path.join(cacheDir.path, 'success'));
  if (successToken.existsSync()) {
    stdout.writeln('Web artifacts already cached at ${cacheDir.path}');
    return cacheDir;
  }

  final zipName = 'thermion_dart-${version}-web.zip';
  final url = '$_r2BaseUrl/$zipName';
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
  stdout.writeln(
      'Downloaded ${bytes.length} bytes (md5: ${md5.convert(bytes)})');

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

void _copyToOutput(Directory cacheDir, String outputDir) {
  for (final name in ['thermion_dart.js', 'thermion_dart.wasm']) {
    final src = File(path.join(cacheDir.path, name));
    if (!src.existsSync()) {
      stderr.writeln('Warning: $name not found in cache');
      continue;
    }
    final destDir = Directory(outputDir);
    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }
    final dest = File(path.join(outputDir, name));
    src.copySync(dest.path);
    stdout.writeln('Copied $name to ${dest.path}');
  }
}

void main(List<String> args) async {
  String outputDir = 'web';

  for (var i = 0; i < args.length; i++) {
    if (args[i] == '-o' || args[i] == '--output') {
      if (i + 1 < args.length) {
        outputDir = args[++i];
      }
    } else if (args[i] == '-h' || args[i] == '--help') {
      stdout.writeln('Usage: dart run thermion_dart:download_web [-o <dir>]');
      stdout.writeln('  -o, --output  Output directory (default: web/)');
      return;
    }
  }

  final version = await _getWebVersion();
  stdout.writeln('Web artifact version: $version');

  outputDir = path.normalize(outputDir);

  // Cache under .dart_tool/thermion_dart/web/{version}/
  final cacheDir = Directory(path.join(
    '.dart_tool',
    'thermion_dart',
    'web',
    version,
  ));

  await _downloadToCache(version, cacheDir);
  _copyToOutput(cacheDir, outputDir);

  stdout.writeln('Done.');
}

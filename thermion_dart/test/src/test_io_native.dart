import 'dart:io';
import 'dart:typed_data';

import 'package:thermion_dart/thermion_dart.dart' show Backend;

export 'dart:typed_data';

/// Native FFI bindings are wired up by the dynamic library load; nothing to do.
Future<void> initTestBindings() async {}

/// Backend selection matches the original `helpers.setup()` logic.
Backend get defaultTestBackend => Platform.isLinux
    ? Backend.OPENGL
    : Platform.isWindows
        ? Backend.VULKAN
        : Backend.DEFAULT;

bool get platformIsWindows => Platform.isWindows;
bool get platformIsLinux => Platform.isLinux;
bool get isWeb => false;
String get currentDirPath => Directory.current.path;

Future<Uint8List> loadResourceBytes(String uri) async {
  uri = uri.replaceAll("file://", "");
  return File(uri).readAsBytesSync();
}

Uint8List readFileBytesSync(String path) => File(path).readAsBytesSync();

Future<void> writeFileBytes(String path, Uint8List bytes) async =>
    File(path).writeAsBytesSync(bytes);

void createDirSync(String path) => Directory(path).createSync(recursive: true);

/// Test files run from a variety of working directories; walk up from the
/// running script (or cwd, when run from a dill) to find the package root.
Uri findPackageRoot(String packageName) {
  String name(Uri uri) => uri.pathSegments.where((e) => e != '').last;

  final script = Platform.script;
  final fileName = name(script);
  if (fileName.contains('_test')) {
    var directory = script.resolve('.');
    while (true) {
      if (name(directory) == packageName) {
        return directory;
      }
      final parent = directory.resolve('..');
      if (parent == directory) break;
      directory = parent;
    }
  } else if (fileName.endsWith('.dill')) {
    final cwd = Directory.current.uri;
    if (name(cwd) == packageName) {
      return cwd;
    }
  }
  throw StateError("Could not find package root for package '$packageName'. "
      "Tried Platform.script '${Platform.script.toFilePath()}' and "
      "Directory.current '${Directory.current.uri.toFilePath()}'.");
}

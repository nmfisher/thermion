import 'dart:ffi';
import 'dart:io';
import 'package:dart_filament/dart_filament/swift/swift_bindings.g.dart';
import 'package:dart_filament/dart_filament/utils/dart_resources.dart';
import 'package:ffi/ffi.dart';
import 'package:dart_filament/dart_filament.dart';
import 'package:dart_filament/dart_filament/dart_filament.g.dart';

import 'package:test/test.dart';

/// Test files are run in a variety of ways, find this package root in all.
///
/// Test files can be run from source from any working directory. The Dart SDK
/// `tools/test.py` runs them from the root of the SDK for example.
///
/// Test files can be run from dill from the root of package. `package:test`
/// does this.
Uri findPackageRoot(String packageName) {
  final script = Platform.script;
  final fileName = script.name;
  if (fileName.endsWith('_test.dart')) {
    // We're likely running from source.
    var directory = script.resolve('.');
    while (true) {
      final dirName = directory.name;
      if (dirName == packageName) {
        return directory;
      }
      final parent = directory.resolve('..');
      if (parent == directory) break;
      directory = parent;
    }
  } else if (fileName.endsWith('.dill')) {
    final cwd = Directory.current.uri;
    final dirName = cwd.name;
    if (dirName == packageName) {
      return cwd;
    }
  }
  throw StateError("Could not find package root for package '$packageName'. "
      'Tried finding the package root via Platform.script '
      "'${Platform.script.toFilePath()}' and Directory.current "
      "'${Directory.current.uri.toFilePath()}'.");
}

extension on Uri {
  String get name => pathSegments.where((e) => e != '').last;
}

void main() async {
  final packageUri = findPackageRoot('dart_filament');
  var testDir = Directory("${packageUri.toFilePath()}/test").path;
  final lib = DartFilamentTexture1(DynamicLibrary.open(
      '${packageUri.toFilePath()}/native/lib/macos/swift/libdartfilamenttexture.dylib'));
  final object = DartFilamentTexture.new1(lib);
  object.initWithWidth_height_(500, 500);

  final resourceLoader = calloc<ResourceLoaderWrapper>(1);
  resourceLoader.ref.loadResource =
      Pointer.fromFunction(DartResourceLoader.loadResource);
  resourceLoader.ref.freeResource =
      Pointer.fromFunction(DartResourceLoader.freeResource);

  var viewer = FilamentViewer(resourceLoader: resourceLoader);

  await viewer.initialized;
  await viewer.createSwapChain(500, 500);
  await viewer.createRenderTarget(500, 500, object.metalTextureAddress);
  await viewer.updateViewportAndCameraProjection(500, 500);

  group('String', () {
    test('set background color', () async {
      var outDir = Directory("$testDir/bgcolor");
      outDir.createSync();
      await viewer.setRecordingOutputDirectory(outDir.path);
      await viewer.setBackgroundColor(0.0, 1.0, 0.0, 1.0);
      await viewer.setRecording(true);
      await viewer.render();
      await viewer.render();
      await viewer.render();
    });

    test('load skybox', () async {
      var outDir = Directory("$testDir/skybox");
      outDir.createSync();
      await viewer.setRecordingOutputDirectory(outDir.path);
      await viewer.setRecording(true);
      await viewer.loadSkybox(
          "file:///$testDir/../../flutter_filament/example/assets/default_env/default_env_skybox.ktx");
      await viewer.render();
    });
  });
}

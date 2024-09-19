import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'package:ffi/ffi.dart';
import 'package:thermion_dart/thermion_dart/swift/swift_bindings.g.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';

import 'package:thermion_dart/thermion_dart/utils/dart_resources.dart';

import 'package:test/test.dart';
import 'package:thermion_dart/thermion_dart/viewer/ffi/thermion_dart.g.dart';
import 'package:thermion_dart/thermion_dart/viewer/ffi/thermion_viewer_ffi.dart';

import 'package:vector_math/vector_math_64.dart';

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

  throw StateError("Could not find package root for package '$packageName'. "
      'Tried finding the package root via Platform.script '
      "'${Platform.script.toFilePath()}' and Directory.current "
      "'${Directory.current.uri.toFilePath()}'.");
}

extension on Uri {
  String get name => pathSegments.where((e) => e != '').last;
}

late String testDir;
void main() async {
  final packageUri = findPackageRoot('thermion_dart');
  testDir = Directory("${packageUri.toFilePath()}/test").path;
  final lib = ThermionDartTexture1(DynamicLibrary.open(
      '${packageUri.toFilePath()}/native/lib/macos/swift/libthermion_swift.dylib'));
  final object = ThermionDartTexture.new1(lib);
  object.initWithWidth_height_(500, 500);

  final resourceLoader = calloc<ResourceLoaderWrapper>(1);
  var loadToOut = NativeCallable<
      Void Function(Pointer<Char>,
          Pointer<ResourceBuffer>)>.listener(DartResourceLoader.loadResource);

  resourceLoader.ref.loadToOut = loadToOut.nativeFunction;
  var freeResource = NativeCallable<Void Function(ResourceBuffer)>.listener(
      DartResourceLoader.freeResource);
  resourceLoader.ref.freeResource = freeResource.nativeFunction;

  var viewer = ThermionViewerFFI(resourceLoader: resourceLoader.cast<Void>());

  await viewer.initialized;
  await viewer.createSwapChain(500, 500);
  await viewer.createRenderTarget(500, 500, object.metalTextureAddress);
  await viewer.updateViewportAndCameraProjection(500, 500);

 
}
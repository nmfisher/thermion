import 'dart:ffi';
import 'dart:io';
import 'package:thermion_dart/thermion_dart/swift/swift_bindings.g.dart';
import 'package:thermion_dart/thermion_dart/utils/dart_resources.dart';
import 'package:ffi/ffi.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/thermion_dart/compatibility/compatibility.dart';
import 'package:test/test.dart';
import 'package:animation_tools_dart/animation_tools_dart.dart';

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

late String testDir;
void main() async {
  final packageUri = findPackageRoot('thermion_dart');
  testDir = Directory("${packageUri.toFilePath()}/test").path;
  final lib = ThermionDartTexture1(DynamicLibrary.open(
      '${packageUri.toFilePath()}/native/lib/macos/swift/libdartfilamenttexture.dylib'));
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

  var viewer = FilamentViewer(resourceLoader: resourceLoader.cast<Void>());

  await viewer.initialized;
  await viewer.createSwapChain(500, 500);
  await viewer.createRenderTarget(500, 500, object.metalTextureAddress);
  await viewer.updateViewportAndCameraProjection(500, 500);

  group('background', () {
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
          "file:///$testDir/../../thermion_flutter/example/assets/default_env/default_env_skybox.ktx");
      await viewer.render();
      await viewer.render();
      await viewer.setRecording(false);
    });
  });

  group('Skinning & animations', () {
    test('get bone names', () async {
      var model = await viewer.loadGlb("$testDir/assets/shapes.glb");
      var names = await viewer.getBoneNames(model);
      expect(names.first, "Bone");
    });

    test('reset bones', () async {
      var model = await viewer.loadGlb("$testDir/assets/shapes.glb");
      await viewer.resetBones(model);
    });
    test('set from BVH', () async {
      var model = await viewer.loadGlb("$testDir/assets/shapes.glb");
      var animation = BVHParser.parse(
          File("$testDir/assets/animation.bvh").readAsStringSync(),
          boneRegex: RegExp(r"Bone$"));
      await viewer.addBoneAnimation(model, animation);
    });

    test('fade in/out', () async {
      var model = await viewer.loadGlb("$testDir/assets/shapes.glb");
      var animation = BVHParser.parse(
          File("$testDir/assets/animation.bvh").readAsStringSync(),
          boneRegex: RegExp(r"Bone$"));
      await viewer.addBoneAnimation(model, animation,
          fadeInInSecs: 0.5, fadeOutInSecs: 0.5);
      await Future.delayed(Duration(seconds: 1));
    });
  });
}

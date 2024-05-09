import 'dart:ffi';
import 'dart:io';
import 'package:dart_filament/dart_filament/swift/swift_bindings.g.dart';
import 'package:dart_filament/dart_filament/utils/dart_resources.dart';
import 'package:ffi/ffi.dart';
import 'package:dart_filament/dart_filament.dart';
import 'package:dart_filament/dart_filament/dart_filament.g.dart';

void main() async {
  var testDir = File(Platform.script.toFilePath()).parent.path;
  final lib = DartFilamentTexture1(DynamicLibrary.open(
      "$testDir/../../native/lib/macos/swift/libdartfilamenttexture.dylib"));
  final object = DartFilamentTexture.new1(lib);
  object.initWithWidth_height_(500, 500);

  final resourceLoader = calloc<ResourceLoaderWrapper>(1);
  var loadToOut = NativeCallable<
      Void Function(Pointer<Char>,
          Pointer<ResourceBuffer>)>.listener(DartResourceLoader.loadResource);

  resourceLoader.ref.loadToOut = loadToOut.nativeFunction;
  var freeResource = NativeCallable<Void Function(ResourceBuffer)>.listener(
      DartResourceLoader.freeResource);
  resourceLoader.ref.freeResource = freeResource.nativeFunction;

  var viewer = FilamentViewer(resourceLoader: resourceLoader);

  await viewer.initialized;
  await viewer.createSwapChain(500, 500);
  await viewer.createRenderTarget(500, 500, object.metalTextureAddress);
  await viewer.updateViewportAndCameraProjection(500, 500);

  var outDir = Directory("$testDir/skybox");
  outDir.deleteSync(recursive: true);
  outDir.createSync();

  await viewer.setRecordingOutputDirectory(outDir.path);
  await viewer.setRecording(true);
  await viewer.loadSkybox(
      "file:///$testDir/../../../flutter_filament/example/assets/default_env/default_env_skybox.ktx");
  await Future.delayed(Duration(milliseconds: 16));
  await viewer.render();
  await viewer.dispose();
}

import 'dart:io';
import 'package:thermion_dart/thermion_dart/compatibility/compatibility.dart';
import 'package:thermion_dart/thermion_dart/swift/swift_bindings.g.dart';
import 'package:thermion_dart/thermion_dart/compatibility/compatibility.dart';
import 'package:thermion_dart/thermion_dart/utils/dart_resources.dart';
import 'package:ffi/ffi.dart';
import 'package:thermion_dart/thermion_dart.dart';

void main() async {
  var scriptDir = File(Platform.script.toFilePath()).parent.path;
  final lib = ThermionDartTexture1(
      DynamicLibrary.open("$scriptDir/libthermion_swift.dylib"));
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

  var outDir = Directory("$scriptDir/output");
  if (outDir.existsSync()) {
    outDir.deleteSync(recursive: true);
  }
  outDir.createSync();

  await viewer.setRecordingOutputDirectory(outDir.path);
  await viewer.setRecording(true);
  await viewer.loadSkybox(
      "file:///$scriptDir/assets/default_env/default_env_skybox.ktx");
  await Future.delayed(Duration(milliseconds: 16));
  await viewer.render();
  await viewer.dispose();
}

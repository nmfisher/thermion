import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:ffi/ffi.dart';
import 'package:thermion_dart/src/utils/src/dart_resources.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_viewer_ffi.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_dart.g.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:cli_windows/thermion_window.g.dart';

void main(List<String> arguments) async {
  var hwnd = create_thermion_window(500, 500, 0, 0);
  update();

  final resourceLoader = calloc<ResourceLoaderWrapper>(1);
  
  var loadToOut = NativeCallable<
      Void Function(Pointer<Char>,
          Pointer<ResourceBuffer>)>.listener(DartResourceLoader.loadResource);

  resourceLoader.ref.loadToOut = loadToOut.nativeFunction;
  var freeResource = NativeCallable<Void Function(ResourceBuffer)>.listener(
      DartResourceLoader.freeResource);
  resourceLoader.ref.freeResource = freeResource.nativeFunction;

  var viewer = ThermionViewerFFI(  
    resourceLoader: resourceLoader.cast<Void>());

  await viewer.initialized;
  var swapChain = await viewer.createHeadlessSwapChain(500,500);
  var view = await viewer.getViewAt(0);
  await view.updateViewport(500, 500);
  var camera = await viewer.getMainCamera();
  await camera.setLensProjection();
  
  await view.setRenderable(true, swapChain);
  
  await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);

  var skyboxPath = File("..\\..\\assets\\default_env_skybox.ktx").absolute;
  await viewer.loadSkybox("file://${skyboxPath.uri.toFilePath(windows: true)}");

  final cube = await viewer.createGeometry(GeometryHelper.cube());

  var stopwatch = Stopwatch();
  stopwatch.start();

  var last = 0;

  await viewer.setCameraPosition(0, 0, 10);

  while(true) {  
    var angle = (stopwatch.elapsedMilliseconds / 1000) * 2 * pi;
    var rotation = Quaternion.axisAngle(Vector3(0,1,0), angle);
    var position = Vector3(10 * sin(angle), 0, 10 * cos(angle));
    var modelMatrix = Matrix4.compose(position, rotation, Vector3.all(1));
    await viewer.setCameraModelMatrix4(modelMatrix);
    await viewer.render();
    update();
    await Future.delayed(Duration(milliseconds: 17));
  }
  

  
}

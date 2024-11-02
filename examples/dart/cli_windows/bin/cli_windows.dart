import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
// import 'package:thermion_dart/thermion_dart/thermion_viewer_ffi.dart';
import 'package:thermion_dart/src/utils/src/dart_resources.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_viewer_ffi.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_dart.g.dart';

void main(List<String> arguments) async {
  var lib = DynamicLibrary.open("thermion_windows.dll");
  var createWindow = lib.lookupFunction<Int Function(Int width, Int height, Int left, Int top), int Function(int, int, int, int)>("create_thermion_window");
  var update = lib.lookupFunction<Void Function(), void Function()>("update");
  var hwnd = createWindow(500, 500, 0, 0);
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
  var swapChain = await viewer.createSwapChain(hwnd);
  var view = await viewer.getViewAt(0);
  await view.updateViewport(500, 500);
  
  await view.setRenderable(true, swapChain);
  
  await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);

  var skyboxPath = File("..\\..\\assets\\default_env_skybox.ktx").absolute;

  await viewer.loadSkybox("file://${skyboxPath.uri.toFilePath(windows: true)}");
  while(true) {
    await viewer.render();
    update();
    await Future.delayed(Duration(milliseconds: 16));
  }
  

  
}

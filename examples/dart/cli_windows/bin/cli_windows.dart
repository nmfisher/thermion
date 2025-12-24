import 'dart:io';
import 'dart:math';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:cli_windows/thermion_window.g.dart';

void main(List<String> arguments) async {
  var hwnd = create_thermion_window(500, 500, 0, 0);
  update();
  final config = FFIFilamentConfig(loadResource: (path) async => File(path.replaceAll("file://", "")).readAsBytesSync());
  await FFIFilamentApp.create(config: config);
  var viewer = ThermionViewerFFI();

  await viewer.initialized;
  var swapChain = await FilamentApp.instance!.createSwapChain(Pointer<Void>.fromAddress(hwnd));
  var view = viewer.view;
  await view.setViewport(500, 500);
  var camera = await viewer.getActiveCamera();
  await camera.setLensProjection();
  await FilamentApp.instance!.register(swapChain, view);
  
  await viewer.setBackgroundColor(1.0, 0.0, 0.0, 1.0);

  var skyboxPath = File("..\\..\\assets\\default_env_skybox.ktx").absolute;
  await viewer.loadSkybox("file://${skyboxPath.uri.toFilePath(windows: true)}");

  final cube = await viewer.createGeometry(GeometryHelper.cube());

  var stopwatch = Stopwatch();
  stopwatch.start();

  var last = 0;

  await camera.lookAt(Vector3(0, 0, 10));

  while(true) {  
    var angle = (stopwatch.elapsedMilliseconds / 1000) * 2 * pi;
    var rotation = Quaternion.axisAngle(Vector3(0,1,0), angle);
    var position = Vector3(10 * sin(angle), 0, 10 * cos(angle));
    var modelMatrix = Matrix4.compose(position, rotation, Vector3.all(1));
    await camera.setModelMatrix(modelMatrix);
    await FilamentApp.instance!.requestFrame();
    update();
    await Future.delayed(Duration(milliseconds: 17));
  }
  

  
}

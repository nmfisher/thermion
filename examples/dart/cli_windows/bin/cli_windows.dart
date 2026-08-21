import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:cli_windows/thermion_window.g.dart';

void main(List<String> arguments) async {
  var hwnd = create_thermion_window(500, 500, 0, 0);
  update();
  final config = FFIFilamentConfig(
      loadResource: (path) async =>
          File(path.replaceAll("file://", "")).readAsBytesSync());
  await FFIFilamentApp.create(config: config);
  var viewer = ThermionViewerFFI();

  await viewer.initialized;
  var swapChain = await FilamentApp.instance!
      .createSwapChain(Pointer<Void>.fromAddress(hwnd));
  var view = viewer.view;
  await view.setViewport(500, 500);
  var camera = await viewer.getActiveCamera();
  await camera.setLensProjection();
  await FilamentApp.instance!.renderManager.attach(view, swapChain);

  await (await viewer.view.getScene()).setSkybox(
    await FilamentApp.instance!
        .createColoredSkybox(r: 1.0, g: 0.0, b: 0.0, a: 1.0),
  );

  var skyboxPath = File("../../assets/default_env_skybox.ktx").absolute;
  await viewer.loadSkybox(
      "file://${skyboxPath.uri.toFilePath(windows: Platform.isWindows)}");

  final cube = await viewer.createGeometry(GeometryUtils.cube());

  var stopwatch = Stopwatch();
  stopwatch.start();

  var last = 0;

  await camera.lookAt(Vector3(0, 0, 10));

  FrameScheduler_initDartApi(ffi.NativeApi.initializeApiDLData);

  final framePort = ReceivePort();
  final completer = Completer<void>();

  framePort.listen((message) async {
    var angle = (stopwatch.elapsedMilliseconds / 1000) * 2 * pi;
    var rotation = Quaternion.axisAngle(Vector3(0, 1, 0), angle);
    var position = Vector3(10 * sin(angle), 0, 10 * cos(angle));
    var modelMatrix = Matrix4.compose(position, rotation, Vector3.all(1));
    await camera.setModelMatrix(modelMatrix);
    await FilamentApp.instance!.render();
    update();
  });

  FrameScheduler_startWithPort(framePort.sendPort.nativePort, 60);

  // Keep alive until interrupted
  ProcessSignal.sigint.watch().listen((_) {
    FrameScheduler_stop();
    framePort.close();
    completer.complete();
  });

  await completer.future;
}

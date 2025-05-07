import 'dart:async';
import 'dart:js_interop';
import 'dart:math';
import 'package:web/web.dart';
import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart.dart' hide NativeLibrary;
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/resource_loader.dart';
import 'web_input_handler.dart';
import 'package:thermion_dart/src/bindings/src/thermion_dart_js_interop.g.dart';

void main(List<String> arguments) async {
  Logger.root.onRecord.listen((record) {
    print(record);
  });

  NativeLibrary.initBindings("thermion_dart");

  final canvas =
      document.getElementById("thermion_canvas") as HTMLCanvasElement;
  try {
    canvas.width = canvas.clientWidth;
    canvas.height = canvas.clientHeight;
  } catch (err) {
    print(err.toString());
  }

  final config =
      FFIFilamentConfig(sharedContext: nullptr.cast(), backend: Backend.OPENGL);

  await FFIFilamentApp.create(config: config);

  var swapChain = await FilamentApp.instance!
      .createHeadlessSwapChain(canvas.width, canvas.height);
  final viewer = ThermionViewerFFI(loadAssetFromUri: defaultResourceLoader);
  await viewer.initialized;
  await FilamentApp.instance!.setClearOptions(1.0, 0.0, 0.0, 1.0);
  await FilamentApp.instance!.register(swapChain, viewer.view);
  await viewer.setViewport(canvas.width, canvas.height);
  await viewer.setRendering(true);
  final rnd = Random();
  // ignore: prefer_function_declarations_over_variables
  bool resizing = false;
  // ignore: prefer_function_declarations_over_variables
  final resizer = () async {
    if (resizing) {
      return;
    }
    try {
      resizing = true;
      await viewer.setViewport(canvas.clientWidth, canvas.clientHeight);
      Thermion_resizeCanvas(canvas.clientWidth, canvas.clientHeight);
    } catch (err) {
      print(err);
    } finally {
      resizing = false;
    }
  };
  // ignore: unused_local_variable, prefer_function_declarations_over_variables
  final jsWrapper = () {
    var promise = resizer().toJS;
    return promise;
  };
  window.addEventListener('resize', jsWrapper.toJS);
  // // await FilamentApp.instance!.render();
  // // await Future.delayed(Duration(seconds: 1));

  // // await FilamentApp.instance!.setClearOptions(1.0, 1.0, 0.0, 1.0);
  // // await FilamentApp.instance!.render();
  // // await Future.delayed(Duration(seconds: 1));

  await viewer.loadSkybox("assets/default_env_skybox.ktx");
  await viewer.loadGltf("assets/cube.glb");
  final camera = await viewer.getActiveCamera();

  var zOffset = 10.0;

  final inputHandler = DelegateInputHandler.flight(viewer);

  final webInputHandler =
      WebInputHandler(inputHandler: inputHandler, canvas: canvas);
  await camera.lookAt(Vector3(0, 0, zOffset));
  DateTime lastRender = DateTime.now();

  while (true) {
    var stackPtr = stackSave();
    var now = DateTime.now();
    await FilamentApp.instance!.requestFrame();
    now = DateTime.now();
    var timeSinceLast =
        now.microsecondsSinceEpoch - lastRender.microsecondsSinceEpoch;
    lastRender = now;
    if (timeSinceLast < 1667) {
      var waitFor = 1667 - timeSinceLast;
      await Future.delayed(Duration(microseconds: waitFor));
    }
    stackRestore(stackPtr);
    // inputHandler.keyDown(PhysicalKey.S);
    // await camera.lookAt(Vector3(0,0,zOffset));
    // zOffset +=0.1;
  }
}

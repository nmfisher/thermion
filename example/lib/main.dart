import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_filament/filament_controller_ffi.dart';
import 'package:flutter_filament_example/camera_matrix_overlay.dart';
import 'package:flutter_filament_example/menus/controller_menu.dart';
import 'package:flutter_filament_example/example_viewport.dart';
import 'package:flutter_filament_example/picker_result_widget.dart';
import 'package:flutter_filament_example/menus/scene_menu.dart';

import 'package:flutter_filament/filament_controller.dart';

const loadDefaultScene = bool.hasEnvironment('--load-default-scene');

void main() async {
  print(loadDefaultScene);
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData(useMaterial3: true),
        // showPerformanceOverlay: true,
        home: const Scaffold(body: ExampleWidget()));
  }
}

class ExampleWidget extends StatefulWidget {
  const ExampleWidget({super.key});

  @override
  State<StatefulWidget> createState() {
    return ExampleWidgetState();
  }
}

enum MenuType { controller, assets, camera, misc }

class ExampleWidgetState extends State<ExampleWidget> {
  FilamentController? _filamentController;

  EdgeInsets _viewportMargin = EdgeInsets.zero;

  // these are all the options that can be set via the menu
  // we store them here
  static bool rendering = false;
  static int framerate = 60;
  static bool postProcessing = true;
  static bool frustumCulling = true;
  static ManipulatorMode cameraManipulatorMode = ManipulatorMode.ORBIT;

  static double zoomSpeed = 0.01;
  static double orbitSpeedX = 0.01;
  static double orbitSpeedY = 0.01;

  static FilamentEntity? last;

  static bool hasSkybox = false;
  static bool coneHidden = false;

  static FilamentEntity? shapes;
  static FilamentEntity? flightHelmet;
  static FilamentEntity? buster;

  static List<String>? animations;

  static FilamentEntity? directionalLight;

  static bool loop = false;
  static final showProjectionMatrices = ValueNotifier<bool>(false);

  late StreamSubscription _listener;

  @override
  void initState() {
    super.initState();
    if (loadDefaultScene) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        setState(() {
          _filamentController = FilamentControllerFFI();
        });
        await Future.delayed(const Duration(milliseconds: 100));
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
          await _filamentController!.createViewer();
          await _filamentController!
              .loadSkybox("assets/default_env/default_env_skybox.ktx");

          await _filamentController!.setRendering(true);
          shapes =
              await _filamentController!.loadGlb("assets/shapes/shapes.glb");
          ExampleWidgetState.animations = await _filamentController!
              .getAnimationNames(ExampleWidgetState.shapes!);
          hasSkybox = true;
          rendering = true;
        });
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    _listener.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: ExampleViewport(
          controller: _filamentController,
          padding: _viewportMargin,
        ),
      ),
      Align(
          alignment: Alignment.bottomCenter,
          child: Container(
              padding: const EdgeInsets.only(bottom: 30),
              height: 100,
              color: Colors.white,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                ControllerMenu(
                    controller: _filamentController,
                    onControllerDestroyed: () {},
                    onControllerCreated: (controller) {
                      setState(() {
                        _filamentController = controller;
                        _listener = _filamentController!.onLoad
                            .listen((FilamentEntity entity) {
                          print("Set last to $entity");
                          last = entity;
                          if (mounted) {
                            setState(() {});
                          }
                          print(_filamentController!.getNameForEntity(entity) ??
                              "NAME NOT FOUND");
                        });
                      });
                    }),
                SceneMenu(
                  controller: _filamentController,
                ),
                Expanded(child: Container()),
                TextButton(
                  child: const Text("Toggle viewport size"),
                  onPressed: () {
                    setState(() {
                      _viewportMargin = (_viewportMargin == EdgeInsets.zero)
                          ? const EdgeInsets.all(30)
                          : EdgeInsets.zero;
                    });
                  },
                )
              ]))),
      _filamentController == null
          ? Container()
          : Padding(
              padding: const EdgeInsets.only(top: 40, left: 20, right: 20),
              child: ValueListenableBuilder(
                  valueListenable: showProjectionMatrices,
                  builder: (ctx, value, child) => CameraMatrixOverlay(
                      controller: _filamentController!,
                      showProjectionMatrices: value)),
            ),
      _filamentController == null
          ? Container()
          : Align(
              alignment: Alignment.topRight,
              child: PickerResultWidget(controller: _filamentController!),
            )
    ]);
  }
}

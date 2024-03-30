import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_filament_example/camera_matrix_overlay.dart';
import 'package:flutter_filament_example/menus/controller_menu.dart';
import 'package:flutter_filament_example/example_viewport.dart';
import 'package:flutter_filament_example/picker_result_widget.dart';
import 'package:flutter_filament_example/menus/scene_menu.dart';

import 'package:flutter_filament/flutter_filament.dart';

const loadDefaultScene = bool.hasEnvironment('--load-default-scene');

void main() async {
  print(loadDefaultScene);
  runApp(const MyApp());
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
        theme: ThemeData(
            useMaterial3: true,
            textTheme: const TextTheme(
                labelLarge: TextStyle(fontSize: 12),
                displayMedium: TextStyle(fontSize: 12),
                headlineMedium: const TextStyle(fontSize: 12),
                titleMedium: TextStyle(fontSize: 12),
                bodyLarge: TextStyle(fontSize: 14),
                bodyMedium: TextStyle(fontSize: 12))),
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
  static bool recording = false;
  static int framerate = 60;
  static bool postProcessing = false;
  static bool antiAliasingMsaa = false;
  static bool antiAliasingTaa = false;
  static bool antiAliasingFxaa = false;
  static bool frustumCulling = true;
  static ManipulatorMode cameraManipulatorMode = ManipulatorMode.ORBIT;

  static double zoomSpeed = 0.01;
  static double orbitSpeedX = 0.01;
  static double orbitSpeedY = 0.01;

  static bool hasSkybox = false;
  static bool coneHidden = false;

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
        WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
          await _filamentController!.createViewer();

          await _filamentController!
              .loadSkybox("assets/default_env/default_env_skybox.ktx");

          await _filamentController!.setRendering(true);

          await _filamentController!.loadGlb("assets/shapes/shapes.glb");

          await _filamentController!
              .setCameraManipulatorOptions(zoomSpeed: 1.0);

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

  EntityTransformController? _transformController;

  final _sharedFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: ExampleViewport(
            controller: _filamentController,
            entityTransformController: _transformController,
            padding: _viewportMargin,
            keyboardFocusNode: _sharedFocusNode),
      ),
      EntityListWidget(controller: _filamentController),
      Positioned(
          bottom: Platform.isIOS ? 30 : 0,
          left: 0,
          right: 10,
          height: 30,
          child: Container(
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: Colors.white.withOpacity(0.25),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                ControllerMenu(
                    sharedFocusNode: _sharedFocusNode,
                    controller: _filamentController,
                    onToggleViewport: () {
                      setState(() {
                        _viewportMargin = (_viewportMargin == EdgeInsets.zero)
                            ? const EdgeInsets.all(30)
                            : EdgeInsets.zero;
                      });
                    },
                    onControllerDestroyed: () {},
                    onControllerCreated: (controller) {
                      setState(() {
                        _filamentController = controller;
                      });
                    }),
                SceneMenu(
                  sharedFocusNode: _sharedFocusNode,
                  controller: _filamentController,
                ),
                GestureDetector(
                    onTap: () async {
                      await _filamentController!
                          .loadGlb('assets/shapes/shapes.glb', numInstances: 1);
                    },
                    child: Container(
                        color: Colors.transparent,
                        child: const Text("shapes.glb"))),
                const SizedBox(width: 5),
                GestureDetector(
                    onTap: () async {
                      await _filamentController!.loadGlb('assets/1.glb');
                    },
                    child: Container(
                        color: Colors.transparent, child: const Text("1.glb"))),
                const SizedBox(width: 5),
                GestureDetector(
                    onTap: () async {
                      await _filamentController!.loadGlb('assets/2.glb');
                    },
                    child: Container(
                        color: Colors.transparent, child: const Text("2.glb"))),
                const SizedBox(width: 5),
                GestureDetector(
                    onTap: () async {
                      await _filamentController!.loadGlb('assets/3.glb');
                    },
                    child: Container(
                        color: Colors.transparent, child: const Text("3.glb"))),
                Expanded(child: Container()),
              ]))),
      _filamentController == null
          ? Container()
          : Padding(
              padding: const EdgeInsets.only(top: 10, left: 20, right: 20),
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

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
  static bool recording = false;
  static int framerate = 60;
  static bool postProcessing = true;
  static bool frustumCulling = true;
  static ManipulatorMode cameraManipulatorMode = ManipulatorMode.ORBIT;

  static double zoomSpeed = 0.01;
  static double orbitSpeedX = 0.01;
  static double orbitSpeedY = 0.01;

  static bool hasSkybox = false;
  static bool coneHidden = false;

  static final assets = <FilamentEntity>[];
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
          assets.add(
              await _filamentController!.loadGlb("assets/shapes/shapes.glb"));
          ExampleWidgetState.animations =
              await _filamentController!.getAnimationNames(assets.first);
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

  Widget _assetEntry(FilamentEntity entity) {
    return Row(children: [
      Text("Asset ${entity}"),
      IconButton(
          tooltip: "Transform to unit cube",
          onPressed: () async {
            await _filamentController!.transformToUnitCube(entity);
          },
          icon: const Icon(Icons.settings_overscan_outlined)),
      IconButton(
          onPressed: () async {
            await _filamentController!.removeAsset(entity);
            assets.remove(entity);
            setState(() {});
          },
          icon: const Icon(Icons.cancel_sharp))
    ]);
    ;
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
      Positioned(
          bottom: 80,
          left: 10,
          height: 200,
          width: 300,
          child: Container(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: Colors.white.withOpacity(0.25),
              ),
              child: ListView(children: assets.map(_assetEntry).toList()))),
      Positioned(
          bottom: 10,
          left: 10,
          right: 10,
          height: 60,
          child: Container(
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: Colors.white.withOpacity(0.25),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                ControllerMenu(
                    controller: _filamentController,
                    onControllerDestroyed: () {},
                    onControllerCreated: (controller) {
                      setState(() {
                        _filamentController = controller;
                        _listener = _filamentController!.onLoad
                            .listen((FilamentEntity entity) async {
                          assets.add(entity);
                          animations = await _filamentController!
                              .getAnimationNames(entity);
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
                GestureDetector(
                    onTap: () async {
                      await _filamentController!
                          .loadGlb('assets/shapes/shapes.glb');
                    },
                    child: Container(
                        color: Colors.transparent,
                        child: const Text("shapes.glb"))),
                SizedBox(width: 5),
                GestureDetector(
                    onTap: () async {
                      await _filamentController!.loadGlb('assets/1.glb');
                    },
                    child: Container(
                        color: Colors.transparent, child: const Text("1.glb"))),
                SizedBox(width: 5),
                GestureDetector(
                    onTap: () async {
                      await _filamentController!.loadGlb('assets/2.glb');
                    },
                    child: Container(
                        color: Colors.transparent, child: const Text("2.glb"))),
                SizedBox(width: 5),
                GestureDetector(
                    onTap: () async {
                      await _filamentController!.loadGlb('assets/3.glb');
                    },
                    child: Container(
                        color: Colors.transparent, child: const Text("3.glb"))),
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

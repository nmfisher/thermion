import 'dart:async';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/filament/widgets/debug/entity_list_widget.dart';
import 'package:thermion_flutter_example/camera_matrix_overlay.dart';
import 'package:thermion_flutter_example/menus/controller_menu.dart';
import 'package:thermion_flutter_example/example_viewport.dart';
import 'package:thermion_dart/thermion_dart/entities/entity_transform_controller.dart';
import 'package:thermion_flutter_example/menus/scene_menu.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter_example/picker_result_widget.dart';


const loadDefaultScene = bool.hasEnvironment('--load-default-scene');

void main() async {
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
        home: const Scaffold(
          backgroundColor: Color(0x00000000),
          body: ExampleWidget()));
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
  final _plugin = ThermionFlutterPlugin();

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
    return FutureBuilder(
        future: _plugin.initialized,
        builder: (_, AsyncSnapshot<bool> initialized) {
          var isInitialized = initialized.data == true;

          return Stack(
            fit: StackFit.expand,
            children: [
            if (isInitialized)
              Positioned.fill(
                child: ExampleViewport(
                    controller: isInitialized ? _plugin : null,
                    entityTransformController: _transformController,
                    padding: _viewportMargin,
                    keyboardFocusNode: _sharedFocusNode),
              ),
            Positioned(
                bottom: 30,
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
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ControllerMenu(
                              sharedFocusNode: _sharedFocusNode,
                              controller: _plugin,
                              onToggleViewport: () {
                                setState(() {
                                  _viewportMargin =
                                      (_viewportMargin == EdgeInsets.zero)
                                          ? const EdgeInsets.all(30)
                                          : EdgeInsets.zero;
                                });
                              },
                              onControllerDestroyed: () {},
                              onControllerCreated: () {}),
                          SceneMenu(
                            sharedFocusNode: _sharedFocusNode,
                            controller: _plugin,
                          ),
                          GestureDetector(
                              onTap: () async {
                                await _plugin.viewer.loadGlb(
                                    'assets/shapes/shapes.glb',
                                    numInstances: 1);
                              },
                              child: Container(
                                  color: Colors.transparent,
                                  child: const Text("shapes.glb"))),
                          const SizedBox(width: 5),
                          GestureDetector(
                              onTap: () async {
                                await _plugin.viewer.loadGlb('assets/1.glb');
                              },
                              child: Container(
                                  color: Colors.transparent,
                                  child: const Text("1.glb"))),
                          const SizedBox(width: 5),
                          GestureDetector(
                              onTap: () async {
                                await _plugin.viewer.loadGlb('assets/2.glb');
                              },
                              child: Container(
                                  color: Colors.transparent,
                                  child: const Text("2.glb"))),
                          const SizedBox(width: 5),
                          GestureDetector(
                              onTap: () async {
                                await _plugin.viewer.loadGlb('assets/3.glb');
                              },
                              child: Container(
                                  color: Colors.transparent,
                                  child: const Text("3.glb"))),
                          Expanded(child: Container()),
                        ]))),
            if (isInitialized) ...[
              Positioned(top:10, left:10, width:200, height:200, child:Container(
                child:EntityListWidget(controller: _plugin.viewer))),
              // Padding(
              //   padding: const EdgeInsets.only(top: 10, left: 20, right: 20),
              //   child: ValueListenableBuilder(
              //       valueListenable: showProjectionMatrices,
              //       builder: (ctx, value, child) => CameraMatrixOverlay(
              //           controller: _plugin.viewer, showProjectionMatrices: value)),
              // ),
              // Align(
              //   alignment: Alignment.topRight,
              //   child: PickerResultWidget(controller: _plugin.viewer),
              // )
            ]
          ]);
        });
  }
}

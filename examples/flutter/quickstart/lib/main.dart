import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

void main() {
  runApp(const MyApp());
  Logger.root.onRecord.listen((record) {
    print(record);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thermion Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Thermion Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ThermionViewer? _viewer;
  ManipulatorType _manipulatorType = ManipulatorType.ORBIT;
  int _framerate = 60;
  Timer? _assetAnimationTimer;
  Timer? _skyboxRemovalTimer;

  late DirectLight _sun;

  @override
  void initState() {
    super.initState();
    _sun = DirectLight.sun(direction: Vector3(0.7, -1, -0.8).normalized());
    if (kIsWeb) {
      ThermionFlutterPlugin.instance.setOptions(const ThermionFlutterOptions(
          webOptions: WebOptions(importCanvasAsWidget: false)));
    }
  }

  bool _showViewer = false;

  void _cancelViewerCallbacks() {
    _assetAnimationTimer?.cancel();
    _assetAnimationTimer = null;
    _skyboxRemovalTimer?.cancel();
    _skyboxRemovalTimer = null;
  }

  @override
  void dispose() {
    _cancelViewerCallbacks();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          if (_showViewer)
            Positioned.fill(
                child: ViewerWidget(
              assetPath: "assets/cube.glb",
              skyboxPath: "assets/default_env_skybox.ktx",
              iblPath: "assets/default_env_ibl.ktx",
              directLight: _sun,
              transformToUnitCube: true,
              initialCameraPosition: Vector3(0, 0, 6),
              background: Colors.blue,
              manipulatorType: _manipulatorType,
              onAssetLoaded: (viewer, asset) async {
                _assetAnimationTimer?.cancel();
                final startedAt = DateTime.now();
                _assetAnimationTimer = Timer.periodic(
                  const Duration(milliseconds: 16),
                  (timer) async {
                    if (!mounted ||
                        !_showViewer ||
                        !identical(_viewer, viewer)) {
                      timer.cancel();
                      return;
                    }
                    final now = DateTime.now();
                    final elapsed = (now.millisecondsSinceEpoch -
                            startedAt.millisecondsSinceEpoch) /
                        1000;
                    await asset.setTransform(Matrix4.rotationY(elapsed));
                  },
                );
              },
              onViewerAvailable: (viewer) async {
                if (!mounted || !_showViewer) {
                  return;
                }
                setState(() {
                  _viewer = viewer;
                });

                _skyboxRemovalTimer?.cancel();
                _skyboxRemovalTimer = Timer(const Duration(seconds: 5), () {
                  if (!mounted || !_showViewer || !identical(_viewer, viewer)) {
                    return;
                  }
                  viewer
                      .removeSkybox()
                      .catchError((Object error, StackTrace stack) {
                    debugPrint(
                        'Failed to remove quickstart skybox: $error\n$stack');
                  });
                });
              },
              initial: Container(
                color: Colors.red,
              ),
            )),
          Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showViewer = !_showViewer;
                              if (!_showViewer) {
                                _cancelViewerCallbacks();
                                _viewer = null;
                              }
                            });
                          },
                          child: Text(
                              _showViewer ? "Remove viewer" : "Show viewer")),
                      if (_viewer != null) ...[
                        const SizedBox(width: 16),
                        ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _manipulatorType =
                                    _manipulatorType == ManipulatorType.ORBIT
                                        ? ManipulatorType.FREE_FLIGHT
                                        : ManipulatorType.ORBIT;
                              });
                            },
                            child: Text(
                                _manipulatorType == ManipulatorType.ORBIT
                                    ? "Switch to Free Flight"
                                    : "Switch to Orbit")),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white70,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<int>(
                            value: _framerate,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(
                                  value: 15, child: Text('15 FPS')),
                              DropdownMenuItem(
                                  value: 30, child: Text('30 FPS')),
                              DropdownMenuItem(
                                  value: 60, child: Text('60 FPS')),
                            ],
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => _framerate = v);
                              FilamentApp.instance!.setTargetFramerate(v);
                            },
                          ),
                        ),
                      ],
                    ],
                  )))
        ]));
  }
}

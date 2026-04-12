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
                var last = DateTime.now();
                Timer.periodic(Duration(milliseconds: 16), (timer) async {
                  var now = DateTime.now();
                  await asset.setTransform(Matrix4.rotationY(
                      (now.millisecondsSinceEpoch.toDouble() -
                              last.millisecondsSinceEpoch) /
                          1000));
                });
              },
              onViewerAvailable: (viewer) async {
                setState(() {
                  _viewer = viewer;
                });
                await Future.delayed(const Duration(seconds: 5));
                await viewer.removeSkybox();
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
                      ],
                    ],
                  )))
        ]));
  }
}

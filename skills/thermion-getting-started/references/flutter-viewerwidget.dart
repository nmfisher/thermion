// Minimal Thermion Flutter app using the high-level ViewerWidget.
//
// Expects an assets/ folder (declared in pubspec.yaml) containing:
//   cube.glb, default_env_skybox.ktx, default_env_ibl.ktx
//
// Adapted from examples/flutter/quickstart in the thermion repository.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Thermion quickstart',
        theme: ThemeData(useMaterial3: true),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _spinTimer;

  @override
  void dispose() {
    _spinTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ViewerWidget(
          assetPath: 'assets/cube.glb',
          skyboxPath: 'assets/default_env_skybox.ktx',
          iblPath: 'assets/default_env_ibl.ktx',
          directLight: DirectLight.sun(direction: Vector3(0, -1, -1)),
          transformToUnitCube: true,
          initialCameraPosition: Vector3(0, 2, 4),
          manipulatorType: ManipulatorType.ORBIT,
          onViewerAvailable: (viewer) async {
            // Post-processing (tone mapping, anti-aliasing) is off by default.
            await viewer.setPostProcessing(true);
          },
          onAssetLoaded: (viewer, asset) async {
            // Spin the model: set a fresh transform ~60x per second. There are
            // no setPosition/setRotation helpers — transforms are Matrix4.
            final started = DateTime.now();
            _spinTimer?.cancel();
            _spinTimer = Timer.periodic(const Duration(milliseconds: 16),
                (timer) async {
              final elapsed = DateTime.now()
                      .difference(started)
                      .inMilliseconds /
                  1000;
              await asset.setTransform(Matrix4.rotationY(elapsed));
            });
          },
        ),
      );
}

// Flutter example: the load/unload lifecycle of a ThermionViewer with a glTF
// asset — create viewer, load, render, then correct teardown order.
//
// Expects assets/ declared in pubspec.yaml containing FlightHelmet/ or swap
// in any .glb.
//
// Adapted from examples/flutter/viewer in the thermion repository.

import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(home: HomePage());
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  ThermionViewer? _viewer;

  Future<void> _load() async {
    if (_viewer != null) return;

    // Only one viewer can be active at a time; creating a new one before
    // disposing the old one throws.
    final viewer = await ThermionFlutterPlugin.createViewer();

    await viewer.loadGltf('assets/FlightHelmet/FlightHelmet.gltf');
    await viewer.loadSkybox('assets/default_env_skybox.ktx');
    await viewer.loadIbl('assets/default_env_ibl.ktx');

    final camera = await viewer.getActiveCamera();
    await camera.lookAt(Vector3(0, 1, 6));

    await viewer.setPostProcessing(true);

    setState(() => _viewer = viewer);
  }

  Future<void> _unload() async {
    final viewer = _viewer;
    if (viewer == null) return;

    // Teardown order matters:
    // 1) remove ThermionWidget from the tree (setState below)
    // 2) drop local references
    // 3) dispose the viewer
    setState(() => _viewer = null);
    await viewer.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          if (_viewer != null)
            Positioned.fill(child: ThermionWidget(viewer: _viewer!)),
          Center(
            child: FilledButton(
              onPressed: _viewer == null ? _load : _unload,
              child: Text(_viewer == null ? 'Load' : 'Unload'),
            ),
          ),
        ]),
      );
}

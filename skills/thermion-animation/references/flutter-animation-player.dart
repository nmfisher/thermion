// Flutter example: a minimal glTF animation player. Lists the asset's clips,
// plays the selected one with a crossfade, and ticks animationManager.update
// every frame (without this, nothing moves).
//
// Expects assets/ declared in pubspec.yaml with an animated glTF (e.g.
// BusterDrone/scene.gltf from the thermion examples assets).
//
// Adapted from examples/flutter/animations in the thermion repository.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(home: PlayerPage());
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  ThermionViewer? _viewer;
  ThermionAsset? _asset;
  List<String> _clipNames = [];
  String? _selected;
  Timer? _tickTimer;

  Future<void> _load() async {
    final viewer = await ThermionFlutterPlugin.createViewer();
    await viewer.setPostProcessing(true);

    await viewer.loadIbl('assets/default_env_ibl.ktx');
    await viewer.addDirectLight(
        DirectLight.sun(direction: Vector3(0, -1, -1)));

    final asset = await viewer.loadGltf('assets/BusterDrone/scene.gltf');
    await asset.transformToUnitCube();
    await asset.addAnimationComponent();

    final camera = await viewer.getActiveCamera();
    await camera.lookAt(Vector3(2, 1.5, 3), focus: Vector3(0, 0, 0));

    // Tick the animation clock every frame. update() takes an ABSOLUTE
    // monotonic clock in nanos — accumulate ~60fps deltas.
    final animationManager = viewer.app.animationManager;
    var clockNanos = 0;
    final dtNanos = (1e9 / 60).round();
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 16), (_) async {
      clockNanos += dtNanos;
      await animationManager.update(clockNanos);
    });

    final clipNames = await asset.getGltfAnimationNames();
    setState(() {
      _viewer = viewer;
      _asset = asset;
      _clipNames = clipNames;
      _selected = clipNames.isNotEmpty ? clipNames.first : null;
    });

    if (_selected != null) {
      await asset.playGltfAnimationByName(_selected!,
          loop: true, crossfade: 0.2);
    }
  }

  Future<void> _play(String? name) async {
    if (name == null || _asset == null) return;
    setState(() => _selected = name);
    await _asset!.playGltfAnimationByName(name,
        loop: true, crossfade: 0.2, replaceActive: true);
  }

  Future<void> _stop() async {
    if (_selected == null || _asset == null) return;
    await _asset!.stopGltfAnimationByName(_selected!);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _viewer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: _viewer == null
            ? Center(child: FilledButton(onPressed: _load, child: const Text('Load')))
            : Stack(children: [
                Positioned.fill(child: ThermionWidget(viewer: _viewer!)),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DropdownButton<String>(
                          value: _selected,
                          items: _clipNames
                              .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                              .toList(),
                          onChanged: _play,
                        ),
                        const SizedBox(width: 16),
                        FilledButton(onPressed: _stop, child: const Text('Stop')),
                      ],
                    ),
                  ),
                ),
              ]),
      );
}

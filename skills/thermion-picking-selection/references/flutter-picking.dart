// Flutter example: tap picking with a selection outline. Three cubes; tapping
// one picks it (View.pick) and gives it a green stencil outline.
//
// Expects assets/ declared in pubspec.yaml containing cube.glb plus the
// default environment ktx files.
//
// Adapted from examples/flutter/picking in the thermion repository.

import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(home: PickPage());
}

class PickPage extends StatefulWidget {
  const PickPage({super.key});

  @override
  State<PickPage> createState() => _PickPageState();
}

class _PickPageState extends State<PickPage> {
  ThermionViewer? _viewer;
  ThermionAsset? _selected;

  Future<void> _load() async {
    final viewer = await ThermionFlutterPlugin.createViewer();
    await viewer.setPostProcessing(true);

    await viewer.loadIbl('assets/default_env_ibl.ktx');
    await viewer.addDirectLight(
        DirectLight.sun(direction: Vector3(0, -1, -1)));

    // Outline rendering needs rebuilt (barycentric-aware) vertex buffers.
    final cubes = <ThermionAsset>[];
    for (final x in [-1.5, 0.0, 1.5]) {
      final cube = await viewer.loadGltf('assets/cube.glb',
          rebuildVertices: true);
      await cube.transformToUnitCube();
      await cube.setTransform(Matrix4.translation(Vector3(x, 0, 0)));
      cubes.add(cube);
    }

    // Enable the highlight overlay once, before any setStencilHighlight.
    await viewer.view.setHighlightOverlayEnabled(true);
    await viewer.view.setStencilBufferEnabled(true);

    final camera = await viewer.getActiveCamera();
    await camera.lookAt(Vector3(2, 2, 4), focus: Vector3(0, 0, 0));

    // Stash for the pick handler.
    _cubes = cubes;

    setState(() => _viewer = viewer);
  }

  late List<ThermionAsset> _cubes;

  Future<void> _onTapUp(TapUpDetails details) async {
    final viewer = _viewer;
    if (viewer == null) return;
    final pos = details.localPosition;

    // Pointer coordinates are logical, top-left origin — same as the pick
    // API expects (rounded to int). Don't flip Y.
    await viewer.view.pick(pos.dx.round(), pos.dy.round(), (result) async {
      if (result.entity == 0) return;

      // Map the hit entity back to one of our assets.
      ThermionAsset? hit;
      for (final cube in _cubes) {
        if (result.entity == cube.entity ||
            await cube.containsChild(result.entity)) {
          hit = cube;
          break;
        }
      }
      if (hit == null) return;

      // Clear the previous outline, draw the new one.
      if (_selected != null) {
        await viewer.view.removeStencilHighlight(_selected!);
      }
      await viewer.view.setStencilHighlight(
        hit,
        r: 0.0, g: 1.0, b: 0.0,
        outlineWidth: 3.0,
      );
      setState(() => _selected = hit);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: _viewer == null
            ? Center(
                child: FilledButton(
                    onPressed: _load, child: const Text('Load')))
            : GestureDetector(
                onTapUp: _onTapUp,
                child: Stack(children: [
                  Positioned.fill(child: ThermionWidget(viewer: _viewer!)),
                ]),
              ),
      );
}

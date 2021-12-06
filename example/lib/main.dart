import 'dart:math';

import 'package:flutter/material.dart';
import 'package:polyvox_filament/filament_controller.dart';
import 'package:polyvox_filament/gesture_detecting_filament_view.dart';
import 'package:polyvox_filament/view/filament_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FilamentController _filamentController = PolyvoxFilamentController();

  int _primitiveIndex = 0;
  final weights = List.filled(255, 0.0);
  List<String> _targets = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          appBar: AppBar(
            title: const Text('Plugin example app'),
          ),
          body: Stack(children: [
            GestureDetectingFilamentView(
              controller: _filamentController,
            ),
            Positioned.fill(
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  ElevatedButton(
                      child: const Text('load skybox'),
                      onPressed: () async {
                        await _filamentController.loadSkybox(
                            'assets/default_env/default_env_skybox.ktx',
                            'assets/default_env/default_env_ibl.ktx');
                      }),
                  ElevatedButton(
                      child: const Text('load cube'),
                      onPressed: () async {
                        await _filamentController.loadGltf(
                            'assets/cube.gltf', 'assets');
                        await _filamentController.createMorpher('Cube', [0]);
                      }),
                  ElevatedButton(
                      child: const Text('stretch'),
                      onPressed: () async {
                        await _filamentController
                            .applyWeights(List.filled(8, 1.0));
                      }),
                  ElevatedButton(
                      child: const Text('squeeze'),
                      onPressed: () async {
                        await _filamentController
                            .applyWeights(List.filled(8, 0));
                      }),
                  ElevatedButton(
                      child: const Text('load caleb'),
                      onPressed: () async {
                        await _filamentController.loadGltf(
                            'assets/caleb_mouth_morph_target.gltf', 'assets');
                        _targets = await _filamentController
                            .getTargetNames('CC_Base_Body');
                        setState(() {});

                        _filamentController
                            .createMorpher('CC_Base_Body', [1, 7, 8]);
                      }),
                  ElevatedButton(
                      onPressed: () => _filamentController.playAnimation(0),
                      child: const Text('Play'))
                ],
              ),
            ),
          ])),
    );
  }
}

// ElevatedButton(
//     child: Text('load skybox'),
//     onPressed: () {
//       _filamentController.loadSkybox(
//           'assets/default_env/default_env_skybox.ktx',
//           'assets/default_env/default_env_ibl.ktx');
//     }),
// ElevatedButton(
//     child: Text('load gltf'),
//     onPressed: () {
//       _filamentController.loadGltf(
//           'assets/guy.gltf', 'assets', 'Material');
//     }),
// ElevatedButton(
//     child: Text('create morpher'),
//     onPressed: () {
//       _filamentController.createMorpher(
//           'CC_Base_Body.003', 'CC_Base_Body.003',
//           materialName: 'Material');
//     }),
// ])),
// Column(
//   children: _targets
//       .asMap()
//       .map((i, t) => MapEntry(
//           i,
//           Row(children: [
//             Text(t),
//             Slider(
//                 min: 0,
//                 max: 1,
//                 divisions: 10,
//                 value: weights[i],
//                 onChanged: (v) {
//                   setState(() {
//                     weights[i] = v;
//                     _filamentController
//                         .applyWeights(weights);
//                   });
//                 })
//           ])))
//       .values
//       .toList(),
// )

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:polyvox_filament/filament_controller.dart';
import 'package:polyvox_filament/gesture_detecting_filament_view.dart';
import 'package:polyvox_filament/view/filament_view.dart';
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
            Center(
                child: Container(
              width: 400,
              height: 400,
              child: FilamentWidget(
                controller: _filamentController,
              ),
            )),
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
                      }),
                  ElevatedButton(
                      child: const Text('set all weights to 1'),
                      onPressed: () async {
                        await _filamentController
                            .applyWeights(List.filled(8, 1.0));
                      }),
                  ElevatedButton(
                      child: const Text('set all weights to 0'),
                      onPressed: () async {
                        await _filamentController
                            .applyWeights(List.filled(8, 0));
                      }),
                  ElevatedButton(
                      onPressed: () => _filamentController.playAnimation(0),
                      child: const Text('play animation')),
                  ElevatedButton(
                      onPressed: () {
                        _filamentController.zoom(-1.0);
                      },
                      child: const Text('zoom in')),
                      
                  ElevatedButton(
                      onPressed: () {
                        _filamentController.zoom(1.0);
                      },
                      child: const Text('zoom out')),
                  ElevatedButton(
                      onPressed: () {
                        _filamentController.setCamera("Camera.001");
                      },
                      child: const Text('Set Camera')),
                  Builder(builder:(innerCtx) => ElevatedButton(
                      onPressed: () async {
                        final names = await _filamentController
                            .getTargetNames("Cube.001");
                        
                        await showDialog(
                            builder: (ctx) {
                              return Container(
                                  color: Colors.white,
                                  height:200, width:200,
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: names
                                              .map((name) => Text(name))
                                              .cast<Widget>()
                                              .toList() +
                                          <Widget>[
                                            ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(),
                                                child: Text("Close"))
                                          ]));
                            },
                            context: innerCtx);
                      },
                      child: const Text('get target names'))),
                  ElevatedButton(
                      onPressed: () async {
                        await _filamentController.panStart(1, 1);
                        await _filamentController.panUpdate(1, 2);
                        await _filamentController.panEnd();
                      },
                      child: Text("Pan left")),
                  ElevatedButton(
                      onPressed: () async {
                        await _filamentController.panStart(1, 1);
                        await _filamentController.panUpdate(0, 0);
                        await _filamentController.panEnd();
                      },
                      child: Text("Pan right"))
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
                  //  ElevatedButton(
                  //     child: const Text('init'),
                  //     onPressed: () async {
                  //       await _filamentController.initialize();
                  //     }),
import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:holovox_filament/filament_controller.dart';
import 'package:holovox_filament/view/filament_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FilamentController _filamentController = MimeticFilamentController();

  bool _rotate = false;
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
        body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (details) {
              _rotate
                  ? _filamentController.rotateStart(
                      details.localPosition.dx, details.localPosition.dy)
                  : _filamentController.panStart(
                      details.localPosition.dx, details.localPosition.dy);
            },
            onPanUpdate: (details) {
              _rotate
                  ? _filamentController.rotateUpdate(
                      details.localPosition.dx, details.localPosition.dy)
                  : _filamentController.panUpdate(
                      details.localPosition.dx, details.localPosition.dy);
            },
            onPanEnd: (d) {
              _rotate
                  ? _filamentController.rotateEnd()
                  : _filamentController.panEnd();
            },
            child: Stack(children: [
              FilamentWidget(controller: _filamentController),
              Positioned.fill(
                  top: 200,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            height: 100,
                            child: Row(children: [
                              ElevatedButton(
                                  child: Text("initialize"),
                                  onPressed: () async {
                                    await _filamentController.loadSkybox(
                                        "assets/default_env/default_env_skybox.ktx",
                                        "assets/default_env/default_env_ibl.ktx");
                                    await _filamentController.loadGltf(
                                        "assets/caleb_mouth_morph_target.gltf",
                                        "assets");
                                    _targets = await _filamentController
                                        .getTargetNames("CC_Base_Body");
                                    setState(() {});

                                    _filamentController.createMorpher(
                                        "CC_Base_Body", [1, 7, 8]);
                                  }),
                              Checkbox(
                                  value: _rotate,
                                  onChanged: (v) {
                                    setState(() {
                                      _rotate = v == true;
                                    });
                                  }),
                              ElevatedButton(
                                  onPressed: () =>
                                      _filamentController.zoom(30.0),
                                  child: const Text("-")),
                              ElevatedButton(
                                  onPressed: () =>
                                      _filamentController.zoom(-30.0),
                                  child: const Text("+")),
                              ElevatedButton(
                                  onPressed: () =>
                                      _filamentController.playAnimation(0),
                                  child: const Text("Play"))
                            ])),
                        Column(
                          children: _targets
                              .asMap()
                              .map((i, t) => MapEntry(
                                  i,
                                  Row(children: [
                                    Text(t),
                                    Slider(
                                        min: 0,
                                        max: 1,
                                        divisions: 10,
                                        value: weights[i],
                                        onChanged: (v) {
                                          setState(() {
                                            weights[i] = v;
                                            _filamentController
                                                .applyWeights(weights);
                                          });
                                        })
                                  ])))
                              .values
                              .toList(),
                        )
                      ],
                    ),
                  )),
            ])),
      ),
    );
  }
}

// ElevatedButton(
//     child: Text("load skybox"),
//     onPressed: () {
//       _filamentController.loadSkybox(
//           "assets/default_env/default_env_skybox.ktx",
//           "assets/default_env/default_env_ibl.ktx");
//     }),
// ElevatedButton(
//     child: Text("load gltf"),
//     onPressed: () {
//       _filamentController.loadGltf(
//           "assets/guy.gltf", "assets", "Material");
//     }),
// ElevatedButton(
//     child: Text("create morpher"),
//     onPressed: () {
//       _filamentController.createMorpher(
//           "CC_Base_Body.003", "CC_Base_Body.003",
//           materialName: "Material");
//     }),

import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:mimetic_filament/filament_controller.dart';
import 'package:mimetic_filament/view/filament_widget.dart';

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

  double _zoomValue = 0;
  int _primitiveIndex = 0;
  double _weight = 0.0;

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
              _filamentController.panStart(
                  details.localPosition.dx, details.localPosition.dy);
            },
            onPanUpdate: (details) {
              _filamentController.panUpdate(
                  details.localPosition.dx, details.localPosition.dy);
            },
            onPanEnd: (d) {
              _filamentController.panEnd();
            },
            child: Stack(children: [
              FilamentWidget(controller: _filamentController),
              Column(children: [
                ElevatedButton(
                    child: Text("initialize"),
                    onPressed: () {
                      _filamentController.initialize(
                          materialPath: "assets/compiled.mat");
                      _filamentController.loadSkybox(
                          "assets/default_env/default_env_skybox.ktx",
                          "assets/default_env/default_env_ibl.ktx");
                      _filamentController.loadGltf(
                          "assets/guy.gltf", "assets", "Material");
                      _filamentController.createMorpher(
                          "CC_Base_Body.003", "CC_Base_Body.003",
                          materialName: "Material");
                    }),
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
                Row(children: [
                  Container(
                      padding: EdgeInsets.all(10),
                      color: Colors.white,
                      child: Text(_primitiveIndex.toString())),
                  ElevatedButton(
                      child: Text("+"),
                      onPressed: () {
                        setState(() {
                          _primitiveIndex = min(_primitiveIndex + 1, 5);
                        });
                      }),
                  ElevatedButton(
                      child: Text("-"),
                      onPressed: () {
                        setState(() {
                          _primitiveIndex = max(_primitiveIndex - 1, 0);
                        });
                      }),
                ]),
                Slider(
                    min: 0,
                    max: 1,
                    divisions: 10,
                    value: _weight,
                    onChanged: (v) {
                      setState(() {
                        _weight = v;
                        _filamentController.applyWeights(
                            List.filled(255, _weight), _primitiveIndex.toInt());
                        print("Set $_primitiveIndex to $_weight");
                      });
                    }),
                Row(children: [
                  ElevatedButton(
                      onPressed: () => _filamentController.zoom(1.0),
                      child: Text("+")),
                  ElevatedButton(
                      onPressed: () => _filamentController.zoom(-1.0),
                      child: Text("-"))
                ])
              ]),
            ])),
      ),
    );
  }
}

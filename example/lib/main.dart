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
  String _platformVersion = 'Unknown';

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
          FilamentWidget(controller: _filamentController),
          Column(children: [
            ElevatedButton(
                child: Text("initialize"),
                onPressed: () {
                  _filamentController.initialize();
                }),
            ElevatedButton(
                child: Text("load asset"),
                onPressed: () {
                  _filamentController.loadSkybox(
                      "assets/default_env/default_env_skybox.ktx",
                      "assets/default_env/default_env_ibl.ktx");
                }),
          ]),
        ]),
      ),
    );
  }
}

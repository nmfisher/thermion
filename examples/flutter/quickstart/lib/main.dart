import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

import 'package:vector_math/vector_math_64.dart' as v;
import 'dart:math';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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
  bool _loaded = false;
  late ThermionFlutterPlugin _thermionFlutterPlugin;
  late Future<ThermionViewer> _thermionViewer;

  @override
  void initState() {
    super.initState();
    _thermionFlutterPlugin = ThermionFlutterPlugin();
    _thermionViewer = _thermionFlutterPlugin.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(child: ThermionWidget(plugin: _thermionFlutterPlugin)),
      if (!_loaded)
        Center(
            child: ElevatedButton(
                child: const Text("Load"),
                onPressed: () async {
                  var viewer = await _thermionViewer;
                  await viewer.loadSkybox("assets/default_env_skybox.ktx");
                  await viewer.loadGlb("assets/cube.glb");

                  await viewer.setCameraPosition(0, 1, 10);
                  await viewer.setCameraRotation(v.Quaternion.axisAngle(
                          v.Vector3(1, 0, 0), -30 / 180 * pi) *
                      v.Quaternion.axisAngle(
                          v.Vector3(0, 1, 0), 15 / 180 * pi));
                  await viewer.addLight(
                      LightType.SUN, 7500, 50000, 0, 0, 0, 1, -1, -1);
                  await viewer.setRendering(true);
                  _loaded = true;
                  setState(() {});
                }))
    ]);
  }
}

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
  ThermionViewer? _thermionViewer;

  @override
  void initState() {
    super.initState();
  }

  ThermionFlutterTexture? _texture;

  Future _load() async {
    var viewer = await ThermionFlutterPlugin.createViewer();
    _thermionViewer = viewer;
    _thermionViewer!.loadSkybox("assets/default_env_skybox.ktx");
    _thermionViewer!.loadGlb("assets/cube.glb");

    _thermionViewer!.setCameraPosition(0, 1, 10);
    _thermionViewer!.setCameraRotation(
        v.Quaternion.axisAngle(v.Vector3(1, 0, 0), -30 / 180 * pi) *
            v.Quaternion.axisAngle(v.Vector3(0, 1, 0), 15 / 180 * pi));
    _thermionViewer!.addLight(LightType.SUN, 7500, 50000, 0, 0, 0, 1, -1, -1);
    _thermionViewer!.setRendering(true);
    _loaded = true;

    setState(() {});
  }

  Future _unload() async {
    await ThermionFlutterPlugin.destroyTexture(_texture!);
    var viewer = _thermionViewer!;
    _thermionViewer = null;
    setState(() {});
    await viewer.dispose();
    _loaded = false;
    setState(() {});
  }

  Widget _loadButton() {
    return Center(
        child: ElevatedButton(child: const Text("Load"), onPressed: _load));
  }

  Widget _unloadButton() {
    return Center(
        child: ElevatedButton(child: const Text("Unload"), onPressed: _unload));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      if (_thermionViewer != null)
        Positioned.fill(child: ThermionWidget(viewer: _thermionViewer!)),
      if (!_loaded) _loadButton(),
      if (_loaded) _unloadButton(),
    ]);
  }
}

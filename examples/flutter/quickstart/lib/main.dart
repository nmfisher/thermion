import 'dart:async';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

void main() {
  runApp(const MyApp());
  Logger.root.onRecord.listen((record) {
    print(record);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thermion Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Thermion Demo Home Page'),
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
  @override
  void initState() {
    super.initState();
  }

  ThermionViewer? _thermionViewer;

  Future _load() async {
    if (_thermionViewer != null) {
      throw Exception();
    }

    // A [ThermionViewer] is the main interface for controlling asset loading,
    // rendering, camera and lighting.
    //
    // When you no longer need a rendering surface, call [dispose] on this instance.
    //
    // Only a single instance can be active at a given time; trying to construct
    // a new instance before the old instance has been disposed will throw an exception.
    _thermionViewer = await ThermionFlutterPlugin.createViewer();

    // Geometry and models are represented as "entities". Here, we load a glTF
    // file containing a plain cube.
    // By default, all paths are treated as asset paths. To load from a file 
    // instead, use file:// URIs.
    var entity =
        await _thermionViewer!.loadGlb("assets/cube.glb", keepData: true);

    // Thermion uses a right-handed coordinate system where +Y is up and -Z is
    // "into" the screen.
    // By default, the camera is located at (0,0,0) looking at (0,0,-1); this
    // would place it directly inside the cube we just loaded.
    //
    // Let's move the camera to (0,0,10) to ensure the cube is visible in the
    // viewport.
    await _thermionViewer!.setCameraPosition(0, 0, 10);

    // Without a light source, your scene will be totally black. Let's load a skybox
    // (a cubemap image that is rendered behind everything else in the scene)
    // and an image-based indirect light that has been precomputed from the same
    // skybox.
    await _thermionViewer!.loadSkybox("assets/default_env_skybox.ktx");
    await _thermionViewer!.loadIbl("assets/default_env_ibl.ktx");

    // Finally, you need to explicitly enable rendering. Setting rendering to
    // false is designed to allow you to pause rendering to conserve battery life
    await _thermionViewer!.setRendering(true);

    setState(() {});
  }

  Future _unload() async {
    // when you are no longer need the 3D viewport:
    // 1) remove all instances of ThermionWidget from the widget tree
    // 2) remove all local references to the ThermionViewer
    // 3) call dispose on the ThermionViewer
    var viewer = _thermionViewer!;
    _thermionViewer = null;
    setState(() {});

    await viewer.dispose();
  }

  Widget _loadButton() {
    return Center(
        child: ElevatedButton(onPressed: _load, child: const Text("Load")));
  }

  Widget _unloadButton() {
    return Align(
        alignment: Alignment.bottomCenter,
        child: ElevatedButton(onPressed: _unload, child: const Text("Unload")));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      if (_thermionViewer != null)
        Positioned.fill(
            child: ThermionWidget(
          viewer: _thermionViewer!,
        )),
      Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:Column(
              crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
            if (_thermionViewer == null) _loadButton(),
            if (_thermionViewer != null) _unloadButton(),
          ])))
    ]);
  }
}

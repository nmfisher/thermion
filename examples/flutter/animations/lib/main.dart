import 'dart:async';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart' hide View;
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
      title: 'Thermion Animation Demo',
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
  late DelegateInputHandler _inputHandler;
  ThermionViewer? _thermionViewer;

  ThermionAsset? _asset;
  final _droneUri = "assets/BusterDrone/scene.gltf";
  final _cubeUri = "assets/cube_with_morph_targets.glb";
  String? _loaded;

  final gltfAnimations = <String>[];
  int selectedGltfAnimation = -1;

  Future _load(String? uri) async {
    if (_asset != null) {
      await _thermionViewer!.destroyAsset(_asset!);
      _asset = null;
    }
    if (uri == null) {
      return;
    }
    _asset = await _thermionViewer!.loadGltf(uri);
    await _asset!.transformToUnitCube();
    final animations = await _asset!.getGltfAnimationNames();
    final durations = await Future.wait(List.generate(
        animations.length, (i) => _asset!.getGltfAnimationDuration(i)));

    final labels = animations
        .asMap()
        .map((index, animation) =>
            MapEntry(index, "$animation (${durations[index]}s"))
        .values;
    gltfAnimations.clear();
    gltfAnimations.addAll(labels);
    selectedGltfAnimation = 0;
    _loaded = uri;
    setState(() {});
  }

  Future _playGltfAnimation() async {
    if (selectedGltfAnimation == -1) {
      throw Exception();
    }
    await _asset!.playGltfAnimation(selectedGltfAnimation);
  }

  Future _stopGltfAnimation() async {
    if (selectedGltfAnimation == -1) {
      throw Exception();
    }
    await _asset!.stopGltfAnimation(selectedGltfAnimation);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _thermionViewer = await ThermionFlutterPlugin.createViewer();

      final camera = await _thermionViewer!.getActiveCamera();
      await camera.lookAt(Vector3(0, 0, 10));

      await _thermionViewer!.loadSkybox("assets/default_env_skybox.ktx");
      await _thermionViewer!.loadIbl("assets/default_env_ibl.ktx");
      await _thermionViewer!.setPostProcessing(true);
      await _thermionViewer!.setRendering(true);

      _inputHandler = DelegateInputHandler.fixedOrbit(_thermionViewer!);
      await _load(_droneUri);

      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_thermionViewer == null) {
      return Container();
    }
    return Stack(children: [
      Positioned.fill(
          child: ThermionListenerWidget(
              inputHandler: _inputHandler,
              child: ThermionWidget(
                viewer: _thermionViewer!,
              ))),
      Card(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Row(children: [
                Text("Asset: "),
                DropdownButton<String>(
                    value: _loaded,
                    items: [_droneUri, _cubeUri]
                        .map((uri) => DropdownMenuItem<String>(
                            value: uri,
                            child: Text(
                              uri,
                              style: TextStyle(fontSize: 12),
                            )))
                        .toList(),
                    onChanged: _load),
                Text("Animation: "),
                DropdownButton<String>(
                    value: selectedGltfAnimation == -1
                        ? null
                        : gltfAnimations[selectedGltfAnimation],
                    items: gltfAnimations
                        .map((animation) => DropdownMenuItem<String>(
                            value: animation,
                                child: Text(
                              animation,
                              style: TextStyle(fontSize: 12),
                            )))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        selectedGltfAnimation = -1;
                      } else {
                        selectedGltfAnimation = gltfAnimations.indexOf(value);
                      }
                    }),
                IconButton(
                    onPressed: _playGltfAnimation,
                    icon: const Icon(Icons.play_arrow)),
                IconButton(
                    onPressed: _stopGltfAnimation, icon: const Icon(Icons.stop))
              ])))
    ]);
  }
}

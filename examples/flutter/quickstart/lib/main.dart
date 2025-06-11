import 'package:flutter/foundation.dart';
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
    if (kIsWeb) {
      ThermionFlutterPlatform.instance
          .setOptions(const ThermionFlutterWebOptions(importCanvasAsWidget: true));
    }
  }

  bool _showViewer = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(children: [
      if (_showViewer)
        Positioned.fill(
            child: ViewerWidget(
          assetPath: "assets/cube.glb",
          skyboxPath: "assets/default_env_skybox.ktx",
          iblPath: "assets/default_env_ibl.ktx",
          transformToUnitCube: true,
          initialCameraPosition: Vector3(0, 0, 6),
          background: Colors.blue,
          manipulatorType: ManipulatorType.ORBIT,
          onViewerAvailable: (viewer) async {
            await Future.delayed(const Duration(seconds: 5));
            await viewer.removeSkybox();
          },
          initial: Container(
            color: Colors.red,
          ),
        )),
      Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showViewer = !_showViewer;
                    });
                  },
                  child: Text(_showViewer ? "Remove viewer" : "Show viewer"))))
    ]));
  }
}

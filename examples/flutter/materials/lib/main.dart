import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

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
  ThermionViewer? _viewer;
  late ThermionAsset _asset;
  late MaterialInstance _materialInstance;

  @override
  void initState() {
    super.initState();
    ThermionFlutterPlugin.createViewer().then((viewer) async {
      _viewer = viewer;
      await _viewer!.setPostProcessing(true);
      _materialInstance = await _viewer!.createUnlitMaterialInstance();
      _asset = await _viewer!.createGeometry(
          GeometryHelper.cube(normals: false, uvs: false),
          materialInstances: [_materialInstance]);

      await _viewer!
          .setTransform(_asset.entity, Matrix4.translation(Vector3.all(2)));
      await _materialInstance.setParameterFloat4(
          "baseColorFactor", 0.0, 1.0, 0.0, 1.0);
      await _viewer!.setCameraPosition(0, 0, 10);
      await _viewer!.setRendering(true);
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(children: [
      if (_viewer == null) CircularProgressIndicator(),
      if (_viewer != null) ...[
        Positioned.fill(child: ThermionWidget(viewer: _viewer!)),
        Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
                padding: EdgeInsets.all(12),
                child: ElevatedButton(
                    onPressed: () async {
                      await _materialInstance.setParameterFloat4(
                          "baseColorFactor", 1.0, 0.0, 0.0, 1.0);
                    },
                    child: Text("Set material property (baseColorFactor)"))))
      ]
    ]));
  }
}

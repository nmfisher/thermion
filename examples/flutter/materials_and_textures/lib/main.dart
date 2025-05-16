import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter/thermion_flutter.dart' as t;
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';

void main() {
  Logger.root.onRecord.listen((record) {
    print(record);
  });
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      color: Colors.transparent,
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
  bool green = true;
  bool unlit = true;

  t.Texture? _texture;
  t.Texture? _textureSampler;
  t.LinearImage? _image;
  late MaterialInstance _unlitMaterial;
  late MaterialInstance _litMaterial;

  late InputHandler _inputHandler;

  @override
  void initState() {
    super.initState();
    ThermionFlutterOptions? options;
    if (kIsWeb) {
      // ThermionFlutterPlatform.instance.setOptions(ThermionFlutterWebOptions(createCanvas:true, importCanvasAsWidget:false));
    }
    ThermionFlutterPlugin.createViewer().then((viewer) async {

      _viewer = viewer;
      
      _inputHandler = DelegateInputHandler.fixedOrbit(
        _viewer!,
        sensitivity: InputSensitivityOptions(mouseSensitivity: 0.01),
      );


      await _viewer!.setPostProcessing(true);

      _unlitMaterial =
          await FilamentApp.instance!.createUnlitMaterialInstance();
      _litMaterial =
          await FilamentApp.instance!.createUbershaderMaterialInstance();
      await _viewer!.addDirectLight(
        DirectLight.sun(
          intensity: 50000,
          direction: Vector3(1, -1, -1).normalized(),
        ),
      );
      await _viewer!.loadSkybox("assets/default_env_skybox.ktx");
      await _viewer!.loadIbl("assets/default_env_ibl.ktx");

      for (var material in [_unlitMaterial, _litMaterial]) {
        await material.setParameterInt("baseColorIndex", -1);
        await material.setParameterFloat4(
          "baseColorFactor",
          0.0,
          1.0,
          0.0,
          1.0,
        );
      }

      _asset = await _viewer!.createGeometry(
        GeometryHelper.cube(),
        materialInstances: [_unlitMaterial],
      );

      final view = await viewer.getActiveCamera();
      await view.lookAt(Vector3(0, 0, 5));

      await _viewer!.setRendering(true);
      setState(() {});
    });
  }

  Future _setMaterialTexture(MaterialInstance materialInstance) async {
    await _textureSampler?.dispose();
    await _texture?.dispose();
    await _image?.destroy();

    await materialInstance.setParameterInt("baseColorIndex", 0);

    var imageBuffer = await rootBundle.load("assets/background.png");

    var imageData = imageBuffer.buffer.asUint8List(imageBuffer.offsetInBytes);

    _image = await FilamentApp.instance!.decodeImage(imageData);

    var width = await _image!.getWidth();
    var height = await _image!.getHeight();

    _texture = await FilamentApp.instance!.createTexture(width, height);

    await _texture!.setLinearImage(
      _image!,
      PixelDataFormat.RGBA,
      PixelDataType.FLOAT,
    );

    final textureSampler = await FilamentApp.instance!.createTextureSampler();

    await materialInstance.setParameterTexture(
      "baseColorMap",
      _texture!,
      textureSampler,
    );
  }

  Future _setActiveMaterialColor() async {
    var active = unlit ? _unlitMaterial : _litMaterial;

    await active.setParameterFloat4(
      "baseColorFactor",
      green ? 0.0 : 1.0,
      green ? 1.0 : 0.0,
      0.0,
      1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          if (_viewer == null) CircularProgressIndicator(),
          if (_viewer != null) ...[
            Positioned.fill(
              child: ThermionListenerWidget(
                inputHandler: _inputHandler,
                child: ThermionWidget(viewer: _viewer!),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        green = !green;
                        setState(() {});
                        _setActiveMaterialColor();
                      },
                      child: Text(
                        "Toggle baseColorFactor (currently ${green ? "green" : "red"}",
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        unlit = !unlit;
                        setState(() {});
                        await _asset.setMaterialInstanceAt(
                          unlit ? _unlitMaterial : _litMaterial,
                        );
                        _setActiveMaterialColor();
                      },
                      child: Text("Use ${unlit ? "lit" : "unlit"} material"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        var materialInstance =
                            await _asset.getMaterialInstanceAt();
                        await _setMaterialTexture(materialInstance);
                      },
                      child: Text("Apply texture"),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

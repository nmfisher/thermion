import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter/thermion_flutter.dart' as t;
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
  bool green = true;
  bool unlit = true;

  t.Texture? _texture;
  t.Texture? _textureSampler;
  t.LinearImage? _image;
  late MaterialInstance _unlitMaterial;
  late MaterialInstance _litMaterial;

  @override
  void initState() {
    super.initState();
    ThermionFlutterPlugin.createViewer().then((viewer) async {
      _viewer = viewer;
      await _viewer!.setPostProcessing(true);

      _unlitMaterial = await _viewer!.createUnlitMaterialInstance();
      _litMaterial = await _viewer!.createUbershaderMaterialInstance();
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

      await _viewer!.setCameraPosition(0, 0, 5);
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
    _image = await _viewer!.decodeImage(imageData);
    var width = await _image!.getWidth();
    var height = await _image!.getHeight();

    _texture = await _viewer!.createTexture(width, height);
    await _texture!.setLinearImage(
      _image!,
      PixelDataFormat.RGBA,
      PixelDataType.FLOAT,
    );

    final textureSampler = await _viewer!.createTextureSampler();
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
      body: Stack(
        children: [
          if (_viewer == null) CircularProgressIndicator(),
          if (_viewer != null) ...[
            Positioned.fill(
              child: ThermionListenerWidget(
                inputHandler: DelegateInputHandler.fixedOrbit(_viewer!),
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
                        _setActiveMaterialColor();
                      },
                      child: Text(
                        "Set baseColorFactor to ${green ? "red" : "green"}",
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        unlit = !unlit;
                        setState(() {
                          
                        });
                        await _asset.setMaterialInstanceAt(
                          unlit ? _unlitMaterial : _litMaterial,
                        );
                        _setActiveMaterialColor();
                      },
                      child: Text("Use ${unlit ? "lit" : "unlit"} material"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        var materialInstance = await _viewer!
                            .getMaterialInstanceAt(_asset.entity, 0);
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

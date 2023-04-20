import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as v;

import 'package:polyvox_filament/filament_controller.dart';
import 'package:polyvox_filament/filament_gesture_detector.dart';
import 'package:polyvox_filament/filament_widget.dart';
import 'package:polyvox_filament/animations/animation_builder.dart';
import 'package:polyvox_filament/animations/animations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  late FilamentController _filamentController;

  FilamentEntity? _cube;
  FilamentEntity? _flightHelmet;
  FilamentEntity? _light;

  final weights = List.filled(255, 0.0);
  List<String> _targetNames = [];
  List<String> _animationNames = [];
  bool _loop = false;
  bool _vertical = false;
  bool _rendering = false;
  int _framerate = 60;

  @override
  void initState() {
    super.initState();
    _filamentController = FilamentController(this);
  }

  void onClick(int index) async {
    switch (index) {
      case -1:
        await _filamentController.initialize();
        break;
      case -2:
        _filamentController.render();
        break;
      case -4:
        setState(() {
          _rendering = !_rendering;
          _filamentController.setRendering(_rendering);
        });
        break;
      case -5:
        setState(() {
          _framerate = _framerate == 60 ? 30 : 60;
          _filamentController.setFrameRate(_framerate);
        });
        break;

      case 0:
        _filamentController.setBackgroundImage('assets/background.ktx');
        break;
      case 1:
        _filamentController
            .loadSkybox('assets/default_env/default_env_skybox.ktx');
        break;
      case -3:
        _filamentController.loadIbl('assets/default_env/default_env_ibl.ktx');
        break;
      case 2:
        _filamentController.removeSkybox();
        break;
      case 3:
        _cube = _filamentController.loadGlb('assets/cube.glb');
        _animationNames = _filamentController.getAnimationNames(_cube!);
        break;

      case 4:
        if (_cube != null) {
          _filamentController.removeAsset(_cube!);
        }
        _cube = _filamentController.loadGltf('assets/cube.gltf', 'assets');
        break;
      case 5:
        _flightHelmet ??= _filamentController.loadGltf(
            'assets/FlightHelmet/FlightHelmet.gltf', 'assets/FlightHelmet');
        break;
      case 6:
        _filamentController.removeAsset(_cube!);
        break;

      case 7:
        _filamentController.setMorphTargetWeights(_cube!, List.filled(8, 1.0));
        break;
      case 8:
        _filamentController.setMorphTargetWeights(_cube!, List.filled(8, 0));
        break;
      case 9:
        for (int i = 0; i < _animationNames.length; i++) {
          _filamentController.playAnimation(_cube!, i, loop: _loop);
        }

        break;
      case 10:
        _filamentController.stopAnimation(_cube!, 0);
        break;
      case 11:
        setState(() {
          _loop = !_loop;
        });
        break;
      case 14:
        _filamentController.setCamera(_cube!, "Camera_Orientation");
        break;
      case 15:
        final animation = AnimationBuilder(
                controller: _filamentController,
                asset: _cube!,
                framerate: 30,
                meshName: "Cube.001")
            .setDuration(4)
            .interpolateMorphWeights(0, 4, 0, 1)
            // .interpolateBoneTransform(
            //     "Bone.001",
            //     "Cube.001",
            //     2,
            //     4,
            //     v.Vector3.zero(),
            //     v.Vector3.zero(),
            //     // Vec3(x: 1, y: 1, z: 1),
            //     v.Quaternion(0, 0, 0, 1),
            //     v.Quaternion(1, 1, 1, 1))
            // Quaternion(x: 1, y: 1, z: 1, w: 1))
            .set();
        break;
      case 16:
        _targetNames = _filamentController.getMorphTargetNames(_cube!, "Cube");
        setState(() {});
        break;
      case 17:
        _animationNames = _filamentController.getAnimationNames(_cube!);
        setState(() {});

        break;
      case 18:
        _filamentController.panStart(1, 1);
        _filamentController.panUpdate(1, 2);
        _filamentController.panEnd();
        break;
      case 19:
        _filamentController.panStart(1, 1);
        _filamentController.panUpdate(0, 0);
        _filamentController.panEnd();
        break;
      case 20:
        _filamentController.clearAssets();
        break;
      case 21:
        _filamentController.setTexture(_cube!, "assets/background.png");
        break;
      case 22:
        _filamentController.transformToUnitCube(_cube!);
        break;
      case 23:
        _filamentController.setPosition(_cube!, 1.0, 1.0, -1.0);
        break;
      case 24:
        _filamentController.setRotation(_cube!, pi / 2, 0.0, 1.0, 0.0);
        break;
      case 25:
        setState(() {
          _vertical = !_vertical;
        });
        break;
      case 26:
        _filamentController.setCameraPosition(0, 0, 3);
        _filamentController.setCameraRotation(0, 0, 1, 0);
        break;
      case 27:
        _framerate = _framerate == 60 ? 30 : 60;
        _filamentController.setFrameRate(_framerate);
        break;
      case 28:
        _filamentController.setBackgroundImagePosition(25, 25);
        break;
      case 29:
        _light = _filamentController.addLight(
            1, 6500, 15000000, 0, 1, 0, 0, -1, 0, true);
        _light = _filamentController.addLight(
            2, 6500, 15000000, 0, 0, 1, 0, 0, -1, true);
        break;
      case 30:
        if (_light != null) {
          _filamentController.removeLight(_light!);
        }
        break;
      case 31:
        _filamentController.clearLights();
        break;
      case 32:
        _filamentController.setCameraModelMatrix(List<double>.filled(16, 1.0));

        //  _filamentController.setBoneTransform(
        //     _cube!,
        //     "Bone.001",
        //     "Cube.001",
        //     BoneTransform([Vec3(x: 0, y: 0.0, z: 0.0)],
        //         [Quaternion(x: 1, y: 1, z: 1, w: 1)]));
        break;
    }
  }

  Widget _item({int value = 0, Widget? child = null}) {
    return GestureDetector(
        onTap: () {
          onClick(value);
        },
        child: Container(
            margin: EdgeInsets.symmetric(vertical: 10), child: child));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        // showPerformanceOverlay: true,
        color: Colors.white,
        home: Scaffold(
            backgroundColor: Colors.white,
            body: Row(children: [
              SingleChildScrollView(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                    Text(
                        "Target names : ${_targetNames.join(",")}, Animation names : ${_animationNames.join(",")}"),
                    _item(value: -1, child: Text("initialize")),
                    _item(value: -2, child: Text("render")),
                    _item(value: -4, child: Text("Rendering: $_rendering ")),
                    _item(value: -5, child: Text("$_framerate fps")),
                    _item(value: 0, child: Text("load background image")),
                    _item(
                      value: 1,
                      child: Text('load skybox'),
                    ),
                    _item(
                      value: -3,
                      child: Text('load IBL'),
                    ),
                    _item(
                      value: 2,
                      child: Text('remove skybox'),
                    ),
                    _item(value: 3, child: Text('load cube GLB')),
                    _item(value: 4, child: Text('load cube GLTF')),
                    _item(value: 21, child: Text('swap cube texture')),
                    _item(value: 22, child: Text('transform to unit cube')),
                    _item(value: 23, child: Text('set position to 1, 1, -1')),
                    _item(
                        value: 32,
                        child: Text('set bone transform to 1, 1, -1')),
                    _item(value: 24, child: Text('rotate by pi around Y axis')),
                    _item(value: 5, child: Text('load flight helmet')),
                    _item(value: 6, child: Text('remove cube')),
                    _item(value: 20, child: Text('clear all assets')),
                    _item(value: 7, child: Text('set all weights to 1')),
                    _item(value: 8, child: Text('set all weights to 0')),
                    _item(value: 9, child: Text('play all animations')),
                    _item(value: 10, child: Text('stop animations')),
                    _item(
                        value: 11,
                        child: Text(
                            _loop ? "don't loop animation" : "loop animation")),
                    _item(value: 14, child: Text('set camera')),
                    _item(value: 15, child: Text('animate weights')),
                    _item(value: 16, child: Text('get target names')),
                    _item(value: 17, child: Text('get animation names')),
                    _item(value: 18, child: Text('pan left')),
                    _item(value: 19, child: Text('pan right')),
                    _item(
                        value: 25,
                        child: Text(
                            _vertical ? 'set horizontal' : 'set vertical')),
                    _item(value: 26, child: Text('set camera pos to 0,0,3')),
                    _item(value: 27, child: Text('toggle framerate')),
                    _item(value: 28, child: Text('set bg image pos')),
                    _item(value: 29, child: Text('add light')),
                    _item(value: 30, child: Text('remove light')),
                    _item(value: 31, child: Text('clear all lights')),
                    _item(value: 32, child: Text('set camera model matrix')),
                  ])),
              Container(
                  width: _vertical ? 200 : 400,
                  height: _vertical ? 400 : 200,
                  alignment: Alignment.center,
                  child: SizedBox(
                    child: FilamentGestureDetector(
                        showControlOverlay: true,
                        controller: _filamentController,
                        child: FilamentWidget(
                          controller: _filamentController,
                        )),
                  )),
            ])));
  }
}

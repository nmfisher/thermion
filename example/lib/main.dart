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

class _MyAppState extends State<MyApp> {
  final FilamentController _filamentController = PolyvoxFilamentController();

  FilamentAsset? _cube;
  FilamentAsset? _flightHelmet;
  FilamentLight? _light;

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
  }

  void onClick(int index) async {
    switch (index) {
      case -1:
        await _filamentController.initialize();
        break;
      case -2:
        await _filamentController.render();
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
        await _filamentController.setBackgroundImage('assets/background.ktx');
        break;
      case 1:
        await _filamentController
            .loadSkybox('assets/default_env/default_env_skybox.ktx');
        break;
      case -3:
        await _filamentController
            .loadIbl('assets/default_env/default_env_ibl.ktx');
        break;
      case 2:
        await _filamentController.removeSkybox();
        break;
      case 3:
        _cube = await _filamentController.loadGlb('assets/cube.glb');

        _animationNames = await _filamentController.getAnimationNames(_cube!);
        break;

      case 4:
        if (_cube != null) {
          await _filamentController.removeAsset(_cube!);
        }
        _cube =
            await _filamentController.loadGltf('assets/cube.gltf', 'assets');
        print(await _filamentController.getAnimationNames(_cube!));
        break;
      case 5:
        if (_flightHelmet == null) {
          _flightHelmet = await _filamentController.loadGltf(
              'assets/FlightHelmet/FlightHelmet.gltf', 'assets/FlightHelmet');
        }
        break;
      case 6:
        await _filamentController.removeAsset(_cube!);
        break;

      case 7:
        await _filamentController.setMorphTargetWeights(
            _cube!, List.filled(8, 1.0));
        break;
      case 8:
        await _filamentController.setMorphTargetWeights(
            _cube!, List.filled(8, 0));
        break;
      case 9:
        _filamentController.playAnimations(
            _cube!, List.generate(_animationNames.length, (i) => i),
            loop: _loop);
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
        throw Exception("FIXME");
        // final animation = AnimationBuilder()
        //     .setFramerate(30)
        //     .setDuration(4)
        //     .setNumMorphWeights(8)
        //     .interpolateMorphWeights(0, 4, 0, 1)
        //     .interpolateBoneTransform(
        //         "Bone.001",
        //         "Cube.001",
        //         2,
        //         4,
        //         v.Vector3.zero(),
        //         v.Vector3.zero(),
        //         // Vec3(x: 1, y: 1, z: 1),
        //         v.Quaternion(0, 0, 0, 1),
        //         v.Quaternion(1, 1, 1, 1))
        //     // Quaternion(x: 1, y: 1, z: 1, w: 1))
        //     .build();

        // _filamentController.setAnimation(_cube!, animation);
        break;
      case 16:
        _targetNames =
            await _filamentController.getMorphTargetNames(_cube!, "Cube");
        setState(() {});
        break;
      case 17:
        _animationNames = await _filamentController.getAnimationNames(_cube!);
        setState(() {});

        break;
      case 18:
        await _filamentController.panStart(1, 1);
        await _filamentController.panUpdate(1, 2);
        await _filamentController.panEnd();
        break;
      case 19:
        await _filamentController.panStart(1, 1);
        await _filamentController.panUpdate(0, 0);
        await _filamentController.panEnd();
        break;
      case 20:
        await _filamentController.clearAssets();
        break;
      case 21:
        await _filamentController.setTexture(_cube!, "assets/background.png");
        break;
      case 22:
        await _filamentController.transformToUnitCube(_cube!);
        break;
      case 23:
        await _filamentController.setPosition(_cube!, 1.0, 1.0, -1.0);
        break;
      case 24:
        await _filamentController.setRotation(_cube!, pi / 2, 0.0, 1.0, 0.0);
        break;
      case 25:
        setState(() {
          _vertical = !_vertical;
        });
        break;
      case 26:
        await _filamentController.setCameraPosition(0, 0, 3);
        await _filamentController.setCameraRotation(0, 0, 1, 0);
        break;
      case 27:
        _framerate = _framerate == 60 ? 30 : 60;
        await _filamentController.setFrameRate(_framerate);
        break;
      case 28:
        await _filamentController.setBackgroundImagePosition(25, 25);
        break;
      case 29:
        _light = await _filamentController.addLight(
            1, 6500, 15000000, 0, 1, 0, 0, -1, 0, true);
        _light = await _filamentController.addLight(
            2, 6500, 15000000, 0, 0, 1, 0, 0, -1, true);
        break;
      case 30:
        if (_light != null) {
          await _filamentController.removeLight(_light!);
        }
        break;
      case 31:
        await _filamentController.clearLights();
        break;
      case 32:
        await _filamentController
            .setCameraModelMatrix(List<double>.filled(16, 1.0));

        // await _filamentController.setBoneTransform(
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

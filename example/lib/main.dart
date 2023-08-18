import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math.dart' as v;

import 'package:polyvox_filament/filament_controller.dart';
import 'package:polyvox_filament/animations/bone_animation_data.dart';
import 'package:polyvox_filament/filament_gesture_detector.dart';
import 'package:polyvox_filament/filament_widget.dart';
import 'package:polyvox_filament/animations/animation_builder.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        // showPerformanceOverlay: true,
        color: Colors.white,
        home: Scaffold(backgroundColor: Colors.white, body: ExampleWidget()));
  }
}

class ExampleWidget extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _ExampleWidgetState();
  }
}

class _ExampleWidgetState extends State<ExampleWidget> {
  late FilamentController _filamentController;

  FilamentEntity? _cube;
  FilamentEntity? _flightHelmet;
  List<String>? _animations;
  FilamentEntity? _light;

  final weights = List.filled(255, 0.0);

  bool _loop = false;
  bool _vertical = false;
  bool _rendering = false;
  int _framerate = 60;

  @override
  void initState() {
    super.initState();
    _filamentController = FilamentController();
  }

  bool _initialized = false;

  bool _coneHidden = false;

  Widget _item(void Function() onTap, String text) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            color: Colors.transparent,
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    var children = [
      _initialized
          ? Container()
          : _item(() async {
              await _filamentController.initialize();
              setState(() {
                _initialized = true;
              });
            }, "initialize"),
      _item(() {
        _filamentController.render();
      }, "render"),
      _item(() {
        setState(() {
          _rendering = !_rendering;
          _filamentController.setRendering(_rendering);
        });
      }, "Rendering: $_rendering "),
      _item(() {
        setState(() {
          _framerate = _framerate == 60 ? 30 : 60;
          _filamentController.setFrameRate(_framerate);
        });
      }, "$_framerate fps"),
      _item(() {
        _filamentController.setBackgroundColor(Color(0xFF73C9FA));
      }, "set background color"),
      _item(() {
        _filamentController.setBackgroundImage('assets/background.ktx');
      }, "load background image"),
      _item(() {
        _filamentController
            .loadSkybox('assets/default_env/default_env_skybox.ktx');
      }, 'load skybox'),
      _item(() {
        _filamentController.loadIbl('assets/default_env/default_env_ibl.ktx');
      }, 'load IBL'),
      _item(
        () {
          _filamentController.removeSkybox();
        },
        'remove skybox',
      ),
      _item(() async {
        _cube = await _filamentController.loadGlb('assets/cube.glb');
        _animations = await _filamentController.getAnimationNames(_cube!);
        setState(() {});
      }, 'load cube GLB'),
      _item(() async {
        if (_coneHidden) {
          _filamentController.reveal(_cube!, "Cone");
        } else {
          _filamentController.hide(_cube!, "Cone");
        }
        setState(() {
          _coneHidden = !_coneHidden;
        });
      }, _coneHidden ? 'show cone' : 'hide cone'),
      _item(() async {
        if (_cube != null) {
          _filamentController.removeAsset(_cube!);
        }
        _cube =
            await _filamentController.loadGltf('assets/cube.gltf', 'assets');
      }, 'load cube GLTF'),
      _item(() async {
        _filamentController.setTexture(_cube!, "assets/background.png");
      }, 'swap cube texture'),
      _item(() async {
        _filamentController.transformToUnitCube(_cube!);
      }, 'transform to unit cube'),
      _item(() async {
        _filamentController.setPosition(_cube!, 1.0, 1.0, -1.0);
      }, 'set position to 1, 1, -1'),
      _item(() async {
        var frameData = Float32List.fromList(
            List<double>.generate(120, (i) => i / 120).expand((x) {
          var vals = List<double>.filled(7, x);
          vals[3] = 1.0;
          // vals[4] = 0;
          vals[5] = 0;
          vals[6] = 0;
          return vals;
        }).toList());

        _filamentController.setBoneAnimation(
            _cube!,
            BoneAnimationData(
                "Bone.001", ["Cube.001"], frameData, 1000.0 / 60.0));
        //     ,
        //     "Bone.001",
        //     "Cube.001",
        //     BoneTransform([Vec3(x: 0, y: 0.0, z: 0.0)],
        //         [Quaternion(x: 1, y: 1, z: 1, w: 1)]));
      }, 'construct bone animation'),
      _item(() async {
        _filamentController.removeAsset(_cube!);
      }, 'remove cube'),
      _item(() async {
        _filamentController.clearAssets();
      }, 'clear all assets'),
      _item(() async {
        var names =
            await _filamentController.getMorphTargetNames(_cube!, "Cylinder");
        await showDialog(
            context: context,
            builder: (ctx) {
              return Container(
                  height: 100,
                  width: 100,
                  color: Colors.white,
                  child: Text(names.join(",")));
            });
      }, "show morph target names for Cylinder"),
      _item(() {
        _filamentController.setMorphTargetWeights(
            _cube!, "Cylinder", List.filled(4, 1.0));
      }, "set Cylinder morph weights to 1"),
      _item(() {
        _filamentController.setMorphTargetWeights(
            _cube!, "Cylinder", List.filled(4, 0.0));
      }, "set Cylinder morph weights to 0.0"),
      _item(() async {
        var morphs =
            await _filamentController.getMorphTargetNames(_cube!, "Cylinder");
        final animation = AnimationBuilder(
                availableMorphs: morphs, framerate: 30, meshName: "Cylinder")
            .setDuration(4)
            .setMorphTargets(["Key 1", "Key 2"])
            .interpolateMorphWeights(0, 4, 0, 1)
            .build();
        _filamentController.setMorphAnimationData(_cube!, animation);
      }, "animate morph weights #1 and #2"),
      _item(() async {
        var morphs =
            await _filamentController.getMorphTargetNames(_cube!, "Cylinder");
        final animation = AnimationBuilder(
                availableMorphs: morphs, framerate: 30, meshName: "Cylinder")
            .setDuration(4)
            .setMorphTargets(["Key 3", "Key 4"])
            .interpolateMorphWeights(0, 4, 0, 1)
            .build();
        _filamentController.setMorphAnimationData(_cube!, animation);
      }, "animate morph weights #3 and #4"),
    ];
    if (_animations != null) {
      children.addAll(_animations!.map((a) => _item(() {
            _filamentController.playAnimation(_cube!, _animations!.indexOf(a),
                replaceActive: true, crossfade: 0.5);
          }, "play animation ${_animations!.indexOf(a)} (replace/fade)")));
      children.addAll(_animations!.map((a) => _item(() {
            _filamentController.playAnimation(_cube!, _animations!.indexOf(a),
                replaceActive: false);
          }, "play animation ${_animations!.indexOf(a)} (noreplace)")));
    }

    return Padding(
        padding: EdgeInsets.only(top: 20, left: 20),
        child: Row(children: [
          Expanded(
              child: SingleChildScrollView(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: children
                      // _item(24 () async { 'rotate by pi around Y axis'),
                      // _item(5 () async { 'load flight helmet'),

                      // _item(7 () async { 'set all weights to 1'),
                      // _item(8 () async { 'set all weights to 0'),
                      // _item(9 () async { 'play all animations'),
                      // _item(34 () async { 'play animation 0'),
                      // _item(34 () async { 'play animation 0 (noreplace)'),
                      // _item(35 () async { 'play animation 1'),
                      // _item(34 () async { 'play animation 0 (noreplace)'),
                      // _item(36 () async { 'play animation 2'),
                      // _item(34 () async { 'play animation 0 (noreplace)'),
                      // _item(36 () async { 'play animation 3'),
                      // _item(34 () async { 'play animation 3 (noreplace)'),
                      // _item(37 () async { 'stop animation 0'),
                      // _item(11 () async {
                      //     Text(
                      //         _loop ? "don't loop animation" : "loop animation")),
                      // _item(14 () async { 'set camera'),
                      // _item(15 () async { 'animate weights'),
                      // _item(16 () async { 'get target names'),
                      // _item(17 () async { 'get animation names'),
                      // _item(18 () async { 'pan left'),
                      // _item(19 () async { 'pan right'),
                      // _item(25 () async {
                      //     Text(_vertical ? 'set horizontal' : 'set vertical')),
                      // _item(26 () async { 'set camera pos to 0,0,3'),
                      // _item(27 () async { 'toggle framerate'),
                      // _item(28 () async { 'set bg image pos'),
                      // _item(29 () async { 'add light'),
                      // _item(30 () async { 'remove light'),
                      // _item(31 () async { 'clear all lights'),
                      // _item(32 () async { 'set camera model matrix'),
                      ))),
          Container(
            width: _vertical ? 200 : 400,
            height: _vertical ? 400 : 200,
            alignment: Alignment.center,
            child: FilamentGestureDetector(
                showControlOverlay: true,
                controller: _filamentController,
                child: FilamentWidget(
                  controller: _filamentController,
                )),
          ),
        ]));
  }
}

// case -1:


//         break;
//       case -2:
//         _filamentController.render();
//         break;
//       case -4:
//         setState(() {
//           _rendering = !_rendering;
//           _filamentController.setRendering(_rendering);
//         });
//         break;
//       case -5:
//         setState(() {
//           _framerate = _framerate == 60 ? 30 : 60;
//           _filamentController.setFrameRate(_framerate);
//         });
//         break;
//       case -6:
//         _filamentController.setBackgroundColor(Color(0xFF73C9FA));
//         break;


//       case 5:
//         _flightHelmet ??= await _filamentController.loadGltf(
//             'assets/FlightHelmet/FlightHelmet.gltf', 'assets/FlightHelmet');
//         break;

//       case 11:
//         setState(() {
//           _loop = !_loop;
//         });
//         break;
//       case 14:
//         _filamentController.setCamera(_cube!, "Camera_Orientation");
//         break;
//       case 15:

//         break;
//       case 17:
//         var animationNames =
//             await _filamentController.getAnimationNames(_cube!);

//         await showDialog(
//             context: context,
//             builder: (ctx) {
//               return Container(
//                   height: 100,
//                   width: 100,
//                   color: Colors.white,
//                   child: Text(animationNames.join(",")));
//             });

//         break;
//       case 18:
//         _filamentController.panStart(1, 1);
//         _filamentController.panUpdate(1, 2);
//         _filamentController.panEnd();
//         break;
//       case 19:
//         _filamentController.panStart(1, 1);
//         _filamentController.panUpdate(0, 0);
//         _filamentController.panEnd();
//         break;
//       case 20:
//         _filamentController.clearAssets();
//         break;
//       case 21:
//         break;
//       case 22:
//         break;
//       case 23:
//         break;
//       case 24:
//         _filamentController.setRotation(_cube!, pi / 2, 0.0, 1.0, 0.0);
//         break;
//       case 25:
//         setState(() {
//           _vertical = !_vertical;
//         });
//         break;
//       case 26:
//         _filamentController.setCameraPosition(0, 0, 3);
//         _filamentController.setCameraRotation(0, 0, 1, 0);
//         break;
//       case 27:
//         _framerate = _framerate == 60 ? 30 : 60;
//         _filamentController.setFrameRate(_framerate);
//         break;
//       case 28:
//         _filamentController.setBackgroundImagePosition(25, 25);
//         break;
//       case 29:
//         _light = await _filamentController.addLight(
//             1, 6500, 15000000, 0, 1, 0, 0, -1, 0, true);
//         break;
//       case 30:
//         if (_light != null) {
//           _filamentController.removeLight(_light!);
//           _light = null;
//         }
//         break;
//       case 31:
//         _filamentController.clearLights();
//         break;
//       case 32:
      
//         // break;
//         break;
//       case 33:
        
//         break;
//       case 34:
//         var duration =
//             await _filamentController.getAnimationDuration(_cube!, 0);
//         _filamentController.playAnimation(_cube!, 0,
//             loop: false, crossfade: 0.5);
//         await Future.delayed(
//             Duration(milliseconds: (duration * 1000.0).toInt()));
//         print("animation complete");
//         // showDialog(
//         //     context: context,
//         //     builder: (context) {
//         //       return Container(
//         //           width: 100,
//         //           height: 100,
//         //           color: Colors.white,
//         //           child: "animation complete!");
//         //     });
//         break;
//       case 35:
//         _filamentController.playAnimation(_cube!, 1,
//             loop: false, crossfade: 0.5);
//         break;
//       case 36:
//         _filamentController.playAnimation(_cube!, 2,
//             loop: false, crossfade: 0.5);
//         break;
//       case 37:
//         _filamentController.stopAnimation(_cube!, 0);
//         break;
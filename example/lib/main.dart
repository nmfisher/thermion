import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:polyvox_filament/animations/animation_data.dart';

import 'package:polyvox_filament/filament_controller.dart';

import 'package:polyvox_filament/filament_controller_ffi.dart';
import 'package:polyvox_filament/animations/animation_builder.dart';

import 'package:path_provider/path_provider.dart';
import 'package:polyvox_filament/widgets/filament_gesture_detector.dart';
import 'package:polyvox_filament/widgets/filament_widget.dart';

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
  FilamentController? _filamentController;
  FilamentEntity? _shapes;
  FilamentEntity? _flightHelmet;
  List<String>? _animations;
  FilamentEntity? _light;

  StreamSubscription? _pickResultListener;
  String? picked;

  final weights = List.filled(255, 0.0);

  bool _loop = false;
  EdgeInsets _viewportMargin = EdgeInsets.zero;

  bool _readyForScene = false;

  bool _rendering = false;
  int _framerate = 60;
  bool _postProcessing = true;

  bool _coneHidden = false;
  bool _frustumCulling = true;

  StreamSubscription? _hasViewerListener;

  @override
  void dispose() {
    super.dispose();
    _pickResultListener?.cancel();
    _hasViewerListener?.cancel();
  }

  Widget _item(void Function() onTap, String text) {
    return GestureDetector(
        onTap: () {
          setState(() {
            onTap();
          });
        },
        child: Container(
            color: Colors.transparent,
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            child: Text(text)));
  }

  void _createController({String? uberArchivePath}) {
    _filamentController =
        FilamentControllerFFI(uberArchivePath: uberArchivePath);
    _filamentController!.pickResult.listen((entityId) {
      setState(() {
        picked = _filamentController!.getNameForEntity(entityId!);
      });
    });
    _hasViewerListener =
        _filamentController!.hasViewer.listen((bool hasViewer) {
      setState(() {
        _readyForScene = hasViewer;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    var children = <Widget>[];

    if (_filamentController == null) {
      children.addAll([
        _item(() {
          _createController();
        }, "create viewer (default ubershader)"),
        _item(() {
          _createController(
              uberArchivePath: Platform.isWindows
                  ? "assets/lit_opaque_32.uberz"
                  : Platform.isMacOS
                      ? "assets/lit_opaque_43.uberz"
                      : Platform.isIOS
                          ? "assets/lit_opaque_43.uberz"
                          : "assets/lit_opaque_43_gles.uberz");
        }, "create viewer (custom ubershader - lit opaque only)"),
      ]);
    }

    if (_readyForScene) {
      children.addAll([
        _item(() {
          _filamentController!.destroy();
          _filamentController = null;
        }, "destroy viewer/texture"),
        _item(() {
          _filamentController!.render();
        }, "render"),
        _item(() {
          setState(() {
            _rendering = !_rendering;
            _filamentController!.setRendering(_rendering);
          });
        }, "Rendering: $_rendering"),
        _item(() {
          setState(() {
            _framerate = _framerate == 60 ? 30 : 60;
            _filamentController!.setFrameRate(_framerate);
          });
        }, "$_framerate fps"),
        _item(() {
          _filamentController!.setBackgroundColor(Color(0xFF73C9FA));
        }, "set background color"),
        _item(() {
          _filamentController!.setBackgroundImage('assets/background.ktx');
        }, "load background image"),
        _item(() {
          _filamentController!
              .setBackgroundImage('assets/background.ktx', fillHeight: true);
        }, "load background image (fill height)"),
        _item(() {
          _filamentController!
              .loadSkybox('assets/default_env/default_env_skybox.ktx');
        }, 'load skybox'),
        _item(() {
          _filamentController!
              .loadIbl('assets/default_env/default_env_ibl.ktx');
        }, 'load IBL'),
        _item(() async {
          _light = await _filamentController!
              .addLight(1, 6500, 150000, 0, 1, 0, 0, -1, 0, true);
        }, "add directional light"),
        _item(() async {
          await _filamentController!.clearLights();
        }, "clear lights"),
        _item(() {
          setState(() {
            _postProcessing = !_postProcessing;
          });
          _filamentController!.setPostProcessing(_postProcessing);
        }, "${_postProcessing ? "Disable" : "Enable"} postprocessing"),
        _item(
          () {
            _filamentController!.removeSkybox();
          },
          'remove skybox',
        ),
        _item(() async {
          _shapes =
              await _filamentController!.loadGlb('assets/shapes/shapes.glb');
          _animations = await _filamentController!.getAnimationNames(_shapes!);
          setState(() {});
        }, 'load shapes GLB'),
        _item(() async {
          _animations = await _filamentController!.setCamera(_shapes!, null);
          setState(() {});
        }, 'set camera to first camera in shapes GLB'),
        _item(() async {
          if (_coneHidden) {
            _filamentController!.reveal(_shapes!, "Cone");
          } else {
            _filamentController!.hide(_shapes!, "Cone");
          }
          setState(() {
            _coneHidden = !_coneHidden;
          });
        }, _coneHidden ? 'show cone' : 'hide cone'),
        _item(() async {
          if (_shapes != null) {
            _filamentController!.removeAsset(_shapes!);
          }
          _shapes = await _filamentController!
              .loadGltf('assets/shapes/shapes.gltf', 'assets/shapes');
        }, 'load shapes GLTF'),
        _item(() async {
          _filamentController!.transformToUnitCube(_shapes!);
        }, 'transform to unit cube'),
        _item(() async {
          _filamentController!.setPosition(_shapes!, 1.0, 1.0, -1.0);
        }, 'set shapes position to 1, 1, -1'),
        _item(() async {
          _filamentController!.setCameraPosition(1.0, 1.0, -1.0);
        }, 'move camera to 1, 1, -1'),
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

          _filamentController!.setBoneAnimation(
              _shapes!,
              BoneAnimationData(
                  "Bone.001", ["Cube.001"], frameData, 1000.0 / 60.0));
          //     ,
          //     "Bone.001",
          //     "Cube.001",
          //     BoneTransform([Vec3(x: 0, y: 0.0, z: 0.0)],
          //         [Quaternion(x: 1, y: 1, z: 1, w: 1)]));
        }, 'construct bone animation'),
        _item(() async {
          _filamentController!.removeAsset(_shapes!);
          _shapes = null;
        }, 'remove shapes'),
        _item(() async {
          _filamentController!.clearAssets();
          _shapes = null;
        }, 'clear all assets'),
        _item(() async {
          var names = await _filamentController!
              .getMorphTargetNames(_shapes!, "Cylinder");
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
          _filamentController!
              .setMorphTargetWeights(_shapes!, "Cylinder", List.filled(4, 1.0));
        }, "set Cylinder morph weights to 1"),
        _item(() {
          _filamentController!
              .setMorphTargetWeights(_shapes!, "Cylinder", List.filled(4, 0.0));
        }, "set Cylinder morph weights to 0.0"),
        _item(() async {
          var morphs = await _filamentController!
              .getMorphTargetNames(_shapes!, "Cylinder");
          final animation = AnimationBuilder(
                  availableMorphs: morphs, framerate: 30, meshName: "Cylinder")
              .setDuration(4)
              .setMorphTargets(["Key 1", "Key 2"])
              .interpolateMorphWeights(0, 4, 0, 1)
              .build();
          _filamentController!.setMorphAnimationData(_shapes!, animation);
        }, "animate cylinder morph weights #1 and #2"),
        _item(() async {
          var morphs = await _filamentController!
              .getMorphTargetNames(_shapes!, "Cylinder");
          final animation = AnimationBuilder(
                  availableMorphs: morphs, framerate: 30, meshName: "Cylinder")
              .setDuration(4)
              .setMorphTargets(["Key 3", "Key 4"])
              .interpolateMorphWeights(0, 4, 0, 1)
              .build();
          _filamentController!.setMorphAnimationData(_shapes!, animation);
        }, "animate cylinder morph weights #3 and #4"),
        _item(() async {
          var morphs =
              await _filamentController!.getMorphTargetNames(_shapes!, "Cube");
          final animation = AnimationBuilder(
                  availableMorphs: morphs, framerate: 30, meshName: "Cube")
              .setDuration(4)
              .setMorphTargets(["Key 1", "Key 2"])
              .interpolateMorphWeights(0, 4, 0, 1)
              .build();
          _filamentController!.setMorphAnimationData(_shapes!, animation);
        }, "animate shapes morph weights #1 and #2"),
        _item(() {
          _filamentController!
              .setMaterialColor(_shapes!, "Cone", 0, Colors.purple);
        }, "set cone material color to purple"),
        _item(() {
          _loop = !_loop;
          setState(() {});
        }, "toggle animation looping ${_loop ? "OFF" : "ON"}"),
        _item(() {
          setState(() {
            _viewportMargin = _viewportMargin == EdgeInsets.zero
                ? EdgeInsets.all(50)
                : EdgeInsets.zero;
          });
        }, "resize"),
        _item(() async {
          await Permission.microphone.request();
        }, "request permissions (tests inactive->resume)")
      ]);
      if (_animations != null) {
        children.addAll(_animations!.map((a) => _item(() {
              _filamentController!.playAnimation(
                  _shapes!, _animations!.indexOf(a),
                  replaceActive: true, crossfade: 0.5, loop: _loop);
            }, "play animation ${_animations!.indexOf(a)} (replace/fade)")));
        children.addAll(_animations!.map((a) => _item(() {
              _filamentController!.playAnimation(
                  _shapes!, _animations!.indexOf(a),
                  replaceActive: false, loop: _loop);
            }, "play animation ${_animations!.indexOf(a)} (noreplace)")));
      }

      children.add(_item(() {
        _filamentController!.setToneMapping(ToneMapper.LINEAR);
      }, "Set tone mapping to linear"));

      children.add(_item(() {
        _filamentController!.moveCameraToAsset(_shapes!);
      }, "Move camera to asset"));

      children.add(_item(() {
        setState(() {
          _frustumCulling = !_frustumCulling;
        });
        _filamentController!.setViewFrustumCulling(_frustumCulling);
      }, "${_frustumCulling ? "Disable" : "Enable"} frustum culling"));
    }
    return Stack(children: [
      _filamentController != null
          ? Positioned.fill(
              child: Padding(
                  padding: _viewportMargin,
                  child: FilamentGestureDetector(
                      showControlOverlay: true,
                      controller: _filamentController!,
                      child: FilamentWidget(
                        controller: _filamentController!,
                      ))))
          : Container(),
      Positioned(
          right: 50,
          top: 50,
          child: Text(picked ?? "",
              style: const TextStyle(color: Colors.green, fontSize: 24))),
      Align(
          alignment: Alignment.bottomCenter,
          child: OrientationBuilder(builder: (ctx, orientation) {
            return Container(
                alignment: Alignment.bottomCenter,
                height: orientation == Orientation.landscape ? 100 : 200,
                color: Colors.white.withOpacity(0.75),
                child: SingleChildScrollView(child: Wrap(children: children)));
          }))
    ]);
  }
}

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

// case -1:

//         break;
//       case -2:
//         _filamentController!.render();
//         break;
//       case -4:
//         setState(() {
//           _rendering = !_rendering;
//           _filamentController!.setRendering(_rendering);
//         });
//         break;
//       case -5:
//         setState(() {
//           _framerate = _framerate == 60 ? 30 : 60;
//           _filamentController!.setFrameRate(_framerate);
//         });
//         break;
//       case -6:
//         _filamentController!.setBackgroundColor(Color(0xFF73C9FA));
//         break;

//       case 5:
//         _flightHelmet ??= await _filamentController!.loadGltf(
//             'assets/FlightHelmet/FlightHelmet.gltf', 'assets/FlightHelmet');
//         break;

//       case 11:
//         setState(() {
//           _loop = !_loop;
//         });
//         break;
//       case 14:
//         _filamentController!.setCamera(_shapes!, "Camera_Orientation");
//         break;
//       case 15:

//         break;
//       case 17:
//         var animationNames =
//             await _filamentController!.getAnimationNames(_shapes!);

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
//         _filamentController!.panStart(1, 1);
//         _filamentController!.panUpdate(1, 2);
//         _filamentController!.panEnd();
//         break;
//       case 19:
//         _filamentController!.panStart(1, 1);
//         _filamentController!.panUpdate(0, 0);
//         _filamentController!.panEnd();
//         break;
//       case 20:
//         _filamentController!.clearAssets();
//         break;
//       case 21:
//         break;
//       case 22:
//         break;
//       case 23:
//         break;
//       case 24:
//         _filamentController!.setRotation(_shapes!, pi / 2, 0.0, 1.0, 0.0);
//         break;
//       case 26:
//         _filamentController!.setCameraPosition(0, 0, 3);
//         _filamentController!.setCameraRotation(0, 0, 1, 0);
//         break;
//       case 27:
//         _framerate = _framerate == 60 ? 30 : 60;
//         _filamentController!.setFrameRate(_framerate);
//         break;
//       case 28:
//         _filamentController!.setBackgroundImagePosition(25, 25);
//         break;

//       case 30:
//         if (_light != null) {
//           _filamentController!.removeLight(_light!);
//           _light = null;
//         }
//         break;
//       case 31:

//         break;
//       case 32:

//         // break;
//         break;
//       case 33:

//         break;
//       case 34:
//         var duration =
//             await _filamentController!.getAnimationDuration(_shapes!, 0);
//         _filamentController!.playAnimation(_shapes!, 0,
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
//         _filamentController!.playAnimation(_shapes!, 1,
//             loop: false, crossfade: 0.5);
//         break;
//       case 36:
//         _filamentController!.playAnimation(_shapes!, 2,
//             loop: false, crossfade: 0.5);
//         break;
//       case 37:
//         _filamentController!.stopAnimation(_shapes!, 0);
//         break;

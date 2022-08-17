import 'dart:math';

import 'package:flutter/material.dart';
import 'package:polyvox_filament/filament_controller.dart';
import 'package:polyvox_filament/filament_widget.dart';

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

  final weights = List.filled(255, 0.0);
  List<String> _targets = [];
  List<String> _animationNames = [];
  bool _loop = false;
  bool _vertical = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        showPerformanceOverlay: true,
        color: Colors.transparent,
        home: Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                      onScaleStart: (d) {
                        if (d.pointerCount == 1)
                          _filamentController.panStart(0.5, 0.5);
                      },
                      onScaleEnd: (d) {
                        // if(d.pointerCount == 2) {}
                        // _filamentController.panEnd(d. .focalPoint.dx,d.focalPoint.dy);
                      },
                      onScaleUpdate: (d) {
                        if (d.pointerCount == 1) {
                          // _filamentController.panUpdate(d.focalPoint.dx,d.focalPoint.dy);
                        } else {
                          _filamentController.zoom(10.0);
                        }
                      },
                      child: Container(
                        width: _vertical ? 100 : 200, height: _vertical ? 200 : 100,
                        alignment: Alignment.center,
                        child: SizedBox(
                            child: FilamentWidget(
                          controller: _filamentController,
                        )),
                      )),
                  Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                          color: Colors.white,
                          margin: const EdgeInsets.all(15),
                          child: PopupMenuButton<int>(
                              padding: EdgeInsets.all(50),
                              iconSize: 36,
                              child: const Icon(Icons.menu),
                              onSelected: (int item) async {
                                switch (item) {
                                  case 0:
                                    await _filamentController
                                        .setBackgroundImage(
                                            'assets/background.png');
                                    break;
                                  case 1:
                                    await _filamentController.loadSkybox(
                                        'assets/default_env/default_env_skybox.ktx');
                                    await _filamentController.loadSkybox(
                                        'assets/default_env/default_env_ibl.ktx');
                                    break;
                                  case 2:
                                    await _filamentController.removeSkybox();
                                    break;
                                  case 3:
                                    _cube = await _filamentController
                                        .loadGlb('assets/cube.glb');

                                    _animationNames = await _filamentController
                                        .getAnimationNames(_cube!);
                                    break;

                                  case 4:
                                    if (_cube != null) {
                                      await _filamentController
                                          .removeAsset(_cube!);
                                    }
                                    _cube = await _filamentController.loadGltf(
                                        'assets/cube.gltf', 'assets');
                                    print(await _filamentController
                                        .getAnimationNames(_cube!));
                                    break;
                                  case 5:
                                    if (_flightHelmet == null) {
                                      _flightHelmet =
                                          await _filamentController.loadGltf(
                                              'assets/FlightHelmet/FlightHelmet.gltf',
                                              'assets/FlightHelmet');
                                    }
                                    break;
                                  case 6:
                                    await _filamentController
                                        .removeAsset(_cube!);
                                    break;

                                  case 7:
                                    await _filamentController.applyWeights(
                                        _cube!, List.filled(8, 1.0));
                                    break;
                                  case 8:
                                    await _filamentController.applyWeights(
                                        _cube!, List.filled(8, 0));
                                    break;
                                  case 9:
                                    _filamentController.playAnimations(
                                        _cube!,
                                        List.generate(
                                            _animationNames.length, (i) => i),
                                        loop: _loop);
                                    break;
                                  case 10:
                                    _filamentController.stopAnimation(_cube!);
                                    break;
                                  case 11:
                                    setState(() {
                                      _loop = !_loop;
                                    });
                                    break;
                                  case 12:
                                    _filamentController.zoom(-1.0);
                                    break;
                                  case 13:
                                    _filamentController.zoom(1.0);
                                    break;
                                  case 14:
                                    _filamentController.setCamera(
                                        _cube!, "Camera_Orientation");
                                    break;
                                  case 15:
                                    final framerate = 30;
                                    final totalSecs = 5;
                                    final numWeights = 8;
                                    final totalFrames = framerate * totalSecs;
                                    final frames = List.generate(
                                        totalFrames,
                                        (frame) => List.filled(
                                            numWeights, frame / totalFrames));

                                    _filamentController.animate(
                                        _cube!,
                                        frames.reduce((a, b) => a + b),
                                        numWeights,
                                        totalFrames,
                                        1000 / framerate.toDouble());
                                    break;
                                  case 16:
                                    final names = await _filamentController
                                        .getTargetNames(_cube!, "Cube");

                                    await showDialog(
                                        builder: (ctx) {
                                          return Container(
                                              color: Colors.white,
                                              height: 200,
                                              width: 200,
                                              child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: names
                                                          .map((name) =>
                                                              Text(name))
                                                          .cast<Widget>()
                                                          .toList() +
                                                      <Widget>[
                                                        ElevatedButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                        ctx)
                                                                    .pop(),
                                                            child:
                                                                Text("Close"))
                                                      ]));
                                        },
                                        context: context);
                                    break;
                                  case 17:
                                    final names = await _filamentController
                                        .getAnimationNames(_cube!);

                                    await showDialog(
                                        builder: (ctx) {
                                          return Container(
                                              color: Colors.white,
                                              height: 200,
                                              width: 200,
                                              child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: names
                                                          .map((name) =>
                                                              Text(name))
                                                          .cast<Widget>()
                                                          .toList() +
                                                      <Widget>[
                                                        ElevatedButton(
                                                            onPressed: () =>
                                                                Navigator.of(
                                                                        ctx)
                                                                    .pop(),
                                                            child:
                                                                Text("Close"))
                                                      ]));
                                        },
                                        context: context);
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
                                    await _filamentController.setTexture(
                                        _cube!, "assets/background.png");
                                    break;
                                  case 22:
                                    await _filamentController
                                        .transformToUnitCube(_cube!);
                                    break;
                                  case 23:
                                    await _filamentController.setPosition(
                                        _cube!, 1.0, 1.0, -1.0);
                                    break;
                                  case 24:
                                    await _filamentController.setRotation(
                                        _cube!, pi / 2, 0.0, 1.0, 0.0);
                                    break;
                                  case 25:
                                    setState(() {
                                      _vertical = !_vertical;
                                    });
                                }
                              },
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<int>>[
                                    const PopupMenuItem(
                                        value: 0,
                                        child: Text("load background image")),
                                    const PopupMenuItem(
                                      value: 1,
                                      child: Text('load skybox'),
                                    ),
                                    const PopupMenuItem(
                                      value: 2,
                                      child: Text('remove skybox'),
                                    ),
                                    const PopupMenuItem(
                                        value: 3, child: Text('load cube GLB')),
                                    const PopupMenuItem(
                                        value: 4,
                                        child: Text('load cube GLTF')),
                                    const PopupMenuItem(
                                        value: 21,
                                        child: Text('swap cube texture')),
                                    const PopupMenuItem(
                                        value: 22,
                                        child: Text('transform to unit cube')),
                                    const PopupMenuItem(
                                        value: 23,
                                        child:
                                            Text('set position to 1, 1, -1')),
                                    const PopupMenuItem(
                                        value: 24,
                                        child:
                                            Text('rotate by pi around Y axis')),
                                    const PopupMenuItem(
                                        value: 5,
                                        child: Text('load flight helmet')),
                                    const PopupMenuItem(
                                        value: 6, child: Text('remove cube')),
                                    const PopupMenuItem(
                                        value: 20,
                                        child: Text('remove all assets')),
                                    const PopupMenuItem(
                                        value: 7,
                                        child: Text('set all weights to 1')),
                                    const PopupMenuItem(
                                        value: 8,
                                        child: Text('set all weights to 0')),
                                    const PopupMenuItem(
                                        value: 9,
                                        child: Text('play all animations')),
                                    const PopupMenuItem(
                                        value: 10,
                                        child: Text('stop animations')),
                                    PopupMenuItem(
                                        value: 11,
                                        child: Text(
                                            _loop ? "don't loop animation" : "loop animation")),
                                    const PopupMenuItem(
                                        value: 12, child: Text('zoom in')),
                                    const PopupMenuItem(
                                        value: 13, child: Text('zoom out')),
                                    const PopupMenuItem(
                                        value: 14, child: Text('set camera')),
                                    const PopupMenuItem(
                                        value: 15,
                                        child: Text('animate weights')),
                                    const PopupMenuItem(
                                        value: 16,
                                        child: Text('get target names')),
                                    const PopupMenuItem(
                                        value: 17,
                                        child: Text('get animation names')),
                                    const PopupMenuItem(
                                        value: 18, child: Text('pan left')),
                                    const PopupMenuItem(
                                        value: 19, child: Text('pan right')),
                                    PopupMenuItem(
                                        value: 25, child: Text(_vertical ? 'set horizontal' : 'set vertical')),
                                  ])))
                ])));
  }
}

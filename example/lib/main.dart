import 'package:flutter/material.dart';
import 'package:polyvox_filament/filament_controller.dart';
import 'package:polyvox_filament/view/filament_widget.dart';

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
  bool _loop = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.transparent,
      home: Scaffold(
          backgroundColor: Colors.transparent,
          body: Column(children: [
            Expanded(
                child: SizedBox(
                    height: 200,
                    width: 200,
                    child: FilamentWidget(
                      controller: _filamentController,
                    ))),
            Expanded(
                child: SingleChildScrollView(
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  ElevatedButton(
                      child: const Text('load background image'),
                      onPressed: () async {
                        await _filamentController
                            .setBackgroundImage('assets/background.png');
                      }),
                  ElevatedButton(
                      child: const Text('load skybox'),
                      onPressed: () async {
                        await _filamentController.loadSkybox(
                            'assets/default_env/default_env_skybox.ktx');
                        await _filamentController.loadSkybox(
                            'assets/default_env/default_env_ibl.ktx');
                      }),
                  ElevatedButton(
                      child: const Text('remove skybox'),
                      onPressed: () async {
                        await _filamentController.removeSkybox();
                      }),
                  ElevatedButton(
                      child: const Text('load cube GLB'),
                      onPressed:_cube != null ? null : () async {
                        _cube = await _filamentController
                            .loadGlb('assets/cube.glb');
                        print(await _filamentController
                            .getAnimationNames(_cube!));
                      }),
                    ElevatedButton(
                      child: const Text('load cube GLTF'),
                      onPressed:() async {
                        if(_cube != null) {
                          await _filamentController.removeAsset(_cube!);
                        }
                        _cube = await _filamentController
                            .loadGltf('assets/cube.gltf', 'assets');
                        print(await _filamentController
                            .getAnimationNames(_cube!));
                      }),
                  ElevatedButton(
                      child: const Text('load flight helmet'),
                      onPressed:_flightHelmet != null ? null : () async {
                        _flightHelmet = await _filamentController.loadGltf(
                            'assets/FlightHelmet/FlightHelmet.gltf',
                            'assets/FlightHelmet');
                      }),
                  ElevatedButton(
                      child: const Text('remove cube'),
                      onPressed: () async {
                        await _filamentController.removeAsset(_cube!);
                      }),
                  ElevatedButton(
                      child: const Text('set all weights to 1'),
                      onPressed: () async {
                        await _filamentController
                            .applyWeights(_cube!, List.filled(8, 1.0));
                      }),
                  ElevatedButton(
                      child: const Text('set all weights to 0'),
                      onPressed: () async {
                        await _filamentController
                            .applyWeights(_cube!, List.filled(8, 0));
                      }),
                  ElevatedButton(
                      onPressed: () =>
                          _filamentController.playAnimation(_cube!, 0, loop: _loop),
                      child: const Text('play animation')),
                  ElevatedButton(
                      onPressed: () {
                        _filamentController.stopAnimation(_cube!);
                      },
                      child: const Text('stop animation')),
                  Checkbox(
                      onChanged: (_) => setState(() {
                            _loop = !_loop;
                          }),
                      value: _loop),
                  ElevatedButton(
                      onPressed: () {
                        _filamentController.zoom(-1.0);
                      },
                      child: const Text('zoom in')),
                  ElevatedButton(
                      onPressed: () {
                        _filamentController.zoom(1.0);
                      },
                      child: const Text('zoom out')),
                  ElevatedButton(
                      onPressed: () {
                        _filamentController.setCamera(_cube!, "Camera_Orientation");
                      },
                      child: const Text('set camera')),
                  ElevatedButton(
                      onPressed: () {
                        final framerate = 30;
                        final totalSecs = 5;
                        final numWeights = 8;
                        final totalFrames = framerate * totalSecs;
                        final frames = List.generate(
                            totalFrames,
                            (frame) =>
                                List.filled(numWeights, frame / totalFrames));

                        _filamentController.animate(
                          _cube!,
                            frames.reduce((a, b) => a + b),
                            numWeights,
                            totalFrames,
                            1000 / framerate.toDouble());
                      },
                      child: const Text('animate weights')),
                  Builder(
                      builder: (innerCtx) => ElevatedButton(
                          onPressed: () async {
                            final names = await _filamentController
                                .getTargetNames(_cube!, "Cube");

                            await showDialog(
                                builder: (ctx) {
                                  return Container(
                                      color: Colors.white,
                                      height: 200,
                                      width: 200,
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: names
                                                  .map((name) => Text(name))
                                                  .cast<Widget>()
                                                  .toList() +
                                              <Widget>[
                                                ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.of(ctx).pop(),
                                                    child: Text("Close"))
                                              ]));
                                },
                                context: innerCtx);
                          },
                          child: const Text('get target names'))),
                  Builder(
                      builder: (innerCtx) => ElevatedButton(
                          onPressed: () async {
                            final names =
                                await _filamentController.getAnimationNames(_cube!);

                            await showDialog(
                                builder: (ctx) {
                                  return Container(
                                      color: Colors.white,
                                      height: 200,
                                      width: 200,
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: names
                                                  .map((name) => Text(name))
                                                  .cast<Widget>()
                                                  .toList() +
                                              <Widget>[
                                                ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.of(ctx).pop(),
                                                    child: Text("Close"))
                                              ]));
                                },
                                context: innerCtx);
                          },
                          child: const Text('get animation names'))),
                  ElevatedButton(
                      onPressed: () async {
                        await _filamentController.panStart(1, 1);
                        await _filamentController.panUpdate(1, 2);
                        await _filamentController.panEnd();
                      },
                      child: Text("Pan left")),
                  ElevatedButton(
                      onPressed: () async {
                        await _filamentController.panStart(1, 1);
                        await _filamentController.panUpdate(0, 0);
                        await _filamentController.panEnd();
                      },
                      child: Text("Pan right"))
                ],
              ),
            )),
          ])),
    );
  }
}



import 'dart:async';
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
  
  late DelegateInputHandler _fixedOrbitInputHandler;
  late DelegateInputHandler _freeFlightInputHandler;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _thermionViewer = await ThermionFlutterPlugin.createViewer();
      var entity =
          await _thermionViewer!.loadGltf("assets/cube.glb", keepData: true);
      await _thermionViewer!.loadSkybox("assets/default_env_skybox.ktx");
      await _thermionViewer!.loadIbl("assets/default_env_ibl.ktx");
      await _thermionViewer!.setPostProcessing(true);
      await _thermionViewer!.setRendering(true);

      _fixedOrbitInputHandler =
          DelegateInputHandler.fixedOrbit(_thermionViewer!)
            ..setActionForType(InputType.MMB_HOLD_AND_MOVE, InputAction.ROTATE)
            ..setActionForType(InputType.SCALE1, InputAction.ROTATE)
            ..setActionForType(InputType.SCALE2, InputAction.ZOOM)
            ..setActionForType(InputType.SCROLLWHEEL, InputAction.ZOOM);

      _freeFlightInputHandler =
          DelegateInputHandler.flight(_thermionViewer!)
            ..setActionForType(InputType.MMB_HOLD_AND_MOVE, InputAction.ROTATE)
            ..setActionForType(InputType.SCALE1, InputAction.ROTATE)
            ..setActionForType(InputType.SCALE2, InputAction.ZOOM)
            ..setActionForType(InputType.SCROLLWHEEL, InputAction.ZOOM);

      setState(() {});
    });
  }

  ThermionViewer? _thermionViewer;

  bool isOrbit = true;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      if (_thermionViewer != null) ...[
        Positioned.fill(
            child: ThermionListenerWidget(
                inputHandler: isOrbit
                    ? _fixedOrbitInputHandler : _freeFlightInputHandler,
                    child:ThermionWidget(
                        viewer: _thermionViewer!,
                      ))),
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
                onPressed: () {
                  isOrbit = !isOrbit;
                  setState(() {});
                },
                child: Text("Switch to ${isOrbit ? "Free Flight" : "Orbit"}"))
          ],
        )
      ],
    ]);
  }
}

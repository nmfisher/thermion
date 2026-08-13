import 'dart:async';
import 'package:flutter/material.dart' hide View;
import 'package:flutter/services.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

void main() {
  runApp(const MyApp());
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
  late DelegateInputHandler _inputHandler;

  String? overlay;
  final vectors = <Vector2>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _thermionViewer = await ThermionFlutterPlugin.createViewer();
      _thermionViewer!.view.setTransparentPickingEnabled(true);
      // var matData = await rootBundle.load("assets/picking_index0.filamat");
      // var mat = await FilamentApp.instance!
      //     .createMaterial(matData.buffer.asUint8List(matData.offsetInBytes));
      // var mi = await mat.createInstance();
      // await mi.setParameterFloat4("baseColorFactor", 1, 0, 0, 1);
      // await mi.setParameterInt("baseColorIndex", -1);

      var asset = await _thermionViewer!
          .createGeometry(GeometryUtils.cube(), materialInstances: [
            // mi
            ]);

      var instances = <ThermionAsset>[
        await asset.createInstance(),
        await asset.createInstance(),
        await asset.createInstance(),
        await asset.createInstance()
      ];
      for (final instance in instances) {
        await _thermionViewer!.addToScene(instance);
      }

      var vectors = <Vector2>[
        Vector2(1, 1),
        Vector2(1, -1),
        Vector2(-1, 1),
        Vector2(-1, -1),
      ];

      const speed = 0.03;

      FilamentApp.instance!.registerRequestFrameHook(() async {
        for (int i = 0; i < instances.length; i++) {
          final instance = instances[i];
          final vector = vectors[i];
          var transform = await instance.getWorldTransform();
          var translation = transform.getTranslation();
          var delta = vector.scaled(speed)
            ..clamp(Vector2(-1, -1), Vector2(1, 1));
          translation.x += delta.x;
          translation.y += delta.y;
          if (translation.x.abs() >= 3) {
            vectors[i].x *= -1;
          }
          if (translation.y.abs() >= 3) {
            vectors[i].y *= -1;
          }
          transform.setTranslation(translation);
          await instance.setTransform(transform);
        }
      });

      final camera = await _thermionViewer!.getActiveCamera();
      await camera.lookAt(Vector3(0, 0, 10));

      // await _thermionViewer!.loadSkybox("assets/default_env_skybox.ktx");
      await _thermionViewer!.loadIbl("assets/default_env_ibl.ktx");
      await _thermionViewer!.setPostProcessing(false);
      await _thermionViewer!.view.setBlendMode(BlendMode.transparent);

      var pickingDelegate = _InputHandlerDelegate(_thermionViewer!.view,
          (ThermionEntity entity, int x, int y) async {
        print("PICKED $entity");
        int picked = -1;
        for (int i = 0; i < instances.length; i++) {
          var instance = instances[i];
          var children = await instance.getChildEntities();
          if (entity == instance.entity || children.contains(entity)) {
            picked = i;
            break;
          }
        }
        if (picked != -1) {
          overlay =
              "Instance $picked selected at viewport coordinates ($x, $y)";
        } else {
          overlay = null;
        }
        setState(() {});
      });

      _inputHandler = DelegateInputHandler.flight(_thermionViewer!);
      _inputHandler.delegate = ChainedDelegate([
        pickingDelegate,
        _inputHandler.delegate!,
      ]);

      setState(() {});
    });
  }

  ThermionViewer? _thermionViewer;

  @override
  Widget build(BuildContext context) {
    if (_thermionViewer == null) {
      return Container();
    }
    return Stack(children: [
      Positioned.fill(
          child: ThermionListenerWidget(
              inputHandler: _inputHandler,
              child: ThermionWidget(
                viewer: _thermionViewer!,
              ))),
      if (overlay != null)
        Align(
            alignment: Alignment.bottomCenter,
            child: Container(
                padding: const EdgeInsets.all(5),
                margin: const EdgeInsets.all(5),
                color: Colors.black,
                child: Text(
                  overlay!,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                )))
    ]);
  }
}

class _InputHandlerDelegate extends InputHandlerDelegate {
  final View view;
  final void Function(ThermionEntity, int x, int y) onPick;

  _InputHandlerDelegate(this.view, this.onPick);

  void _onPickResult(PickResult result) {
    onPick.call(result.entity, result.x, result.y);
  }

  @override
  Future handle(List<InputEvent> events) async {
    for (final event in events) {
      switch (event) {
        case MouseEvent(:final type, :final localPosition):
          switch (type) {
            case MouseEventType.buttonDown:
              await view.pick(localPosition.x.toInt(), localPosition.y.toInt(),
                  _onPickResult);
            default:
              break;
          }
          break;
        case TouchEvent(:final localPosition):
          if (localPosition != null) {
            await view.pick(localPosition.x.toInt(), localPosition.y.toInt(),
                _onPickResult);
          }
          break;
        default:
          break;
      }
    }
  }
}

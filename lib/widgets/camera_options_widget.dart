import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/filament_controller.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class CameraOptionsWidget extends StatefulWidget {
  final FilamentController controller;
  final List<({FilamentEntity entity, String name})> cameras;

  CameraOptionsWidget(
      {super.key, required this.controller, required this.cameras}) {}

  @override
  State<StatefulWidget> createState() => _CameraOptionsWidgetState();
}

class _CameraOptionsWidgetState extends State<CameraOptionsWidget> {
  final _apertureController = TextEditingController();
  final _speedController = TextEditingController();
  final _sensitivityController = TextEditingController();

  @override
  void initState() {
    _apertureController.text = "0";
    _speedController.text = "0";
    _sensitivityController.text = "0";

    _apertureController.addListener(() {
      _set();
      setState(() {});
    });
    _speedController.addListener(() {
      _set();
      setState(() {});
    });
    _sensitivityController.addListener(() {
      _set();
      setState(() {});
    });

    super.initState();
  }

  @override
  void didUpdateWidget(CameraOptionsWidget oldWidget) {
    if (oldWidget.cameras.length != widget.cameras.length) {
      setState(() {});
    }
  }

  Future _set() async {
    await widget.controller.setCameraExposure(
        double.parse(_apertureController.text),
        double.parse(_speedController.text),
        double.parse(_sensitivityController.text));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: ThemeData(platform: TargetPlatform.android),
        child: Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.5)),
            child: SliderTheme(
                data: SliderThemeData(
                    showValueIndicator: ShowValueIndicator.always,
                    valueIndicatorTextStyle: TextStyle(color: Colors.black)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Text("Aperture"),
                    Expanded(
                        child: TextField(
                      controller: _apertureController,
                    )),
                    Text("Speed"),
                    Expanded(child: TextField(controller: _speedController)),
                    Text("Sensitivity"),
                    Expanded(
                        child: TextField(controller: _sensitivityController)),
                  ]),
                  Wrap(
                    children: [
                      GestureDetector(
                        child: Text("Main "),
                        onTap: () {
                          widget.controller.setMainCamera();
                        },
                      ),
                      ...widget.cameras
                          .map((camera) => GestureDetector(
                              onTap: () {
                                widget.controller
                                    .setCamera(camera.entity, camera.name);
                              },
                              child: Text(camera.name)))
                          .toList()
                    ],
                  )
                ]))));
  }
}

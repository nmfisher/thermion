import 'package:thermion_dart/thermion_dart.dart';
import 'package:flutter/material.dart';
import '../../../utils/camera_orientation.dart';

import 'dart:math';

class CameraOptionsWidget extends StatefulWidget {
  final Camera camera;
  final CameraOrientation cameraOrientation;

  CameraOptionsWidget(
      {super.key, required this.camera, required this.cameraOrientation}) {}

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
    super.didUpdateWidget(oldWidget);
    if (oldWidget.camera != widget.camera) {
      setState(() {});
    }
  }

  Future _set() async {
    await widget.camera.setCameraExposure(
        double.parse(_apertureController.text),
        double.parse(_speedController.text),
        double.parse(_sensitivityController.text));
    await widget.camera.setModelMatrix(widget.cameraOrientation.compose());
    setState(() {});
  }

  double _bloom = 0.0;

  double _focalLength = 26.0;
  @override
  Widget build(BuildContext context) {
    return Theme(
        data: ThemeData(platform: TargetPlatform.android),
        child: Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.5)),
            child: SliderTheme(
                data: const SliderThemeData(
                    showValueIndicator: ShowValueIndicator.always,
                    valueIndicatorTextStyle: TextStyle(color: Colors.black)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Text("Aperture"),
                    Expanded(
                        child: TextField(
                      controller: _apertureController,
                    )),
                    const Text("Speed"),
                    Expanded(child: TextField(controller: _speedController)),
                    const Text("Sensitivity"),
                    Expanded(
                        child: TextField(controller: _sensitivityController)),
                  ]),
                  // Row(children: [
                  //   const Text("Focal length"),
                  //   Slider(
                  //       label: _focalLength.toString(),
                  //       value: _focalLength,
                  //       min: 1.0,
                  //       max: 100.0,
                  //       onChanged: (v) async {
                  //         setState(() {
                  //           _focalLength = v;
                  //         });
                  //         await widget.camera.setLensProjection(near: kNear, far:kFar, _focalLength);
                  //       })
                  // ]),
                  Row(children: [
                    const Text("X"),
                    Slider(
                        label: widget.cameraOrientation.position.x.toString(),
                        value: widget.cameraOrientation.position.x,
                        min: -100.0,
                        max: 100.0,
                        onChanged: (v) async {
                          setState(() {
                            widget.cameraOrientation.position.x = v;
                          });
                          _set();
                        })
                  ]),
                ]))));
  }
}

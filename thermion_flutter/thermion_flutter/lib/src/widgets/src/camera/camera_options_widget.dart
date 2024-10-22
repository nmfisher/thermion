
import 'package:thermion_dart/thermion_dart.dart';
import 'package:flutter/material.dart';
import '../../../utils/camera_orientation.dart';

import 'dart:math';


class CameraOptionsWidget extends StatefulWidget {
  final ThermionViewer controller;
  final CameraOrientation cameraOrientation;
  final List<({ThermionEntity entity, String name})> cameras;

  CameraOptionsWidget(
      {super.key,
      required this.controller,
      required this.cameras,
      required this.cameraOrientation}) {}

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
    if (oldWidget.cameras.length != widget.cameras.length) {
      setState(() {});
    }
  }

  Future _set() async {
    await widget.controller.setCameraExposure(
        double.parse(_apertureController.text),
        double.parse(_speedController.text),
        double.parse(_sensitivityController.text));
    await widget.controller.setCameraPosition(
        widget.cameraOrientation.position.x,
        widget.cameraOrientation.position.y,
        widget.cameraOrientation.position.z);
    var rotation = widget.cameraOrientation.compose();
    await widget.controller.setCameraRotation(rotation);
    print(
        "Camera : ${widget.cameraOrientation.position} ${widget.cameraOrientation.rotationX} ${widget.cameraOrientation.rotationY} ${widget.cameraOrientation.rotationZ}");
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
                  Row(children: [
                    Text("Bloom: ${_bloom.toStringAsFixed(2)}"),
                    Slider(
                        value: _bloom,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (v) async {
                          setState(() {
                            _bloom = v;
                          });
                          await widget.controller.setBloom(_bloom);
                        })
                  ]),
                  Row(children: [
                    const Text("Focal length"),
                    Slider(
                        label: _focalLength.toString(),
                        value: _focalLength,
                        min: 1.0,
                        max: 100.0,
                        onChanged: (v) async {
                          setState(() {
                            _focalLength = v;
                          });
                          await widget.controller
                              .setCameraFocalLength(_focalLength);
                        })
                  ]),
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
                  Row(children: [
                    const Text("Y"),
                    Slider(
                        label: widget.cameraOrientation.position.y.toString(),
                        value: widget.cameraOrientation.position.y,
                        min: -100.0,
                        max: 100.0,
                        onChanged: (v) async {
                          setState(() {
                            widget.cameraOrientation.position.y = v;
                          });
                          _set();
                        })
                  ]),
                  Row(children: [
                    const Text("Z"),
                    Slider(
                        label: widget.cameraOrientation.position.z.toString(),
                        value: widget.cameraOrientation.position.z,
                        min: -100.0,
                        max: 100.0,
                        onChanged: (v) async {
                          setState(() {
                            widget.cameraOrientation.position.z = v;
                          });
                          _set();
                        })
                  ]),
                  Row(children: [
                    const Text("ROTX"),
                    Slider(
                        label: widget.cameraOrientation.rotationX.toString(),
                        value: widget.cameraOrientation.rotationX,
                        min: -pi,
                        max: pi,
                        onChanged: (value) async {
                          setState(() {
                            widget.cameraOrientation.rotationX = value;
                          });
                          _set();
                        })
                  ]),
                  Row(children: [
                    const Text("ROTY"),
                    Slider(
                        label: widget.cameraOrientation.rotationY.toString(),
                        value: widget.cameraOrientation.rotationY,
                        min: -pi,
                        max: pi,
                        onChanged: (v) async {
                          setState(() {
                            widget.cameraOrientation.rotationY = v;
                          });
                          _set();
                        }),
                  ]),
                  Row(children: [
                    const Text("ROTZ"),
                    Slider(
                        label: widget.cameraOrientation.rotationZ.toString(),
                        value: widget.cameraOrientation.rotationZ,
                        min: -pi,
                        max: pi,
                        onChanged: (v) async {
                          setState(() {
                            widget.cameraOrientation.rotationZ = v;
                          });
                          _set();
                        })
                  ]),
                  Wrap(
                    children: [
                      GestureDetector(
                        child: const Text("Main "),
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

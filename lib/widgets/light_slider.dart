import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/filament_controller.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class LightSliderWidget extends StatefulWidget {
  final FilamentController controller;

  late final v.Vector3 initialPosition;
  late final v.Vector3 initialDirection;
  final int initialType;
  final double initialColor;
  final double initialIntensity;
  final bool initialCastShadows;
  final bool showControls;

  LightSliderWidget(
      {super.key,
      required this.controller,
      this.initialType = 0,
      this.initialColor = 6500,
      this.initialIntensity = 100000,
      this.initialCastShadows = true,
      this.showControls = false,
      v.Vector3? initialDirection,
      v.Vector3? initialPosition}) {
    this.initialDirection = initialDirection ?? v.Vector3(0, 0.5, -1);
    this.initialPosition = initialPosition ?? v.Vector3(0, 0.5, 1);
  }

  @override
  State<StatefulWidget> createState() => _IblRotationSliderWidgetState();
}

class _IblRotationSliderWidgetState extends State<LightSliderWidget> {
  v.Vector3 lightPos = v.Vector3(1, 0.1, 1);
  v.Vector3 lightDir = v.Vector3(-1, 0.1, 0);
  bool castShadows = true;
  int type = 0;
  double color = 6500;
  double intensity = 100000;
  FilamentEntity? _light;

  @override
  void initState() {
    type = widget.initialType;
    castShadows = widget.initialCastShadows;
    color = widget.initialColor;
    lightPos = widget.initialPosition;
    lightDir = widget.initialDirection;
    intensity = widget.initialIntensity;
    _set();
    super.initState();
  }

  Future _set() async {
    if (_light != null) await widget.controller.removeLight(_light!);

    _light = await widget.controller.addLight(
        type,
        color,
        intensity,
        lightPos.x,
        lightPos.y,
        lightPos.z,
        lightDir.x,
        lightDir.y,
        lightDir.z,
        castShadows);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_light == null || !widget.showControls) {
      return Container();
    }
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
                    Expanded(
                        child: Slider(
                            label: "POSX",
                            value: lightPos.x,
                            min: -10.0,
                            max: 10.0,
                            onChanged: (value) {
                              lightPos.x = value;
                              _set();
                            })),
                    Expanded(
                        child: Slider(
                            label: "POSY",
                            value: lightPos.y,
                            min: -10.0,
                            max: 10.0,
                            onChanged: (value) {
                              lightPos.y = value;
                              _set();
                            })),
                    Expanded(
                        child: Slider(
                            label: "POSZ",
                            value: lightPos.z,
                            min: -10.0,
                            max: 10.0,
                            onChanged: (value) {
                              lightPos.z = value;
                              _set();
                            }))
                  ]),
                  Row(children: [
                    Expanded(
                        child: Slider(
                            label: "DIRX",
                            value: lightDir.x,
                            min: -10.0,
                            max: 10.0,
                            onChanged: (value) {
                              lightDir.x = value;
                              _set();
                            })),
                    Expanded(
                        child: Slider(
                            label: "DIRY",
                            value: lightDir.y,
                            min: -10.0,
                            max: 10.0,
                            onChanged: (value) {
                              lightDir.y = value;
                              _set();
                            })),
                    Expanded(
                        child: Slider(
                            label: "DIRZ",
                            value: lightDir.z,
                            min: -10.0,
                            max: 10.0,
                            onChanged: (value) {
                              lightDir.z = value;
                              _set();
                            }))
                  ]),
                  Slider(
                      label: "Color",
                      value: color,
                      min: 0,
                      max: 16000,
                      onChanged: (value) {
                        color = value;
                        _set();
                      }),
                  Slider(
                      label: "Intensity",
                      value: intensity,
                      min: 0,
                      max: 1000000,
                      onChanged: (value) {
                        intensity = value;
                        _set();
                      }),
                  DropdownButton(
                      onChanged: (v) {
                        this.type = v;
                        _set();
                      },
                      value: type,
                      items: List<DropdownMenuItem>.generate(
                          5,
                          (idx) => DropdownMenuItem(
                                value: idx,
                                child: Text("$idx"),
                              ))),
                  Row(children: [
                    Text("Shadows: $castShadows"),
                    Checkbox(
                        value: castShadows,
                        onChanged: (v) {
                          this.castShadows = v!;
                          _set();
                        })
                  ])
                ]))));
  }
}

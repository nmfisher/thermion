
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_dart/thermion_dart/utils/light_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:vector_math/vector_math_64.dart' as v;

class LightSliderWidget extends StatefulWidget {
  final ThermionViewer controller;

  final LightOptions options;
  final bool showControls;

  LightSliderWidget(
      {super.key,
      required this.controller,
      this.showControls = false,
      required this.options});
  @override
  State<StatefulWidget> createState() => _LightSliderWidgetState();
}

class _LightSliderWidgetState extends State<LightSliderWidget> {
  ThermionEntity? _light;

  @override
  void initState() {
    _set();
    super.initState();
  }

  Future _set() async {
    await widget.controller.clearLights();

    if (widget.options.iblPath != null) {
      _light = await widget.controller.loadIbl(widget.options.iblPath!,
          intensity: widget.options.iblIntensity);
    }

    _light = await widget.controller.addLight(
      LightType.values[
        widget.options.directionalType],
        widget.options.directionalColor,
        widget.options.directionalIntensity,
        widget.options.directionalPosition.x,
        widget.options.directionalPosition.y,
        widget.options.directionalPosition.z,
        widget.options.directionalDirection.x,
        widget.options.directionalDirection.y,
        widget.options.directionalDirection.z,
        castShadows:widget.options.directionalCastShadows);

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
                data: const SliderThemeData(
                    showValueIndicator: ShowValueIndicator.always,
                    valueIndicatorTextStyle: TextStyle(color: Colors.black)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text("Directional"),
                  Row(children: [
                    Expanded(
                        child: Slider(
                            label:
                                "POSX ${widget.options.directionalPosition.x}",
                            value: widget.options.directionalPosition.x,
                            min: -10.0,
                            max: 10.0,
                            onChanged: (value) {
                              widget.options.directionalPosition.x = value;
                              _set();
                            })),
                    Expanded(
                        child: Slider(
                            label:
                                "POSY ${widget.options.directionalPosition.y}",
                            value: widget.options.directionalPosition.y,
                            min: -100.0,
                            max: 100.0,
                            onChanged: (value) {
                              widget.options.directionalPosition.y = value;
                              _set();
                            })),
                    Expanded(
                        child: Slider(
                            label:
                                "POSZ ${widget.options.directionalPosition.z}",
                            value: widget.options.directionalPosition.z,
                            min: -100.0,
                            max: 100.0,
                            onChanged: (value) {
                              widget.options.directionalPosition.z = value;
                              _set();
                            }))
                  ]),
                  Row(children: [
                    Expanded(
                        child: Slider(
                            label: "DIRX",
                            value: widget.options.directionalDirection.x,
                            min: -1.0,
                            max: 1.0,
                            onChanged: (value) {
                              widget.options.directionalDirection.x = value;
                              _set();
                            })),
                    Expanded(
                        child: Slider(
                            label: "DIRY",
                            value: widget.options.directionalDirection.y,
                            min: -1.0,
                            max: 1.0,
                            onChanged: (value) {
                              widget.options.directionalDirection.y = value;
                              _set();
                            })),
                    Expanded(
                        child: Slider(
                            label: "DIRZ",
                            value: widget.options.directionalDirection.z,
                            min: -1.0,
                            max: 1.0,
                            onChanged: (value) {
                              widget.options.directionalDirection.z = value;
                              _set();
                            }))
                  ]),
                  Slider(
                      label: "Color",
                      value: widget.options.directionalColor,
                      min: 0,
                      max: 16000,
                      onChanged: (value) {
                        widget.options.directionalColor = value;
                        _set();
                      }),
                  Slider(
                      label: "Intensity ${widget.options.directionalIntensity}",
                      value: widget.options.directionalIntensity,
                      min: 0,
                      max: 1000000,
                      onChanged: (value) {
                        widget.options.directionalIntensity = value;
                        _set();
                      }),
                  DropdownButton(
                      onChanged: (v) {
                        this.widget.options.directionalType = v;
                        _set();
                      },
                      value: this.widget.options.directionalType,
                      items: List<DropdownMenuItem>.generate(
                          5,
                          (idx) => DropdownMenuItem(
                                value: idx,
                                child: Text("$idx"),
                              ))),
                  Row(children: [
                    Text(
                        "Shadows: ${this.widget.options.directionalCastShadows}"),
                    Checkbox(
                        value: widget.options.directionalCastShadows,
                        onChanged: (v) {
                          this.widget.options.directionalCastShadows = v!;
                          _set();
                        })
                  ]),
                  Text("Indirect"),
                  Row(children: [
                    Expanded(
                        child: Slider(
                            label: "Intensity ${widget.options.iblIntensity}",
                            value: widget.options.iblIntensity,
                            min: 0.0,
                            max: 200000,
                            onChanged: (value) {
                              widget.options.iblIntensity = value;
                              _set();
                            })),
                  ])
                ]))));
  }
}

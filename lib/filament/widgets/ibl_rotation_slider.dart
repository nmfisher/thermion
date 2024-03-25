import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/filament/filament_controller.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class IblRotationSliderWidget extends StatefulWidget {
  final FilamentController controller;

  const IblRotationSliderWidget({super.key, required this.controller});
  @override
  State<StatefulWidget> createState() => _IblRotationSliderWidgetState();
}

class _IblRotationSliderWidgetState extends State<IblRotationSliderWidget> {
  double _iblRotation = 0;
  @override
  Widget build(BuildContext context) {
    return Slider(
        value: _iblRotation,
        onChanged: (value) {
          _iblRotation = value;
          setState(() {});
          print(value);
          var rotation = v.Matrix3.identity();
          Matrix4.rotationY(value * 2 * pi).copyRotation(rotation);
          widget.controller.rotateIbl(rotation);
        });
  }
}

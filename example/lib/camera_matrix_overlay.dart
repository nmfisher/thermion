import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/filament_controller.dart';

class CameraMatrixOverlay extends StatefulWidget {
  final FilamentController controller;

  CameraMatrixOverlay({super.key, required this.controller});

  @override
  State<StatefulWidget> createState() => _CameraMatrixOverlayState();
}

class _CameraMatrixOverlayState extends State<CameraMatrixOverlay> {
  Timer? _cameraTimer;
  String? _cameraPosition;
  String? _cameraRotation;

  @override
  void initState() {
    super.initState();

    _cameraTimer =
        Timer.periodic(const Duration(milliseconds: 50), (timer) async {
      var cameraPosition = await widget.controller.getCameraPosition();
      var cameraRotation = await widget.controller.getCameraRotation();
      _cameraPosition = cameraPosition.toString();
      _cameraRotation = cameraRotation.toString();
      setState(() {});
    });
  }

  @override
  void dispose() {
    super.dispose();
    _cameraTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(29)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text("Camera position : $_cameraPosition $_cameraRotation",
            style: const TextStyle(color: Colors.white, fontSize: 12)));
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/filament_controller.dart';

class CameraMatrixOverlay extends StatefulWidget {
  final FilamentController controller;
  final bool showProjectionMatrices;

  const CameraMatrixOverlay(
      {super.key,
      required this.controller,
      required this.showProjectionMatrices});

  @override
  State<StatefulWidget> createState() => _CameraMatrixOverlayState();
}

class _CameraMatrixOverlayState extends State<CameraMatrixOverlay> {
  Timer? _cameraTimer;
  String? _cameraPosition;
  String? _cameraRotation;

  String? _cameraProjectionMatrix;
  String? _cameraCullingProjectionMatrix;

  void _tick(Timer timer) async {
    var cameraPosition = await widget.controller.getCameraPosition();
    var cameraRotation = await widget.controller.getCameraRotation();

    _cameraPosition =
        "${cameraPosition.storage.map((v) => v.toStringAsFixed(2))}";
    _cameraRotation =
        "${cameraRotation.storage.map((v) => v.toStringAsFixed(2))}";

    if (widget.showProjectionMatrices) {
      var projMatrix = await widget.controller.getCameraProjectionMatrix();
      var cullingMatrix =
          await widget.controller.getCameraCullingProjectionMatrix();

      _cameraProjectionMatrix =
          projMatrix.storage.map((v) => v.toStringAsFixed(2)).join(",");
      _cameraCullingProjectionMatrix =
          cullingMatrix.storage.map((v) => v.toStringAsFixed(2)).join(",");
    }

    setState(() {});
  }

  void _updateTimer() {
    _cameraTimer?.cancel();
    if (widget.controller.hasViewer.value) {
      _cameraTimer = Timer.periodic(const Duration(milliseconds: 50), _tick);
    }
  }

  @override
  void initState() {
    super.initState();

    _updateTimer();

    widget.controller.hasViewer.addListener(_updateTimer);
  }

  @override
  void didUpdateWidget(CameraMatrixOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
    widget.controller.hasViewer.removeListener(_updateTimer);
    _cameraTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(29)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Camera position : $_cameraPosition $_cameraRotation",
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
              widget.showProjectionMatrices
                  ? Text("Projection matrix : $_cameraProjectionMatrix",
                      style: const TextStyle(color: Colors.white, fontSize: 12))
                  : Container(),
              widget.showProjectionMatrices
                  ? Text("Culling matrix : $_cameraCullingProjectionMatrix",
                      style: const TextStyle(color: Colors.white, fontSize: 12))
                  : Container(),
            ]));
  }
}

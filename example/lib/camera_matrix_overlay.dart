import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart';
import 'package:vector_math/vector_math_64.dart' as v;

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
      _getFrustum();
    }

    setState(() {});
  }

  void _updateTimer() {
    _cameraTimer?.cancel();
    if (widget.controller.hasViewer.value) {
      _cameraTimer = Timer.periodic(const Duration(milliseconds: 50), _tick);
    }
  }

  v.Frustum? _frustum;

  void _getFrustum() async {
    _frustum = await widget.controller.getCameraFrustum();
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
            children: <Widget>[
                  Text("Camera : $_cameraPosition $_cameraRotation",
                      style:
                          const TextStyle(color: Colors.white, fontSize: 10)),
                  // widget.showProjectionMatrices
                  //     ? Text("Projection matrix : $_cameraProjectionMatrix",
                  //         style: const TextStyle(color: Colors.white, fontSize: 12))
                  //     : Container(),
                  // widget.showProjectionMatrices
                  //     ? Text("Culling matrix : $_cameraCullingProjectionMatrix",
                  //         style: const TextStyle(color: Colors.white, fontSize: 12))
                  //     : Container(),
                  widget.showProjectionMatrices
                      ? const Text("Frustum matrix",
                          style: TextStyle(color: Colors.white, fontSize: 10))
                      : Container()
                ] +
                (_frustum == null
                    ? []
                    : [
                        _frustum!.plane0,
                        _frustum!.plane1,
                        _frustum!.plane2,
                        _frustum!.plane3,
                        _frustum!.plane4,
                        _frustum!.plane5
                      ]
                        .map((plane) => Row(
                                children: [
                              plane.normal.x,
                              plane.normal.y,
                              plane.normal.z,
                              plane.constant
                            ]
                                    .map((v) => Text(
                                          v.toStringAsFixed(2) + " ",
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10),
                                          textAlign: TextAlign.center,
                                        ))
                                    .cast<Widget>()
                                    .toList()))
                        .cast<Widget>()
                        .toList())));
  }
}

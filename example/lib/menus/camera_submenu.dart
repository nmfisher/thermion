import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:flutter_filament/filament_controller.dart';
import 'package:flutter_filament_example/main.dart';

class CameraSubmenu extends StatefulWidget {
  final FilamentController controller;
  const CameraSubmenu({super.key, required this.controller});

  @override
  State<StatefulWidget> createState() => _CameraSubmenuState();
}

class _CameraSubmenuState extends State<CameraSubmenu> {
  List<Widget> _cameraMenu() {
    return [
      MenuItemButton(
        onPressed: () async {
          widget.controller.setCameraPosition(1.0, 1.0, -1.0);
        },
        child: const Text('Move to 1, 1, -1'),
      ),
      MenuItemButton(
        onPressed: ExampleWidgetState.last == null
            ? null
            : () async {
                await widget.controller
                    .setCamera(ExampleWidgetState.last!, null);
              },
        child: const Text('Set to first camera in last added asset'),
      ),
      MenuItemButton(
        onPressed: ExampleWidgetState.last == null
            ? null
            : () async {
                await widget.controller
                    .moveCameraToAsset(ExampleWidgetState.last!);
              },
        child: const Text("Move to last added asset"),
      ),
      MenuItemButton(
        onPressed: () {
          widget.controller.setCameraRotation(pi / 4, 0.0, 1.0, 0.0);
        },
        child: const Text("Rotate camera 45 degrees around y axis"),
      ),
      MenuItemButton(
        onPressed: () {
          ExampleWidgetState.frustumCulling =
              !ExampleWidgetState.frustumCulling;
          widget.controller
              .setViewFrustumCulling(ExampleWidgetState.frustumCulling);
        },
        child: Text(
            "${ExampleWidgetState.frustumCulling ? "Disable" : "Enable"} frustum culling"),
      ),
      MenuItemButton(
          closeOnActivate: false,
          onPressed: () async {
            var projMatrix =
                await widget.controller.getCameraProjectionMatrix();
            await showDialog(
                context: context,
                builder: (ctx) {
                  return Center(
                      child: Container(
                          height: 100,
                          width: 300,
                          color: Colors.white,
                          child: Text(projMatrix.storage
                              .map((v) => v.toStringAsFixed(2))
                              .join(","))));
                });
          },
          child: const Text("Get projection matrix")),
      MenuItemButton(
          closeOnActivate: false,
          onPressed: () async {
            var frustum = await widget.controller.getCameraFrustum();
            await showDialog(
                context: context,
                builder: (ctx) {
                  return Center(
                      child: Container(
                          height: 300,
                          width: 300,
                          color: Colors.white,
                          child: Column(
                              children: frustum
                                  .map((vector) => Text(vector.storage
                                      .map((v) => v.toStringAsFixed(2))
                                      .join(",")))
                                  .toList())));
                });
          },
          child: const Text("Get frustum")),
      SubmenuButton(
          menuChildren: ManipulatorMode.values.map((mm) {
            return MenuItemButton(
              onPressed: () {
                ExampleWidgetState.cameraManipulatorMode = mm;
                widget.controller.setCameraManipulatorOptions(
                    mode: ExampleWidgetState.cameraManipulatorMode,
                    orbitSpeedX: ExampleWidgetState.orbitSpeedX,
                    orbitSpeedY: ExampleWidgetState.orbitSpeedY,
                    zoomSpeed: ExampleWidgetState.zoomSpeed);
              },
              child: Text(
                mm.name,
                style: TextStyle(
                    fontWeight: ExampleWidgetState.cameraManipulatorMode == mm
                        ? FontWeight.bold
                        : FontWeight.normal),
              ),
            );
          }).toList(),
          child: const Text("Manipulator mode")),
      SubmenuButton(
          menuChildren: [0.01, 0.1, 1.0, 10.0, 100.0].map((speed) {
            return MenuItemButton(
              onPressed: () {
                ExampleWidgetState.zoomSpeed = speed;
                widget.controller.setCameraManipulatorOptions(
                    mode: ExampleWidgetState.cameraManipulatorMode,
                    orbitSpeedX: ExampleWidgetState.orbitSpeedX,
                    orbitSpeedY: ExampleWidgetState.orbitSpeedY,
                    zoomSpeed: ExampleWidgetState.zoomSpeed);
              },
              child: Text(
                speed.toString(),
                style: TextStyle(
                    fontWeight:
                        (speed - ExampleWidgetState.zoomSpeed).abs() < 0.0001
                            ? FontWeight.bold
                            : FontWeight.normal),
              ),
            );
          }).toList(),
          child: const Text("Zoom speed")),
      SubmenuButton(
          menuChildren: [0.001, 0.01, 0.1, 1.0].map((speed) {
            return MenuItemButton(
              onPressed: () {
                ExampleWidgetState.orbitSpeedX = speed;
                ExampleWidgetState.orbitSpeedY = speed;
                widget.controller.setCameraManipulatorOptions(
                    mode: ExampleWidgetState.cameraManipulatorMode,
                    orbitSpeedX: ExampleWidgetState.orbitSpeedX,
                    orbitSpeedY: ExampleWidgetState.orbitSpeedY,
                    zoomSpeed: ExampleWidgetState.zoomSpeed);
              },
              child: Text(
                speed.toString(),
                style: TextStyle(
                    fontWeight:
                        (speed - ExampleWidgetState.orbitSpeedX).abs() < 0.0001
                            ? FontWeight.bold
                            : FontWeight.normal),
              ),
            );
          }).toList(),
          child: const Text("Orbit speed (X & Y)"))
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SubmenuButton(
      menuChildren: _cameraMenu(),
      child: const Text("Camera"),
    );
  }
}

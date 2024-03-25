import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;
import 'package:flutter_filament/flutter_filament.dart';

import 'package:flutter_filament_example/main.dart';

class CameraSubmenu extends StatefulWidget {
  final FilamentController controller;
  const CameraSubmenu({super.key, required this.controller});

  @override
  State<StatefulWidget> createState() => _CameraSubmenuState();
}

class _CameraSubmenuState extends State<CameraSubmenu> {
  double? _near;
  double? _far;

  @override
  void initState() {
    super.initState();
    widget.controller.getCameraCullingNear().then((v) {
      _near = v;
      widget.controller.getCameraCullingFar().then((v) {
        _far = v;
        setState(() {});
      });
    });
  }

  final _menuController = MenuController();

  List<Widget> _cameraMenu() {
    return [
      MenuItemButton(
        closeOnActivate: false,
        onPressed: () async {
          ExampleWidgetState.showProjectionMatrices.value =
              !ExampleWidgetState.showProjectionMatrices.value;
          print("Set to ${ExampleWidgetState.showProjectionMatrices}");
        },
        child: Text(
          '${ExampleWidgetState.showProjectionMatrices.value ? "Hide" : "Display"} camera frustum',
          style: TextStyle(
              fontWeight: ExampleWidgetState.showProjectionMatrices.value
                  ? FontWeight.bold
                  : FontWeight.normal),
        ),
      ),
      SubmenuButton(
          menuChildren: [1.0, 7.0, 14.0, 28.0, 56.0]
              .map((v) => MenuItemButton(
                    onPressed: () {
                      widget.controller.setCameraFocalLength(v);
                    },
                    child: Text(
                      v.toStringAsFixed(2),
                    ),
                  ))
              .toList(),
          child: const Text("Set camera focal length")),
      SubmenuButton(
          menuChildren: [0.05, 0.1, 1.0, 10.0, 100.0]
              .map((v) => MenuItemButton(
                    onPressed: () {
                      _near = v;
                      print("Setting camera culling to $_near $_far!");

                      widget.controller.setCameraCulling(_near!, _far!);
                    },
                    child: Text(
                      v.toStringAsFixed(2),
                    ),
                  ))
              .toList(),
          child: const Text("Set near")),
      SubmenuButton(
          menuChildren: [5.0, 50.0, 500.0, 1000.0, 100000.0]
              .map((v) => MenuItemButton(
                    onPressed: () {
                      _far = v;
                      print("Setting camera culling to $_near! $_far");
                      widget.controller.setCameraCulling(_near!, _far!);
                    },
                    child: Text(
                      v.toStringAsFixed(2),
                    ),
                  ))
              .toList(),
          child: const Text("Set far")),
      MenuItemButton(
        onPressed: () async {
          widget.controller.setCameraPosition(1.0, 1.0, -1.0);
        },
        child: const Text('Set position to 1, 1, -1 (leave rotation as-is)'),
      ),
      MenuItemButton(
        onPressed: () async {
          widget.controller.setCameraPosition(0.0, 0.0, 0.0);
          widget.controller.setCameraRotation(
              v.Quaternion.axisAngle(v.Vector3(0, 0.0, 1.0), 0.0));
        },
        child: const Text('Move to 0,0,0, facing towards 0,0,-1'),
      ),
      MenuItemButton(
        onPressed: () {
          widget.controller.setCameraRotation(
              v.Quaternion.axisAngle(v.Vector3(0, 1, 0), pi / 4));
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
    if (_near == null || _far == null) {
      return Container();
    }
    return SubmenuButton(
      controller: _menuController,
      menuChildren: _cameraMenu(),
      child: const Text("Camera"),
    );
  }
}

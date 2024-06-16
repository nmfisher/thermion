import 'dart:io';

import 'package:dart_filament/dart_filament/abstract_filament_viewer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'filament_gesture_detector_desktop.dart';
import 'filament_gesture_detector_mobile.dart';

enum GestureType { rotateCamera, panCamera, panBackground }

///
/// A widget that translates finger/mouse gestures to zoom/pan/rotate actions.
///
class FilamentGestureDetector extends StatelessWidget {
  ///
  /// The content to display below the gesture detector/listener widget.
  /// This will usually be a FilamentWidget (so you can navigate by directly interacting with the viewport), but this is not necessary.
  /// It is equally possible to render the viewport/gesture controls elsewhere in the widget hierarchy. The only requirement is that they share the same [FilamentController].
  ///
  final Widget? child;

  ///
  /// The [controller] attached to the [FilamentWidget] you wish to control.
  ///
  final AbstractFilamentViewer controller;

  ///
  /// If true, an overlay will be shown with buttons to toggle whether pointer movements are interpreted as:
  /// 1) rotate or a pan (mobile only),
  /// 2) moving the camera or the background image (TODO).
  ///
  final bool showControlOverlay;

  ///
  /// If false, gestures will not manipulate the active camera.
  ///
  final bool enableCamera;

  ///
  /// If false, pointer down events will not trigger hit-testing (picking).
  ///
  final bool enablePicking;

  final void Function(ScaleStartDetails)? onScaleStart;
  final void Function(ScaleUpdateDetails)? onScaleUpdate;
  final void Function(ScaleEndDetails)? onScaleEnd;

  const FilamentGestureDetector(
      {Key? key,
      required this.controller,
      this.child,
      this.showControlOverlay = false,
      this.enableCamera = true,
      this.enablePicking = true,
      this.onScaleStart,
      this.onScaleUpdate,
      this.onScaleEnd})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: controller.initialized,
        builder: (_, initialized) {
          if (initialized.data != true) {
            return child ?? Container();
          }
          if (kIsWeb || Platform.isLinux ||
              Platform.isWindows ||
              Platform.isMacOS) {
            return FilamentGestureDetectorDesktop(
              controller: controller,
              child: child,
              showControlOverlay: showControlOverlay,
              enableCamera: enableCamera,
              enablePicking: enablePicking,
            );
          } else {
            return FilamentGestureDetectorMobile(
                controller: controller,
                child: child,
                showControlOverlay: showControlOverlay,
                enableCamera: enableCamera,
                enablePicking: enablePicking,
                onScaleStart: onScaleStart,
                onScaleUpdate: onScaleUpdate,
                onScaleEnd: onScaleEnd);
          }
        });
  }
}

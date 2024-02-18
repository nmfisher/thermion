import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_filament/widgets/filament_gesture_detector_desktop.dart';
import 'package:flutter_filament/widgets/filament_gesture_detector_mobile.dart';
import '../filament_controller.dart';

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
  final FilamentController controller;

  ///
  /// If true, an overlay will be shown with buttons to toggle whether pointer movements are interpreted as:
  /// 1) rotate or a pan (mobile only),
  /// 2) moving the camera or the background image (TODO).
  ///
  final bool showControlOverlay;

  ///
  /// If false, all gestures will be ignored.
  ///
  final bool enabled;

  const FilamentGestureDetector(
      {Key? key,
      required this.controller,
      this.child,
      this.showControlOverlay = false,
      this.enabled = true})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      throw Exception("TODO");
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return FilamentGestureDetectorDesktop(
        controller: controller,
        child: child,
        showControlOverlay: showControlOverlay,
        listenerEnabled: enabled,
      );
    } else {
      return FilamentGestureDetectorMobile(
        controller: controller,
        child: child,
        showControlOverlay: showControlOverlay,
        listenerEnabled: enabled,
      );
    }
  }
}

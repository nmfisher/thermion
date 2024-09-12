import 'dart:io';

import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'thermion_gesture_detector_desktop.dart';
import 'thermion_gesture_detector_mobile.dart';

enum GestureType { rotateCamera, panCamera, panBackground }

///
/// A widget that translates finger/mouse gestures to zoom/pan/rotate actions.
///
class ThermionGestureDetector extends StatelessWidget {
  ///
  /// The content to display below the gesture detector/listener widget.
  /// This will usually be a ThermionWidget (so you can navigate by directly interacting with the viewport), but this is not necessary.
  /// It is equally possible to render the viewport/gesture controls elsewhere in the widget hierarchy. The only requirement is that they share the same [Filamentviewer].
  ///
  final Widget? child;

  ///
  /// The [viewer] attached to the [ThermionWidget] you wish to control.
  ///
  final ThermionViewer viewer;

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

  const ThermionGestureDetector(
      {Key? key,
      required this.viewer,
      this.child,
      this.showControlOverlay = false,
      this.enableCamera = true,
      this.enablePicking = false,
      this.onScaleStart,
      this.onScaleUpdate,
      this.onScaleEnd})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: viewer.initialized,
        builder: (_, initialized) {
          if (initialized.data != true) {
            return child ?? Container();
          }
          if (kIsWeb || Platform.isLinux ||
              Platform.isWindows ||
              Platform.isMacOS) {
            return ThermionGestureDetectorDesktop(
              viewer: viewer,
              child: child,
              showControlOverlay: showControlOverlay,
              enableCamera: enableCamera,
              enablePicking: enablePicking,
            );
          } else {
            return ThermionGestureDetectorMobile(
                viewer: viewer,
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

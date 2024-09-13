import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/thermion_gesture_handler.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/thermion_gesture_detector_desktop_widget.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/thermion_gesture_detector_mobile_widget.dart';

///
/// A widget that captures swipe/pointer events.
/// This is a dumb listener that simply forwards events to the provided [ThermionGestureHandler].
///
class ThermionListenerWidget extends StatelessWidget {
  ///
  /// The content to display below the gesture detector/listener widget.
  /// This will usually be a ThermionWidget (so you can navigate by directly interacting with the viewport), but this is not necessary.
  /// It is equally possible to render the viewport/gesture controls elsewhere in the widget hierarchy. The only requirement is that they share the same [FilamentViewer].
  ///
  final Widget? child;

  ///
  /// The handler to use for interpreting gestures/pointer movements.
  ///
  final ThermionGestureHandler gestureHandler;

  ThermionListenerWidget({
    Key? key,
    required this.gestureHandler,
    this.child,
  }) : super(key: key);

  bool get isDesktop => kIsWeb ||
                Platform.isLinux ||
                Platform.isWindows ||
                Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: gestureHandler.initialized,
        builder: (_, initialized) {
          if (initialized.data != true) {
            return child ?? Container();
          }
          return Stack(children: [
            if(child != null)
              Positioned.fill(child:child!),
            if (isDesktop)
            Positioned.fill(child:ThermionGestureDetectorDesktop(
                  gestureHandler: gestureHandler)),
            if(!isDesktop)
            Positioned.fill(child:ThermionGestureDetectorMobile(
                  gestureHandler: gestureHandler))
          ]);
        });
  }
}

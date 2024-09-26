import 'dart:async';
import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart/entities/abstract_gizmo.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/src/widgets/camera/gestures/thermion_gesture_handler.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class ThermionGestureDetectorDesktop extends StatefulWidget {
  final Widget? child;
  final ThermionGestureHandler gestureHandler;
  final bool showControlOverlay;
  final bool enableCamera;
  final bool enablePicking;

  const ThermionGestureDetectorDesktop({
    Key? key,
    required this.gestureHandler,
    this.child,
    this.showControlOverlay = false,
    this.enableCamera = true,
    this.enablePicking = true,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ThermionGestureDetectorDesktopState();
}

class _ThermionGestureDetectorDesktopState
    extends State<ThermionGestureDetectorDesktop> {
  
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (event) =>
          widget.gestureHandler.onPointerHover(event.localPosition, event.delta),
      onPointerSignal: (PointerSignalEvent pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          widget.gestureHandler.onPointerScroll(
              pointerSignal.localPosition, pointerSignal.scrollDelta.dy);
        }
      },
      onPointerPanZoomStart: (pzs) {
        throw Exception("TODO - is this a pinch zoom on laptop trackpad?");
      },
      onPointerDown: (d) =>
          widget.gestureHandler.onPointerDown(d.localPosition, d.buttons),
      onPointerMove: (d) =>
          widget.gestureHandler.onPointerMove(d.localPosition, d.delta, d.buttons),
      onPointerUp: (d) => widget.gestureHandler.onPointerUp(d.buttons),
      child: widget.child,
    );
  }
}

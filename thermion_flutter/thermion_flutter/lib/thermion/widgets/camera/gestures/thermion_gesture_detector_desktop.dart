import 'dart:async';
import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart/entities/abstract_gizmo.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/thermion_gesture_handler.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class ThermionGestureDetectorDesktop extends StatefulWidget {
  final Widget? child;
  final ThermionViewer controller;
  final bool showControlOverlay;
  final bool enableCamera;
  final bool enablePicking;

  const ThermionGestureDetectorDesktop({
    Key? key,
    required this.controller,
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
  late ThermionGestureHandler _gestureHandler;

  @override
  void initState() {
    super.initState();
    _gestureHandler = ThermionGestureHandler(
      enableCamera: widget.enableCamera,
      enablePicking: widget.enablePicking, viewer: widget.controller,
    );
  }

  @override
  void didUpdateWidget(ThermionGestureDetectorDesktop oldWidget) {
    if (widget.enableCamera != oldWidget.enableCamera ||
        widget.enablePicking != oldWidget.enablePicking) {
      _gestureHandler = ThermionGestureHandler(
        viewer: widget.controller,
        enableCamera: widget.enableCamera,
        enablePicking: widget.enablePicking,
      );
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (event) =>
          _gestureHandler.onPointerHover(event.localPosition),
      onPointerSignal: (PointerSignalEvent pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          _gestureHandler.onPointerScroll(
              pointerSignal.localPosition, pointerSignal.scrollDelta.dy);
        }
      },
      onPointerPanZoomStart: (pzs) {
        throw Exception("TODO - is this a pinch zoom on laptop trackpad?");
      },
      onPointerDown: (d) =>
          _gestureHandler.onPointerDown(d.localPosition, d.buttons),
      onPointerMove: (d) => _gestureHandler.onPointerMove(
          d.localPosition, d.delta, d.buttons),
      onPointerUp: (d) => _gestureHandler.onPointerUp(d.buttons),
      child: widget.child,
    );
  }
}
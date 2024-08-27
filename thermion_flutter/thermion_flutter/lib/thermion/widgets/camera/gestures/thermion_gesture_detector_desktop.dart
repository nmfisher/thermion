import 'dart:async';
import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart/entities/abstract_gizmo.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

///
/// A widget that translates finger/mouse gestures to zoom/pan/rotate actions.
///
class ThermionGestureDetectorDesktop extends StatefulWidget {
  ///
  /// The content to display below the gesture detector/listener widget.
  /// This will usually be a ThermionWidget (so you can navigate by directly interacting with the viewport), but this is not necessary.
  /// It is equally possible to render the viewport/gesture controls elsewhere in the widget hierarchy. The only requirement is that they share the same [FilamentController].
  ///
  final Widget? child;

  ///
  /// The [controller] attached to the [ThermionWidget] you wish to control.
  ///
  final ThermionViewer controller;

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

  const ThermionGestureDetectorDesktop(
      {Key? key,
      required this.controller,
      this.child,
      this.showControlOverlay = false,
      this.enableCamera = true,
      this.enablePicking = true})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _ThermionGestureDetectorDesktopState();
}

class _ThermionGestureDetectorDesktopState
    extends State<ThermionGestureDetectorDesktop> {
  final _logger = Logger("_ThermionGestureDetectorDesktopState");

  ///
  ///
  // ignore: unused_field
  final bool _scaling = false;

  bool _pointerMoving = false;

  AbstractGizmo? _gizmo;

  @override
  void initState() {
    super.initState();
    try {
      _gizmo = widget.controller.gizmo;
    } catch (err) {
      _logger.warning(
          "Failed to get gizmo. If you are running on WASM, this is expected");
    }
  }

  @override
  void didUpdateWidget(ThermionGestureDetectorDesktop oldWidget) {
    if (widget.showControlOverlay != oldWidget.showControlOverlay ||
        widget.enableCamera != oldWidget.enableCamera ||
        widget.enablePicking != oldWidget.enablePicking) {
      setState(() {});
    }

    super.didUpdateWidget(oldWidget);
  }

  Timer? _scrollTimer;

  ///
  /// Scroll-wheel on desktop, interpreted as zoom
  ///
  void _zoom(PointerScrollEvent pointerSignal) async {
    _scrollTimer?.cancel();
    await widget.controller.zoomBegin();
    await widget.controller.zoomUpdate(
        pointerSignal.localPosition.dx,
        pointerSignal.localPosition.dy,
        pointerSignal.scrollDelta.dy > 0 ? 1 : -1);

    // we don't want to end the zoom in the same frame, because this will destroy the camera manipulator (and cancel the zoom update).
    // here, we just defer calling [zoomEnd] for 100ms to ensure the update is propagated through.
    _scrollTimer = Timer(const Duration(milliseconds: 100), () async {
      await widget.controller.zoomEnd();
    });
  }

  Timer? _pickTimer;

  @override
  Widget build(BuildContext context) {
    return Listener(
        onPointerHover: (event) async {
          _gizmo?.checkHover(event.localPosition.dx, event.localPosition.dy);
        },
        onPointerSignal: (PointerSignalEvent pointerSignal) async {
          if (pointerSignal is PointerScrollEvent) {
            if (widget.enableCamera) {
              _zoom(pointerSignal);
            }
          } else {
            throw Exception("TODO");
          }
        },
        onPointerPanZoomStart: (pzs) {
          throw Exception("TODO - is this a pinch zoom on laptop trackpad?");
        },
        onPointerDown: (d) async {
          if (d.buttons != kTertiaryButton && widget.enablePicking) {
            widget.controller
                .pick(d.localPosition.dx.toInt(), d.localPosition.dy.toInt());
          }
          _pointerMoving = false;
        },
        // holding/moving the left mouse button is interpreted as a pan, middle mouse button as a rotate
        onPointerMove: (PointerMoveEvent d) async {
          if (_gizmo?.isHovered == true) {
            _gizmo!.translate(d.delta.dx, d.delta.dy);
            return;
          }
          // if this is the first move event, we need to call rotateStart/panStart to set the first coordinates
          if (!_pointerMoving) {
            if (d.buttons == kTertiaryButton && widget.enableCamera) {
              widget.controller
                  .rotateStart(d.localPosition.dx, d.localPosition.dy);
            } else if (widget.enableCamera) {
              widget.controller
                  .panStart(d.localPosition.dx, d.localPosition.dy);
            }
          }
          // set the _pointerMoving flag so we don't call rotateStart/panStart on future move events
          _pointerMoving = true;
          if (d.buttons == kTertiaryButton && widget.enableCamera) {
            widget.controller
                .rotateUpdate(d.localPosition.dx, d.localPosition.dy);
          } else if (widget.enableCamera) {
            widget.controller.panUpdate(d.localPosition.dx, d.localPosition.dy);
          }
        },
        // when the left mouse button is released:
        // 1) if _pointerMoving is true, this completes the pan
        // 2) if _pointerMoving is false, this is interpreted as a pick
        // same applies to middle mouse button, but this is ignored as a pick
        onPointerUp: (PointerUpEvent d) async {
          if (_gizmo?.isHovered == true) {
            return;
          }

          if (d.buttons == kTertiaryButton && widget.enableCamera) {
            widget.controller.rotateEnd();
          } else {
            if (_pointerMoving && widget.enableCamera) {
              widget.controller.panEnd();
            }
          }
          _pointerMoving = false;
        },
        child: widget.child);
  }
}

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../filament_controller.dart';

///
/// A widget that translates finger/mouse gestures to zoom/pan/rotate actions.
///
class FilamentGestureDetectorDesktop extends StatefulWidget {
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
  final bool listenerEnabled;

  const FilamentGestureDetectorDesktop(
      {Key? key,
      required this.controller,
      this.child,
      this.showControlOverlay = false,
      this.listenerEnabled = true})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _FilamentGestureDetectorDesktopState();
}

class _FilamentGestureDetectorDesktopState
    extends State<FilamentGestureDetectorDesktop> {
  ///
  ///
  ///
  bool _scaling = false;

  bool _pointerMoving = false;

  @override
  void didUpdateWidget(FilamentGestureDetectorDesktop oldWidget) {
    if (widget.showControlOverlay != oldWidget.showControlOverlay ||
        widget.listenerEnabled != oldWidget.listenerEnabled) {
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
    _scrollTimer = Timer(Duration(milliseconds: 100), () async {
      await widget.controller.zoomEnd();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.listenerEnabled) {
      return widget.child ?? Container();
    }
    return Listener(
        onPointerSignal: (PointerSignalEvent pointerSignal) async {
          if (pointerSignal is PointerScrollEvent) {
            _zoom(pointerSignal);
          } else {
            throw Exception("TODO");
          }
        },
        onPointerPanZoomStart: (pzs) {
          throw Exception("TODO - is this a pinch zoom on laptop trackpad?");
        },
        // ignore all pointer down events
        // so we can wait to see if the pointer will be held/moved (interpreted as rotate/pan),
        // or if this is a single mousedown event (interpreted as viewport pick)
        onPointerDown: (d) async {},
        // holding/moving the left mouse button is interpreted as a pan, middle mouse button as a rotate
        onPointerMove: (PointerMoveEvent d) async {
          // if this is the first move event, we need to call rotateStart/panStart to set the first coordinates
          if (!_pointerMoving) {
            if (d.buttons == kTertiaryButton) {
              widget.controller
                  .rotateStart(d.localPosition.dx, d.localPosition.dy);
            } else {
              widget.controller
                  .panStart(d.localPosition.dx, d.localPosition.dy);
            }
          }
          // set the _pointerMoving flag so we don't call rotateStart/panStart on future move events
          _pointerMoving = true;
          if (d.buttons == kTertiaryButton) {
            widget.controller
                .rotateUpdate(d.localPosition.dx, d.localPosition.dy);
          } else {
            widget.controller.panUpdate(d.localPosition.dx, d.localPosition.dy);
          }
        },
        // when the left mouse button is released:
        // 1) if _pointerMoving is true, this completes the pan
        // 2) if _pointerMoving is false, this is interpreted as a pick
        // same applies to middle mouse button, but this is ignored as a pick
        onPointerUp: (PointerUpEvent d) async {
          if (d.buttons == kTertiaryButton) {
            widget.controller.rotateEnd();
          } else {
            if (_pointerMoving) {
              widget.controller.panEnd();
            } else {
              widget.controller
                  .pick(d.localPosition.dx.toInt(), d.localPosition.dy.toInt());
            }
          }
          _pointerMoving = false;
        },
        child: widget.child);
  }
}

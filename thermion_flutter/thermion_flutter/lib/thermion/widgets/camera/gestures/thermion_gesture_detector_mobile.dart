import 'dart:async';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:flutter/material.dart';

enum GestureType { rotateCamera, panCamera, panBackground }

///
/// A widget that translates finger/mouse gestures to zoom/pan/rotate actions.
///
class ThermionGestureDetectorMobile extends StatefulWidget {
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

  final double zoomDelta;

  final void Function(ScaleStartDetails)? onScaleStart;
  final void Function(ScaleUpdateDetails)? onScaleUpdate;
  final void Function(ScaleEndDetails)? onScaleEnd;

  const ThermionGestureDetectorMobile(
      {Key? key,
      required this.viewer,
      this.child,
      this.showControlOverlay = false,
      this.enableCamera = true,
      this.enablePicking = true,
      this.onScaleStart,
      this.onScaleUpdate,
      this.onScaleEnd,
      this.zoomDelta = 1})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _ThermionGestureDetectorMobileState();
}

class _ThermionGestureDetectorMobileState
    extends State<ThermionGestureDetectorMobile> {
  GestureType gestureType = GestureType.panCamera;

  final _icons = {
    GestureType.panBackground: Icons.image,
    GestureType.panCamera: Icons.pan_tool,
    GestureType.rotateCamera: Icons.rotate_90_degrees_ccw
  };

  // on mobile, we can't differentiate between pointer down events like we do on desktop with primary/secondary/tertiary buttons
  // we allow the user to toggle between panning and rotating by double-tapping the widget
  bool _rotateOnPointerMove = false;

  //
  //
  //
  bool _scaling = false;

  // to avoid duplicating code for pan/rotate (panStart, panUpdate, panEnd, rotateStart, rotateUpdate etc)
  // we have only a single function for start/update/end.
  // when the gesture type is changed, these properties are updated to point to the correct function.
  // ignore: unused_field
  late Function(double x, double y) _functionStart;
  // ignore: unused_field
  late Function(double x, double y) _functionUpdate;
  // ignore: unused_field
  late Function() _functionEnd;

  @override
  void initState() {
    _setFunction();
    super.initState();
  }

  void _setFunction() {
    switch (gestureType) {
      case GestureType.rotateCamera:
        _functionStart = widget.viewer.rotateStart;
        _functionUpdate = widget.viewer.rotateUpdate;
        _functionEnd = widget.viewer.rotateEnd;
        break;
      case GestureType.panCamera:
        _functionStart = widget.viewer.panStart;
        _functionUpdate = widget.viewer.panUpdate;
        _functionEnd = widget.viewer.panEnd;
        break;
      // TODO
      case GestureType.panBackground:
        _functionStart = (x, y) async {};
        _functionUpdate = (x, y) async {};
        _functionEnd = () async {};
    }
  }

  @override
  void didUpdateWidget(ThermionGestureDetectorMobile oldWidget) {
    if (widget.showControlOverlay != oldWidget.showControlOverlay ||
        widget.enableCamera != oldWidget.enableCamera ||
        widget.enablePicking != oldWidget.enablePicking) {
      setState(() {});
    }

    super.didUpdateWidget(oldWidget);
  }

  // ignore: unused_field
  Timer? _scrollTimer;
  double _lastScale = 0;

  // pinch zoom on mobile
  // couldn't find any equivalent for pointerCount in Listener (?) so we use a GestureDetector
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
          child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (d) {
                if (!widget.enablePicking) {
                  return;
                }

                widget.viewer.pick(
                    d.globalPosition.dx.toInt(), d.globalPosition.dy.toInt());
              },
              onDoubleTap: () {
                setState(() {
                  _rotateOnPointerMove = !_rotateOnPointerMove;
                });
              },
              onScaleStart: (d) async {
                if (widget.onScaleStart != null) {
                  widget.onScaleStart!.call(d);
                  return;
                }
                if (d.pointerCount == 2 && widget.enableCamera) {
                  _scaling = true;
                  await widget.viewer.zoomBegin();
                } else if (!_scaling && widget.enableCamera) {
                  if (_rotateOnPointerMove) {
                    widget.viewer.rotateStart(
                        d.localFocalPoint.dx, d.localFocalPoint.dy);
                  } else {
                    widget.viewer
                        .panStart(d.localFocalPoint.dx, d.localFocalPoint.dy);
                  }
                }
              },
              onScaleUpdate: (ScaleUpdateDetails d) async {
                if (widget.onScaleUpdate != null) {
                  widget.onScaleUpdate!.call(d);
                  return;
                }
                if (d.pointerCount == 2 && widget.enableCamera) {
                  if (d.horizontalScale != _lastScale) {
                    widget.viewer.zoomUpdate(
                        d.localFocalPoint.dx,
                        d.localFocalPoint.dy,
                        d.horizontalScale > _lastScale ? 0.1 : -0.1);
                    _lastScale = d.horizontalScale;
                  }
                } else if (!_scaling && widget.enableCamera) {
                  if (_rotateOnPointerMove) {
                    widget.viewer
                        .rotateUpdate(d.focalPoint.dx, d.focalPoint.dy);
                  } else {
                    widget.viewer
                        .panUpdate(d.focalPoint.dx, d.focalPoint.dy);
                  }
                }
              },
              onScaleEnd: (d) async {
                if (widget.onScaleEnd != null) {
                  widget.onScaleEnd!.call(d);
                  return;
                }

                if (d.pointerCount == 2 && widget.enableCamera) {
                  widget.viewer.zoomEnd();
                } else if (!_scaling && widget.enableCamera) {
                  if (_rotateOnPointerMove) {
                    widget.viewer.rotateEnd();
                  } else {
                    widget.viewer.panEnd();
                  }
                }
                _scaling = false;
              },
              child: widget.child)),
      widget.showControlOverlay
          ? Align(
              alignment: Alignment.bottomRight,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    var curIdx = GestureType.values.indexOf(gestureType);
                    var nextIdx = curIdx == GestureType.values.length - 1
                        ? 0
                        : curIdx + 1;
                    gestureType = GestureType.values[nextIdx];
                    _setFunction();
                  });
                },
                child: Container(
                    padding: const EdgeInsets.all(50),
                    child: Icon(_icons[gestureType], color: Colors.green)),
              ))
          : Container()
    ]);
  }
}

import 'package:flutter/material.dart';
import 'filament_controller.dart';
import 'filament_widget.dart';

class GestureDetectingFilamentView extends StatefulWidget {
  final FilamentController controller;

  final bool showControls;

  const GestureDetectingFilamentView(
      {Key? key, required this.controller, this.showControls = false})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _GestureDetectingFilamentViewState();
}

class _GestureDetectingFilamentViewState
    extends State<GestureDetectingFilamentView> {
  bool _rotate = false;
  late Future Function(double x, double y) _functionStart;
  late Future Function(double x, double y) _functionUpdate;
  late Future Function() _functionEnd;

  double _lastScale = 0;

  @override
  void initState() {
    _setFunction();
    super.initState();
  }

  void _setFunction() {
    if (_rotate) {
      _functionStart = widget.controller.rotateStart;
      _functionUpdate = widget.controller.rotateUpdate;
      _functionEnd = widget.controller.rotateEnd;
    } else {
      _functionStart = widget.controller.panStart;
      _functionUpdate = widget.controller.panUpdate;
      _functionEnd = widget.controller.panEnd;
    }
  }

  @override
  void didUpdateWidget(Widget oldWidget) {
    if (widget.showControls !=
        (oldWidget as GestureDetectingFilamentView).showControls) {
      setState(() {});
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
          child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (d) {
                if (d.pointerCount == 2) {
                  // _lastScale = d.
                } else {
                  // print("start ${d.focalPoint}");
                  _functionStart(d.focalPoint.dx, d.focalPoint.dy);
                }
              },
              onScaleEnd: (d) {
                if (d.pointerCount == 2) {
                  _lastScale = 0;
                } else {
                  // print("end ${d.velocity}");
                  _functionEnd();
                }
              },
              onScaleUpdate: (d) {
                if (d.pointerCount == 2) {
                  if (_lastScale == 0) {
                    _lastScale = d.scale;
                  } else {
                    // var zoomFactor = ;
                    // if(zoomFactor < 0) {
                    //   zoomFactor *= 10;
                    // }
                    // print(zoomFactor);
                    print(d.horizontalScale);
                    // print(d.focalPoint.dx);
                    widget.controller.zoom(d.scale > 1 ? 10 : -10);
                  }
                } else {
                  // print("update ${d.focalPoint}");
                  _functionUpdate(d.focalPoint.dx, d.focalPoint.dy);
                }
              },
              child: FilamentWidget(controller: widget.controller))),
      widget.showControls
          ? Align(
              alignment: Alignment.bottomRight,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _rotate = !_rotate;
                    _setFunction();
                  });
                },
                child: Container(
                    padding: const EdgeInsets.all(50),
                    child: Icon(Icons.rotate_90_degrees_ccw,
                        color: _rotate
                            ? Colors.white
                            : Colors.white.withOpacity(0.5))),
              ))
          : Container()
    ]);
  }
}

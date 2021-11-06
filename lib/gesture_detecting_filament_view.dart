import 'package:flutter/widgets.dart';

import 'filament_controller.dart';
import 'view/filament_widget.dart';

class GestureDetectingFilamentView extends StatefulWidget {
  final FilamentController controller;
  final bool rotate;

  const GestureDetectingFilamentView(
      {Key? key, required this.controller, this.rotate = false})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _GestureDetectingFilamentViewState();
}

class _GestureDetectingFilamentViewState
    extends State<GestureDetectingFilamentView> {
  int _primitiveIndex = 0;
  double _weight = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (details) {
          widget.rotate
              ? widget.controller.rotateStart(
                  details.localPosition.dx, details.localPosition.dy)
              : widget.controller
                  .panStart(details.localPosition.dx, details.localPosition.dy);
        },
        onPanUpdate: (details) {
          widget.rotate
              ? widget.controller.rotateUpdate(
                  details.localPosition.dx, details.localPosition.dy)
              : widget.controller.panUpdate(
                  details.localPosition.dx, details.localPosition.dy);
        },
        onPanEnd: (d) {
          widget.rotate
              ? widget.controller.rotateEnd()
              : widget.controller.panEnd();
        },
        child: FilamentWidget(controller: widget.controller));
  }
}

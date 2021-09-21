import 'package:flutter/widgets.dart';
import 'package:mimetic_filament/filament_controller.dart';
import 'package:mimetic_filament/view/filament_widget.dart';

class GestureDetectingFilamentView extends StatefulWidget {
  final FilamentController controller;

  const GestureDetectingFilamentView({Key? key, required this.controller})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _GestureDetectingFilamentViewState();
}

class _GestureDetectingFilamentViewState
    extends State<GestureDetectingFilamentView> {
  bool _rotate = false;
  int _primitiveIndex = 0;
  double _weight = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (details) {
          _rotate
              ? widget.controller.rotateStart(
                  details.localPosition.dx, details.localPosition.dy)
              : widget.controller
                  .panStart(details.localPosition.dx, details.localPosition.dy);
        },
        onPanUpdate: (details) {
          _rotate
              ? widget.controller.rotateUpdate(
                  details.localPosition.dx, details.localPosition.dy)
              : widget.controller.panUpdate(
                  details.localPosition.dx, details.localPosition.dy);
        },
        onPanEnd: (d) {
          _rotate ? widget.controller.rotateEnd() : widget.controller.panEnd();
        },
        child: FilamentWidget(controller: widget.controller));
  }
}

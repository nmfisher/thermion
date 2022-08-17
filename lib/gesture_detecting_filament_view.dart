import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

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
              onPanDown: (details) async {
                await widget.controller.panEnd();
                await widget.controller.rotateEnd();
                _rotate
                    ? widget.controller.rotateStart(
                        details.globalPosition.dx, details.globalPosition.dy)
                    : widget.controller.panStart(
                        details.globalPosition.dx, details.globalPosition.dy);
              },
              onPanUpdate: (details) {
                _rotate
                    ? widget.controller.rotateUpdate(
                        details.globalPosition.dx, details.globalPosition.dy)
                    : widget.controller.panUpdate(
                        details.globalPosition.dx, details.globalPosition.dy);
              },
              onPanEnd: (d) {
                _rotate
                    ? widget.controller.rotateEnd()
                    : widget.controller.panEnd();
              },
              child: FilamentWidget(controller: widget.controller))),
      widget.showControls
          ? Padding(
              padding: const EdgeInsets.all(50),
              child: Row(children: [
                Checkbox(
                    value: _rotate,
                    onChanged: (v) {
                      setState(() {
                        _rotate = v == true;
                      });
                    }),
                ElevatedButton(
                    onPressed: () => widget.controller.zoom(30.0),
                    child: const Text('-')),
                ElevatedButton(
                    onPressed: () => widget.controller.zoom(-30.0),
                    child: const Text('+'))
              ]))
          : Container()
    ]);
  }
}
// behavior: HitTestBehavior.opaque,
// onPanDown: (details) {
//               _rotate
//                   ? _filamentController.rotateStart(
//                       details.globalPosition.dx, details.globalPosition.dy)
//                   : _filamentController.panStart(
//                       details.globalPosition.dx, details.globalPosition.dy);
//             },
//             onPanUpdate: (details) {
//               _rotate
//                   ? _filamentController.rotateUpdate(
//                       details.globalPosition.dx, details.globalPosition.dy)
//                   : _filamentController.panUpdate(
//                       details.globalPosition.dx, details.globalPosition.dy);
//             },
//             onPanEnd: (d) {
//               _rotate
//                   ? _filamentController.rotateEnd()
//                   : _filamentController.panEnd();
//             },

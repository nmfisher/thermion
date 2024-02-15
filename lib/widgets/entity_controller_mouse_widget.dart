import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_filament/entities/entity_transform_controller.dart';
import 'dart:async';

///
/// A widget that translates mouse gestures to zoom/pan/rotate actions.
///
class EntityTransformMouseControllerWidget extends StatelessWidget {
  final EntityTransformController? transformController;
  final Widget? child;

  EntityTransformMouseControllerWidget(
      {Key? key, required this.transformController, this.child})
      : super(key: key);

  Timer? _timer;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      return Listener(
          onPointerDown: (event) {
            if (kPrimaryMouseButton & event.buttons != 0) {
              transformController?.mouse1Down();
            }
          },
          onPointerUp: (event) {
            if (kPrimaryMouseButton & event.buttons != 0) {
              transformController?.mouse1Up();
            }
          },
          onPointerHover: (event) {
            _timer?.cancel();
            if (event.position.dx < 10) {
              _timer = Timer.periodic(const Duration(milliseconds: 17), (_) {
                transformController?.look(-30);
              });
            } else if (event.position.dx > constraints.maxWidth - 10) {
              _timer = Timer.periodic(const Duration(milliseconds: 17), (_) {
                transformController?.look(30);
              });
            } else {
              transformController?.look(event.delta.dx);
            }
          },
          child: child);
    });
  }
}

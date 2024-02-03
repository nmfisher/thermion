import 'package:flutter/material.dart';
import 'package:flutter_filament/entities/entity_transform_controller.dart';

///
/// A widget that translates mouse gestures to zoom/pan/rotate actions.
///
class EntityTransformMouseControllerWidget extends StatelessWidget {
  final EntityTransformController? transformController;
  final Widget? child;

  const EntityTransformMouseControllerWidget(
      {Key? key, required this.transformController, this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Listener(
        onPointerHover: (event) {
          transformController?.look(event.delta.dx);
        },
        child: child);
  }
}

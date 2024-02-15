import 'package:flutter/widgets.dart';
import 'package:flutter_filament/entities/entity_transform_controller.dart';
import 'package:flutter_filament/filament_controller.dart';
import 'package:flutter_filament/widgets/entity_controller_mouse_widget.dart';
import 'package:flutter_filament/widgets/filament_gesture_detector.dart';
import 'package:flutter_filament/widgets/filament_widget.dart';

class ExampleViewport extends StatelessWidget {
  final FilamentController? controller;
  final EntityTransformController? entityTransformController;
  final EdgeInsets padding;
  final FocusNode keyboardFocusNode;

  const ExampleViewport(
      {super.key,
      required this.controller,
      required this.padding,
      required this.keyboardFocusNode,
      this.entityTransformController});

  @override
  Widget build(BuildContext context) {
    return controller != null
        ? Padding(
            padding: padding,
            child: EntityTransformMouseControllerWidget(
                transformController: entityTransformController,
                child: FilamentGestureDetector(
                    showControlOverlay: true,
                    controller: controller!,
                    child: FilamentWidget(
                      controller: controller!,
                    ))))
        : Container();
  }
}

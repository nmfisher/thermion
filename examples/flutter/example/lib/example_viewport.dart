import 'package:flutter/widgets.dart';
import 'package:thermion_flutter/filament/widgets/camera/entity_controller_mouse_widget.dart';
import 'package:thermion_flutter/filament/widgets/camera/gestures/filament_gesture_detector.dart';
import 'package:thermion_flutter/filament/widgets/filament_widget.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_dart/thermion_dart/entities/entity_transform_controller.dart';


class ExampleViewport extends StatelessWidget {
  final ThermionFlutterPlugin? controller;
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
                    controller: controller!.viewer,
                    child: ThermionWidget(
                      plugin: controller!,
                    ))))
        : Container();
  }
}

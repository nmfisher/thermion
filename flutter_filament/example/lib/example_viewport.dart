import 'package:flutter/widgets.dart';
import 'package:flutter_filament/flutter_filament.dart';

class ExampleViewport extends StatelessWidget {
  final FlutterFilamentPlugin? controller;
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
                      plugin: controller!,
                    ))))
        : Container();
  }
}

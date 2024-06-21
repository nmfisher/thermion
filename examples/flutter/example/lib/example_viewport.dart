import 'package:flutter/widgets.dart';
import 'package:thermion_flutter/thermion/widgets/camera/entity_controller_mouse_widget.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_dart/thermion_dart/entities/entity_transform_controller.dart';


class ExampleViewport extends StatelessWidget {
  final ThermionViewer? viewer;
  final EntityTransformController? entityTransformController;
  final EdgeInsets padding;
  final FocusNode keyboardFocusNode;

  const ExampleViewport(
      {super.key,
      required this.viewer,
      required this.padding,
      required this.keyboardFocusNode,
      this.entityTransformController});

  @override
  Widget build(BuildContext context) {
        return viewer != null
        ? Padding(
            padding: padding,
            child: EntityTransformMouseControllerWidget(
                transformController: entityTransformController,
                child: ThermionGestureDetector(
                    showControlOverlay: true,
                    controller: viewer!,
                    child: ThermionWidget(
                      viewer: viewer!,
                    ))))
        : Container();
  }
}

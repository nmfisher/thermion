import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/filament_controller.dart';

class CameraMenu extends StatefulWidget {
  final FilamentController? controller;

  CameraMenu({super.key, required this.controller});

  @override
  State<StatefulWidget> createState() {
    return _CameraMenuState();
  }
}

class _CameraMenuState extends State<CameraMenu> {
  bool _frustumCulling = true;

  final FocusNode _buttonFocusNode = FocusNode(debugLabel: 'Camera Menu');

  @override
  void didUpdateWidget(CameraMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      childFocusNode: _buttonFocusNode,
      menuChildren: <Widget>[
        MenuItemButton(
          child: Text("Camera"),
          onPressed: () {},
        ),
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
        return Align(
            alignment: Alignment.bottomLeft,
            child: TextButton(
              onPressed: widget.controller?.hasViewer != true
                  ? null
                  : () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
              child: const Text("Camera"),
            ));
      },
    );
  }
}

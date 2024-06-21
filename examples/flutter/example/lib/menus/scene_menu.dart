import 'package:flutter/material.dart';

import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter_example/menus/asset_submenu.dart';
import 'package:thermion_flutter_example/menus/camera_submenu.dart';
import 'package:thermion_flutter_example/menus/rendering_submenu.dart';

class SceneMenu extends StatefulWidget {
  final ThermionViewer? controller;
  final FocusNode sharedFocusNode;

  const SceneMenu(
      {super.key, required this.controller, required this.sharedFocusNode});

  @override
  State<StatefulWidget> createState() {
    return _SceneMenuState();
  }
}

class _SceneMenuState extends State<SceneMenu> {
  @override
  void didUpdateWidget(SceneMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null &&
        (widget.controller != oldWidget.controller)) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      onClose: () {},
      childFocusNode: widget.sharedFocusNode,
      menuChildren: widget.controller == null
          ? []
          : <Widget>[
              RenderingSubmenu(
                viewer: widget.controller!,
              ),
              AssetSubmenu(viewer: widget.controller!),
              CameraSubmenu(
                viewer: widget.controller!,
              ),
            ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) {
        return TextButton(
          onPressed: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: const Text("Scene"),
        );
      },
    );
  }
}

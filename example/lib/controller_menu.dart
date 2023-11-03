import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/filament_controller.dart';
import 'package:flutter_filament/filament_controller_ffi.dart';

class ControllerMenu extends StatefulWidget {
  final void Function(FilamentController controller) onControllerCreated;
  final void Function() onControllerDestroyed;

  ControllerMenu(
      {required this.onControllerCreated, required this.onControllerDestroyed});

  @override
  State<StatefulWidget> createState() => _ControllerMenuState();
}

class _ControllerMenuState extends State<ControllerMenu> {
  FilamentController? _filamentController;
  final FocusNode _buttonFocusNode = FocusNode(debugLabel: 'Camera Menu');

  void _createController({String? uberArchivePath}) {
    _filamentController =
        FilamentControllerFFI(uberArchivePath: uberArchivePath);
    widget.onControllerCreated(_filamentController!);
  }

  @override
  Widget build(BuildContext context) {
    var items = <Widget>[];
    if (_filamentController?.hasViewer != true) {
      items.addAll([
        MenuItemButton(
          child: const Text("create viewer"),
          onPressed: _filamentController == null
              ? null
              : () {
                  _filamentController!.createViewer();
                },
        ),
        MenuItemButton(
          child: const Text("create FilamentController (default ubershader)"),
          onPressed: () {
            _createController();
          },
        ),
        MenuItemButton(
          child: const Text(
              "create FilamentController (custom ubershader - lit opaque only)"),
          onPressed: () {
            _createController(
                uberArchivePath: Platform.isWindows
                    ? "assets/lit_opaque_32.uberz"
                    : Platform.isMacOS
                        ? "assets/lit_opaque_43.uberz"
                        : Platform.isIOS
                            ? "assets/lit_opaque_43.uberz"
                            : "assets/lit_opaque_43_gles.uberz");
          },
        )
      ]);
    } else {
      items.addAll([
        MenuItemButton(
          child: const Text("destroy viewer"),
          onPressed: () {
            _filamentController!.destroy();
            _filamentController = null;
            widget.onControllerDestroyed();
            setState(() {});
          },
        )
      ]);
    }
    return MenuAnchor(
        childFocusNode: _buttonFocusNode,
        menuChildren: items,
        builder:
            (BuildContext context, MenuController controller, Widget? child) {
          return Align(
              alignment: Alignment.bottomLeft,
              child: TextButton(
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                child: const Text("Controller / Viewer"),
              ));
        });
  }
}

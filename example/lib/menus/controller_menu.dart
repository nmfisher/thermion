import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/filament_controller.dart';
import 'package:flutter_filament/filament_controller_ffi.dart';

class ControllerMenu extends StatefulWidget {
  final FilamentController? controller;
  final void Function(FilamentController controller) onControllerCreated;
  final void Function() onControllerDestroyed;

  ControllerMenu(
      {this.controller,
      required this.onControllerCreated,
      required this.onControllerDestroyed});

  @override
  State<StatefulWidget> createState() => _ControllerMenuState();
}

class _ControllerMenuState extends State<ControllerMenu> {
  FilamentController? _filamentController;
  final FocusNode _buttonFocusNode = FocusNode(debugLabel: 'Camera Menu');

  void _createController({String? uberArchivePath}) {
    if (_filamentController != null) {
      throw Exception("Controller already exists");
    }
    _filamentController =
        FilamentControllerFFI(uberArchivePath: uberArchivePath);
    widget.onControllerCreated(_filamentController!);
  }

  @override
  void initState() {
    super.initState();
    _filamentController = widget.controller;
  }

  @override
  void didUpdateWidget(ControllerMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != _filamentController) {
      setState(() {
        _filamentController = widget.controller;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var items = <Widget>[];
    if (_filamentController?.hasViewer.value != true) {
      items.addAll([
        MenuItemButton(
          child: const Text("Create FilamentViewer"),
          onPressed: _filamentController == null
              ? null
              : () {
                  _filamentController!.createViewer();
                },
        ),
        MenuItemButton(
          child: const Text("Create FilamentController (default ubershader)"),
          onPressed: () {
            _createController();
          },
        ),
        MenuItemButton(
          child: const Text(
              "Create FilamentController (custom ubershader - lit opaque only)"),
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
          child: const Text("Destroy viewer"),
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
          return TextButton(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: const Text("Controller / Viewer"),
          );
        });
  }
}

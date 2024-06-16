import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:thermion_flutter/thermion_flutter.dart';

class ControllerMenu extends StatefulWidget {
  final ThermionFlutterPlugin controller;
  final void Function() onToggleViewport;
  final void Function() onControllerCreated;
  final void Function() onControllerDestroyed;
  final FocusNode sharedFocusNode;
         

  ControllerMenu(
      {required this.controller,
      required this.onControllerCreated,
      required this.onControllerDestroyed,
      required this.sharedFocusNode,
      required this.onToggleViewport});

  @override
  State<StatefulWidget> createState() => _ControllerMenuState();
}

class _ControllerMenuState extends State<ControllerMenu> {
  void _createController({String? uberArchivePath}) async {
    widget.controller.initialize(uberArchivePath: uberArchivePath);
    widget.onControllerCreated();
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(ControllerMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  bool _initialized = false;
  @override
  Widget build(BuildContext context) {
    var items = <Widget>[];
    if (!_initialized) {
      items.addAll([
        MenuItemButton(
          child:
              const Text("Create ThermionFlutterPlugin (default ubershader)"),
          onPressed: () {
            _createController();
          },
        ),
        MenuItemButton(
          child: const Text(
              "Create ThermionFlutterPlugin (custom ubershader - lit opaque only)"),
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
          onPressed: () async {
            widget.controller.dispose();
            widget.onControllerDestroyed();
            setState(() {});
          },
        )
      ]);
    }
    return MenuAnchor(
        childFocusNode: widget.sharedFocusNode,
        menuChildren: items +
            [
              TextButton(
                child: const Text("Toggle viewport size"),
                onPressed: widget.onToggleViewport,
              )
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
            child: const Text("Controller / Viewer"),
          );
        });
  }
}

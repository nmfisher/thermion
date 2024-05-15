import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_filament/flutter_filament.dart';

class ControllerMenu extends StatefulWidget {
  final FlutterFilamentPlugin? controller;
  final void Function() onToggleViewport;
  final void Function(FlutterFilamentPlugin controller) onControllerCreated;
  final void Function() onControllerDestroyed;
  final FocusNode sharedFocusNode;

  ControllerMenu(
      {this.controller,
      required this.onControllerCreated,
      required this.onControllerDestroyed,
      required this.sharedFocusNode,
      required this.onToggleViewport});

  @override
  State<StatefulWidget> createState() => _ControllerMenuState();
}

class _ControllerMenuState extends State<ControllerMenu> {
  FlutterFilamentPlugin? _flutterFilamentPlugin;

  void _createController({String? uberArchivePath}) async {
    if (_flutterFilamentPlugin != null) {
      throw Exception("Controller already exists");
    }
    _flutterFilamentPlugin =
        await FlutterFilamentPlugin.create(uberArchivePath: uberArchivePath);
    widget.onControllerCreated(_flutterFilamentPlugin!);
  }

  @override
  void initState() {
    super.initState();
    _flutterFilamentPlugin = widget.controller;
  }

  @override
  void didUpdateWidget(ControllerMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != _flutterFilamentPlugin) {
      setState(() {
        _flutterFilamentPlugin = widget.controller;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var items = <Widget>[];
    if (_flutterFilamentPlugin == null) {
      items.addAll([
        MenuItemButton(
          child:
              const Text("Create FlutterFilamentPlugin (default ubershader)"),
          onPressed: () {
            _createController();
          },
        ),
        MenuItemButton(
          child: const Text(
              "Create FlutterFilamentPlugin (custom ubershader - lit opaque only)"),
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
            await _flutterFilamentPlugin!.dispose();
            _flutterFilamentPlugin = null;
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

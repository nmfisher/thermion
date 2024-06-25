import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:thermion_flutter/thermion_flutter.dart';

class ViewerMenu extends StatefulWidget {
  final ThermionViewer? viewer;
  final void Function() onToggleViewport;
  final void Function(ThermionViewer viewer) onViewerCreated;
  final void Function() onViewerDestroyed;
  final FocusNode sharedFocusNode;

  ViewerMenu(
      {
        required this.viewer,
        required this.onViewerCreated,
      required this.onViewerDestroyed,
      required this.sharedFocusNode,
      required this.onToggleViewport});

  @override
  State<StatefulWidget> createState() => _ViewerMenuState();
}

class _ViewerMenuState extends State<ViewerMenu> {
  void _createViewer({String? uberArchivePath}) async {
    var viewer = await ThermionFlutterPlugin.createViewer(
        uberArchivePath: uberArchivePath);
    await viewer.initialized;
    widget.onViewerCreated(viewer);
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(ViewerMenu oldWidget) {
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
            _createViewer();
          },
        ),
        MenuItemButton(
          child: const Text(
              "Create ThermionFlutterPlugin (custom ubershader - lit opaque only)"),
          onPressed: () {
            _createViewer(
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
            widget.viewer!.dispose();
            widget.onViewerDestroyed();
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
        builder: (BuildContext context, MenuController controller, Widget? child) {
          return TextButton(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            child: const Text("Viewer / Viewer"),
          );
        });
  }
}

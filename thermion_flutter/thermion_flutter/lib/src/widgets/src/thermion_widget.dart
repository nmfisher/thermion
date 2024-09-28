import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/src/widgets/src/thermion_texture_widget.dart';
import 'package:thermion_flutter/src/widgets/src/thermion_widget_web.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter_web/thermion_flutter_web_options.dart';
import 'package:thermion_dart/src/viewer/src/shared_types/view.dart' as t;
import 'thermion_widget_windows.dart';

class ThermionWidget extends StatefulWidget {
  ///
  /// The viewer.
  ///
  final ThermionViewer viewer;

  ///
  /// The view.
  ///
  final t.View? view;

  ///
  /// The options to use when creating this widget.
  ///
  final ThermionFlutterOptions? options;

  ///
  /// The content to render before the texture widget is available.
  /// The default is a solid red Container, intentionally chosen to make it clear that there will be at least one frame where the Texture widget is not being rendered.
  ///
  final Widget? initial;

  const ThermionWidget(
      {Key? key, this.initial, required this.viewer, this.view, this.options})
      : super(key: key);

  State<ThermionWidget> createState() => _ThermionWidgetState();
}

class _ThermionWidgetState extends State<ThermionWidget> {
  t.View? view;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future initialize() async {
    if (widget.view != null) {
      view = widget.view;
    } else {
      view = await widget.viewer.getViewAt(0);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (view == null) {
      return widget.initial ?? Container(color: Colors.red);
    }

    // Windows & Web don't support imported textures yet
    if (kIsWeb) {
      return ThermionWidgetWeb(
          viewer: widget.viewer,
          options: widget.options as ThermionFlutterWebOptions);
    }

    if (Platform.isWindows) {
      return ThermionWidgetWindows(viewer: widget.viewer);
    }

    return ThermionTextureWidget(
        key: ObjectKey(view!),
        initial: widget.initial,
        viewer: widget.viewer,
        view: view!);
  }
}

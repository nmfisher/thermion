import 'package:flutter/material.dart' hide View;
import 'thermion_widget_internal/thermion_widget_internal.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

class ThermionWidget extends StatefulWidget {

  // The viewer whose content will be rendered into this widget.
  final ThermionViewer viewer;

  /// If true, enable the highlight overlay system.
  /// This creates a separate texture for rendering entity highlights/outlines
  /// that is composited on top of the main render texture.
  final bool enableOverlay;

  const ThermionWidget(
      {Key? key,
      required this.viewer,
      this.enableOverlay = false})
      : super(key: key);

  @override
  State<ThermionWidget> createState() => _ThermionWidgetState();
}

class _ThermionWidgetState extends State<ThermionWidget> {

  void initState() {
    super.initState();  
  }
  
  @override
  Widget build(BuildContext context) {
    return ThermionWidgetInternal(
        view: widget.viewer.view);
  }
}

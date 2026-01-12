import 'package:flutter/material.dart' hide View;
import 'package:thermion_flutter/thermion_flutter.dart';

class ThermionWidgetInternal extends StatelessWidget {
  ///
  final ThermionViewer viewer;

  ///
  final Widget? initial;

  /// A callback that will be invoked whenever this widget (and the underlying texture is resized).
  final Future Function(Size size, View view, double pixelRatio)? onResize;

  /// When true, an FPS counter will be displayed at the top right of the widget
  final bool showFpsCounter;

  /// When true, enable the highlight overlay system with a separate composited texture
  final bool enableOverlay;

  const ThermionWidgetInternal({
    super.key,
    required this.viewer,
    this.initial,
    this.onResize,
    this.showFpsCounter = false,
    this.enableOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }
}

import 'package:flutter/material.dart' hide View;
import 'package:thermion_dart/thermion_dart.dart' show View;
import 'package:thermion_flutter/thermion_flutter.dart';

import '../../../platform/src/platform_texture_descriptor.dart';

/// Web surface builder. With `importCanvasAsWidget` (the default) each
/// viewer's engine renders into its own DOM canvas, which is hosted inside
/// this widget via an `HtmlElementView` — the widget slot positions the
/// canvas element, and the engine paints it directly. With the legacy flag
/// off, the canvas floats behind the app and the widget is a transparent
/// placeholder.
Widget surfaceWidgetBuilder(PlatformTextureDescriptor? descriptor, View view) {
  final plugin = ThermionFlutterPlugin.instance;
  if (!plugin.options.webOptions.importCanvasAsWidget) {
    return Container(color: Colors.transparent);
  }
  final canvasId = plugin.canvasIdForView(view);
  if (canvasId == null) {
    // Viewer not registered yet (still initializing) — keep the slot warm.
    return Container(color: Colors.transparent);
  }
  return HtmlElementView(viewType: 'imported-canvas-$canvasId');
}

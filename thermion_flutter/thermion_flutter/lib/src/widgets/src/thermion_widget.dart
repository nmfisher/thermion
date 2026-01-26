import 'package:flutter/material.dart' hide View;
import 'thermion_widget_internal/thermion_widget_internal.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

class ThermionWidget extends StatefulWidget {
  // The viewer whose content will be rendered into this widget.
  final ThermionViewer viewer;

  /// If true, enable the highlight overlay system.
  /// The edge detection shader samples both the main scene and silhouette
  /// textures, compositing them into a single output texture.
  final bool enableHighlights;

  const ThermionWidget({
    Key? key,
    required this.viewer,
    this.enableHighlights = false,
  }) : super(key: key);

  @override
  State<ThermionWidget> createState() => _ThermionWidgetState();
}

class _ThermionWidgetState extends State<ThermionWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.enableHighlights) {
      return ThermionWidgetInternal(
        key: Key("highlight_texture_view"),
        onTextureUpdated: (descriptor) async {
          if (descriptor == null) {
            return;
          }
          final view = widget.viewer.view;
          var camera = await view.getCamera();
          var near = await camera.getNear();
          var far = await camera.getCullingFar();
          var focalLength = await camera.getFocalLength();

          await camera.setLensProjection(
              near: near,
              far: far,
              focalLength: focalLength,
              aspect: descriptor.width.toDouble() /
                  descriptor.height.toDouble());

          await view.setViewport(descriptor.width, descriptor.height);

          // Enable highlight overlay
          await view.enableHighlightOverlay();
        },
        view: widget.viewer.view,
      );
    }

    // No highlights
    return ThermionWidgetInternal(view: widget.viewer.view);
  }
}

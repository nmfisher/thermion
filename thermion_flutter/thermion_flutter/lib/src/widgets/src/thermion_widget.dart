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
      {Key? key, required this.viewer, this.enableOverlay = false})
      : super(key: key);

  @override
  State<ThermionWidget> createState() => _ThermionWidgetState();
}

class _ThermionWidgetState extends State<ThermionWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.enableOverlay) {
      final overlayView = widget.viewer.view.getOverlayView();

      return Stack(children: [
        Positioned.fill(
            child: ThermionWidgetInternal(
                key: Key("main_texture_view"),
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
                },
                view: widget.viewer.view)),
        Positioned.fill(
            child: ThermionWidgetInternal(
                key: Key("overlay_texture_view"),
                view: overlayView!,
                onTextureUpdated: (descriptor) async {
                  if (descriptor == null) {
                    return;
                  }
                }))
      ]);
    }
    return ThermionWidgetInternal(view: widget.viewer.view);
  }
}

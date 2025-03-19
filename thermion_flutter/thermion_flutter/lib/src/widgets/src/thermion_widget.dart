import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide View;
import 'package:thermion_flutter/src/widgets/src/thermion_texture_widget.dart';
import 'package:thermion_flutter/src/widgets/src/thermion_widget_web.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter_web/thermion_flutter_web_options.dart';

Future kDefaultResizeCallback(Size size, View view, double pixelRatio) async {
  var camera = await view.getCamera();
  var near = await camera.getNear();
  var far = await camera.getCullingFar();
  var focalLength = await camera.getFocalLength();

  await camera.setLensProjection(
      near: near,
      far: far,
      focalLength: focalLength,
      aspect: size.width.toDouble() / size.height.toDouble());
}

class ThermionWidget extends StatefulWidget {
  ///
  /// The viewer.
  ///
  final ThermionViewer viewer;

  ///
  /// A callback to invoke whenever this widget and the underlying surface are
  /// resized. If a callback is not explicitly provided, the default callback
  /// will be run, which changes the aspect ratio for the active camera in
  /// the View managed by this widget. If you specify your own callback,
  /// you probably want to preserve this behaviour (otherwise the aspect ratio)
  /// will be incorrect.
  ///
  /// To completely disable the resize callback, pass [null].
  ///
  /// IMPORTANT - size is specified in physical pixels, not logical pixels.
  /// If you need to work with Flutter dimensions, divide [size] by
  /// [pixelRatio].
  ///
  final Future Function(Size size, View view, double pixelRatio)? onResize;

  final bool showFpsCounter;

  ///
  /// The content to render before the texture widget is available.
  /// The default is a solid red Container, intentionally chosen to make it clear that there will be at least one frame where the Texture widget is not being rendered.
  ///
  final Widget? initial;

  const ThermionWidget(
      {Key? key,
      this.initial,
      required this.viewer,
      this.showFpsCounter = false,
      this.onResize = kDefaultResizeCallback})
      : super(key: key);

  @override
  State<ThermionWidget> createState() => _ThermionWidgetState();
}

class _ThermionWidgetState extends State<ThermionWidget> {
  @override
  Widget build(BuildContext context) {
    // Web doesn't support imported textures yet
    if (kIsWeb) {
      throw Exception();
      // return ThermionWidgetWeb(
      //     viewer: widget.viewer,
      //     options: ThermionFlutterPlugin.options as ThermionFlutterWebOptions?);
    }

    return ThermionTextureWidget(
        key: ObjectKey(widget.viewer),
        initial: widget.initial,
        viewer: widget.viewer,
        showFpsCounter: widget.showFpsCounter,
        onResize: widget.onResize);
  }
}

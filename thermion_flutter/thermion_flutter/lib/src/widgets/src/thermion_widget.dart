import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/src/widgets/src/thermion_texture_widget.dart';
import 'package:thermion_flutter/src/widgets/src/thermion_widget_web.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter_web/thermion_flutter_web_options.dart';
import 'package:thermion_dart/src/viewer/src/shared_types/view.dart' as t;

Future kDefaultResizeCallback(Size size, t.View view, double pixelRatio) async {
  var camera = await view.getCamera();
  var near = await camera.getNear();
  var far = await camera.getCullingFar();
  var focalLength = await camera.getFocalLength();

  await camera.setLensProjection(near:near, far:far, focalLength: focalLength,
      aspect: size.width.toDouble() / size.height.toDouble());
}

class ThermionWidget extends StatefulWidget {
  ///
  /// The viewer.
  ///
  final ThermionViewer viewer;

  ///
  /// The [t.View] associated with this widget. If null, the default View will be used.
  ///
  final t.View? view;

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
  final Future Function(Size size, t.View view, double pixelRatio)? onResize;

  ///
  /// The content to render before the texture widget is available.
  /// The default is a solid red Container, intentionally chosen to make it clear that there will be at least one frame where the Texture widget is not being rendered.
  ///
  final Widget? initial;

  const ThermionWidget(
      {Key? key,
      this.initial,
      required this.viewer,
      this.view,
      this.onResize = kDefaultResizeCallback})
      : super(key: key);

  @override
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

    // Web doesn't support imported textures yet
    if (kIsWeb) {
      return ThermionWidgetWeb(
          viewer: widget.viewer,
          options: ThermionFlutterPlugin.options as ThermionFlutterWebOptions?);
    }

    return ThermionTextureWidget(
        key: ObjectKey(view!),
        initial: widget.initial,
        viewer: widget.viewer,
        view: view!,
        onResize: widget.onResize);
  }
}

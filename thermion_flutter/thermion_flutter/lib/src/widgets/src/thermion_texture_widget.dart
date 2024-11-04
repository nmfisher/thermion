import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:thermion_dart/src/viewer/src/shared_types/view.dart' as t;
import 'package:thermion_flutter/src/widgets/src/resize_observer.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';

class ThermionTextureWidget extends StatefulWidget {
  ///
  ///
  ///
  final ThermionViewer viewer;

  ///
  ///
  ///
  final t.View view;

  ///
  ///
  ///
  final Widget? initial;

  ///
  /// A callback that will be invoked whenever this widget (and the underlying texture is resized).
  ///
  final Future Function(Size size, t.View view, double pixelRatio)? onResize;

  const ThermionTextureWidget(
      {super.key,
      required this.viewer,
      required this.view,
      this.initial,
      this.onResize});

  @override
  State<StatefulWidget> createState() {
    return _ThermionTextureWidgetState();
  }
}

class _ThermionTextureWidgetState extends State<ThermionTextureWidget> {
  ThermionFlutterTexture? _texture;

  static final _views = <t.View>[];

  final _logger = Logger("_ThermionTextureWidgetState");

  @override
  void dispose() {
    super.dispose();
    _views.remove(widget.view);
    if(_texture != null) {
      ThermionFlutterPlatform.instance.destroyTexture(_texture!);
    }

    _states.remove(this);
  }

  @override
  void initState() {
    if (_views.contains(widget.view)) {
      throw Exception("View already embedded in a widget");
    }
    _views.add(widget.view);
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await widget.viewer.initialized;

      var dpr = MediaQuery.of(context).devicePixelRatio;

      var size = ((context.findRenderObject()) as RenderBox).size;

      _logger.info(
          "Widget size in logical pixels ${size} (pixel ratio : $dpr)");
      
      var width = (size.width * dpr).ceil();
      var height = (size.height * dpr).ceil();

      _logger.info(
          "Target texture dimensions ${width}x${height} (pixel ratio : $dpr)");

      _texture = await ThermionFlutterPlatform.instance
          .createTexture(width, height);

      await ThermionFlutterPlatform.instance
          .bind(widget.view, _texture!);

      _logger.info(
          "Actual texture dimensions ${_texture!.width}x${_texture!.height} (pixel ratio : $dpr)");

      await widget.view.updateViewport(_texture!.width, _texture!.height);

      try {
        await widget.onResize?.call(
            Size(_texture!.width.toDouble(), _texture!.height.toDouble()),
            widget.view,
            dpr);
      } catch (err, st) {
        _logger.severe(err);
        _logger.severe(st);
      }

      if (mounted) {
        setState(() {});
      }

      _states.add(this);

      _requestFrame();

      widget.viewer.onDispose(() async {
        var texture = _texture;
        if (mounted) {
          setState(() {});
        }
        if(texture != null) {
          ThermionFlutterPlatform.instance.destroyTexture(texture);
        }

        _views.clear();
      });
    });
    super.initState();
  }

  bool _rendering = false;

  static final _states = <_ThermionTextureWidgetState>{};

  int lastRender = 0;

  ///
  /// Each instance of ThermionTextureWidget in the widget hierarchy must
  /// call [markFrameAvailable] on every frame to notify Flutter that the content
  /// of its backing texture has changed.
  ///
  /// Calling [requestFrame] on [ThermionViewer], however, will render all
  /// views/swapchains that have been marked as renderable (see [setRenderable]).
  ///
  /// Only need one instance of [ThermionTextureWidget] needs to call
  /// [requestFrame]. We manage this by storing all instances of
  /// [_ThermionTextureWidgetState] in a static set, and allowing the first
  /// instance to call [requestFrame].
  ///
  void _requestFrame() {
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.scheduleFrameCallback((d) async {
      if (!mounted) {
        return;
      }
      if (widget.viewer.rendering && !_rendering) {
        _rendering = true;
        if (this == _states.first && _texture != null) {
          await widget.viewer.requestFrame();
          lastRender = d.inMilliseconds;
        }
        if(_texture != null) {
          await ThermionFlutterPlatform.instance.markTextureFrameAvailable(_texture!);
        }
        _rendering = false;
      }
      _requestFrame();
    });
  }

  final _resizing = <Future>[];

  Timer? _resizeTimer;

  Future _resize(Size oldSize, Size newSize) async {
    await Future.wait(_resizing);

    _resizeTimer?.cancel();

    _resizeTimer = Timer(const Duration(milliseconds: 100), () async {
      await Future.wait(_resizing);
      if (!mounted) {
        return;
      }

      if (newSize.width == _texture?.width &&
          newSize.height == _texture?.height) {
        return;
      }

      final completer = Completer();

      _resizing.add(completer.future);

      final dpr = MediaQuery.of(context).devicePixelRatio;

      newSize *= dpr;

      var newWidth = newSize.width.ceil();
      var newHeight = newSize.height.ceil();

      _logger.info(
          "Resizing texture to dimensions ${newWidth}x${newHeight} (pixel ratio : $dpr)");

      await ThermionFlutterPlatform.instance.resizeTexture(_texture!, newWidth, newHeight);

      _logger.info(
          "Resized texture to dimensions ${_texture!.width}x${_texture!.height} (pixel ratio : $dpr)");

      await widget.view.updateViewport(_texture!.width, _texture!.height);

      await widget.onResize?.call(
          Size(_texture!.width.toDouble(), _texture!.height.toDouble()),
          widget.view,
          dpr);

      if (!mounted) {
        return;
      }
      setState(() {});
      completer.complete();
      _resizing.remove(completer.future);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_texture == null) {
      return widget.initial ?? Container(color: Colors.red);
    }

    return ResizeObserver(
        onResized: _resize,
        child: Stack(children: [
          Positioned.fill(
              child: Texture(
            key: ObjectKey("flutter_texture_${_texture!.flutterId}"),
            textureId: _texture!.flutterId,
            filterQuality: FilterQuality.none,
            freeze: false,
          ))
        ]));
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:thermion_dart/src/viewer/src/shared_types/view.dart' as t;
import 'package:thermion_flutter/src/widgets/src/resize_observer.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

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
  RenderTarget? _renderTarget;

  static final _views = <t.View>[];

  @override
  void dispose() {
    super.dispose();
    _views.remove(widget.view);
    _texture?.destroy();
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
      var width = (size.width * dpr).ceil();
      var height = (size.height * dpr).ceil();

      _texture = await ThermionFlutterPlatform.instance
          .createTexture(widget.view, width, height);

      await widget.view.updateViewport(_texture!.width, _texture!.height);

      try {
        await widget.onResize?.call(
            Size(_texture!.width.toDouble(), _texture!.height.toDouble()),
            widget.view,
            dpr);
      } catch (err, st) {
        print(err);
        print(st);
      }

      if (mounted) {
        setState(() {});
      }

      _requestFrame();

      widget.viewer.onDispose(() async {
        var texture = _texture;
        if (mounted) {
          setState(() {});
        }
        await texture?.destroy();
        _views.clear();
      });
    });
    _callbackId = _numCallbacks;
    _numCallbacks++;
    super.initState();
  }

  bool _rendering = false;

  static int _numCallbacks = 0;
  static int _primaryCallback = 0;
  late int _callbackId;
  int lastRender = 0;

  void _requestFrame() {
    WidgetsBinding.instance.scheduleFrameCallback((d) async {
      if (widget.viewer.rendering && !_rendering) {
        _rendering = true;
        if (_callbackId == _primaryCallback && _texture != null) {
          await widget.viewer.requestFrame();
          lastRender = d.inMilliseconds;
        }
        await _texture?.markFrameAvailable();
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

      await _texture?.resize(
        newWidth,
        newHeight,
        0,
        0,
      );

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

import 'dart:async';
import 'package:flutter/material.dart' hide View;
import 'package:logging/logging.dart';
import 'package:thermion_flutter/src/widgets/src/resize_observer.dart';
import 'package:thermion_flutter/thermion_flutter.dart' hide Texture;

class ThermionTextureWidget extends StatefulWidget {
  
  ///
  ///
  ///
  final ThermionViewer viewer;

  ///
  ///
  ///
  final Widget? initial;

  ///
  /// A callback that will be invoked whenever this widget (and the underlying texture is resized).
  ///
  final Future Function(Size size, View view, double pixelRatio)? onResize;

  ///
  /// When true, an FPS counter will be displayed at the top right of the widget
  ///
  final bool showFpsCounter;

  const ThermionTextureWidget({
    super.key,
    required this.viewer,
    this.initial,
    this.onResize,
    this.showFpsCounter = false,
  });

  @override
  State<StatefulWidget> createState() {
    return _ThermionTextureWidgetState();
  }
}

class _ThermionTextureWidgetState extends State<ThermionTextureWidget> {
  PlatformTextureDescriptor? _texture;

  static final _views = <View>[];

  final _logger = Logger("_ThermionTextureWidgetState");

  int _fps = 0;
  int _frameCount = 0;
  int _frameRequestCount = 0;
  int _frameRequestPercentage = 0;
  int _lastFpsUpdateTime = 0;
  Timer? _fpsUpdateTimer;

  @override
  void dispose() {
    super.dispose();
    _views.remove(widget.viewer.view);
    if (_texture != null) {
      ThermionFlutterPlatform.instance.destroyTextureDescriptor(_texture!);
    }
    _fpsUpdateTimer?.cancel();
    _states.remove(this);
  }

  @override
  void initState() {
    if (_views.contains(widget.viewer.view)) {
      throw Exception("View already embedded in a widget");
    }
    _views.add(widget.viewer.view);

    // Start FPS counter update timer if enabled
    if (widget.showFpsCounter) {
      _fpsUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _fps = _frameCount;
            _frameRequestPercentage = _frameCount > 0
                ? (_frameCount / _frameRequestCount * 100).round()
                : 0;
            _frameCount = 0;
            _frameRequestCount = 0;
          });
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {

      var dpr = MediaQuery.of(context).devicePixelRatio;

      var size = ((context.findRenderObject()) as RenderBox).size;

      _logger
          .info("Widget size in logical pixels ${size} (pixel ratio : $dpr)");

      var width = (size.width * dpr).ceil();
      var height = (size.height * dpr).ceil();

      _logger.info(
          "Target texture dimensions ${width}x${height} (pixel ratio : $dpr)");

      _texture = await ThermionFlutterPlatform.instance
          .createTextureAndBindToView(widget.viewer.view, width, height);

      _logger.info(
          "Actual texture dimensions ${_texture!.width}x${_texture!.height} (pixel ratio : $dpr)");

      await widget.viewer.view.setViewport(_texture!.width, _texture!.height);

      try {
        await widget.onResize?.call(
            Size(_texture!.width.toDouble(), _texture!.height.toDouble()),
            widget.viewer.view,
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
        if (texture != null) {
          ThermionFlutterPlatform.instance.destroyTextureDescriptor(texture);
        }

        _views.clear();
      });
    });
    super.initState();
  }

  bool _rendering = false;

  static final _states = <_ThermionTextureWidgetState>{};

  int lastRender = 0;
  int _headroomInMs = 5;

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

    if (widget.showFpsCounter) {
      _frameRequestCount++;
    }

    WidgetsBinding.instance.scheduleFrameCallback((d) async {

      if (!mounted) {
        return;
      }
      if (widget.viewer.rendering &&
          !_rendering &&
          _resizing.isEmpty &&
          (d.inMilliseconds - lastRender >
              widget.viewer.msPerFrame - _headroomInMs)) {
        _rendering = true;
        if (this == _states.first && _texture != null) {
          await FilamentApp.instance!.requestFrame();
          lastRender = d.inMilliseconds;

          if (widget.showFpsCounter) {
            _frameCount++;
          }
        }
        if (_texture != null) {
          await ThermionFlutterPlatform.instance
              .markTextureFrameAvailable(_texture!);
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

      _texture = await ThermionFlutterPlatform.instance
          .resizeTexture(_texture!, widget.viewer.view, newWidth, newHeight);

      _logger.info(
          "Resized texture to dimensions ${_texture!.width}x${_texture!.height} (pixel ratio : $dpr)");

      await widget.viewer.setViewport(_texture!.width, _texture!.height);

      await widget.onResize?.call(
          Size(_texture!.width.toDouble(), _texture!.height.toDouble()),
          widget.viewer.view,
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
      child: Stack(
        children: [
          Positioned.fill(
              child: Texture(
            key: ObjectKey("flutter_texture_${_texture!.flutterTextureId}"),
            textureId: _texture!.flutterTextureId,
            filterQuality: FilterQuality.none,
            freeze: false,
          )),
          if (widget.showFpsCounter)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_fps FPS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Render: $_frameRequestPercentage%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:polyvox_filament/filament_controller.dart';

import 'dart:async';

typedef ResizeCallback = void Function(Size newSize);

class ResizeObserver extends SingleChildRenderObjectWidget {
  final ResizeCallback onResized;

  const ResizeObserver({
    Key? key,
    required this.onResized,
    Widget? child,
  }) : super(
          key: key,
          child: child,
        );

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderResizeObserver(onLayoutChangedCallback: onResized);
}

class _RenderResizeObserver extends RenderProxyBox {
  final ResizeCallback onLayoutChangedCallback;

  _RenderResizeObserver({
    RenderBox? child,
    required this.onLayoutChangedCallback,
  }) : super(child);

  Size _oldSize = Size.zero;

  @override
  void performLayout() async {
    super.performLayout();
    if (size.width != _oldSize.width || size.height != _oldSize.height) {
      onLayoutChangedCallback(size);
      _oldSize = Size(size.width, size.height);
    }
  }
}

class FilamentWidget extends StatefulWidget {
  final FilamentController controller;

  ///
  /// The content to render before the texture widget is available.
  /// The default is a solid red Container, intentionally chosen to make it clear that there will be at least one frame where the Texture widget is not being rendered.
  ///
  final Widget? initial;

  const FilamentWidget({Key? key, required this.controller, this.initial})
      : super(key: key);

  @override
  _FilamentWidgetState createState() => _FilamentWidgetState();
}

class _FilamentWidgetState extends State<FilamentWidget> {
  int? _width;
  int? _height;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      // when attaching a debugger via Android Studio on startup, this can delay presentation of the widget
      // (meaning the widget may attempt to create a viewer with size 0x0).
      // we just add a small delay here which should avoid this
      if (!kReleaseMode) {
        await Future.delayed(Duration(seconds: 2));
      }
      var size = ((context.findRenderObject()) as RenderBox).size;
      _width = size.width.ceil();
      _height = size.height.ceil();
      setState(() {});
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_width == null || _height == null) {
      return widget.initial ?? Container(color: Colors.red);
    }

    return ResizeObserver(
        onResized: (newSize) {
          WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
            setState(() {
              _width = newSize.width.ceil();
              _height = newSize.height.ceil();
            });
          });
        },
        child: _SizedFilamentWidget(
          initial: widget.initial,
          width: _width!,
          height: _height!,
          controller: widget.controller,
        ));
  }
}

class _SizedFilamentWidget extends StatefulWidget {
  final int width;
  final int height;
  final Widget? initial;
  final FilamentController controller;

  const _SizedFilamentWidget(
      {super.key,
      required this.width,
      required this.height,
      this.initial,
      required this.controller});

  @override
  State<StatefulWidget> createState() => _SizedFilamentWidgetState();
}

class _SizedFilamentWidgetState extends State<_SizedFilamentWidget> {
  String? _error;

  late final AppLifecycleListener _appLifecycleListener;
  AppLifecycleState? _lastState;

  @override
  void initState() {
    _appLifecycleListener = AppLifecycleListener(
      onStateChange: _handleStateChange,
    );

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      // when attaching a debugger via Android Studio on startup, this can delay presentation of the widget
      // (meaning the widget may attempt to create a viewer with size 0x0).
      // we just add a small delay here which should avoid this
      if (!kReleaseMode) {
        await Future.delayed(Duration(seconds: 2));
      }
      try {
        widget.controller.createViewer(widget.width, widget.height);
      } catch (err) {
        _error = err.toString();
      }
      setState(() {});
    });

    super.initState();
  }

  Timer? _resizeTimer;
  bool _resizing = false;

  Future _resize() {
    final completer = Completer();
    // resizing the window can be sluggish (particular in debug mode), exacerbated when simultaneously recreating the swapchain and resize the window.
    // to address this, whenever the widget is resized, we set a timer for Xms in the future.
    // this timer will call [resize] with the widget size at that point in time.
    // any subsequent widget resizes will cancel the timer and replace with a new one.
    // debug mode does need a longer timeout.
    _resizeTimer?.cancel();

    _resizeTimer = Timer(const Duration(milliseconds: kReleaseMode ? 20 : 100), () async {
      if(!mounted) {
        return;
      }
      var size = ((context.findRenderObject()) as RenderBox).size;
      var width = size.width.ceil();
      var height = size.height.ceil();
      while (_resizing) {
        await Future.delayed(Duration(milliseconds: 20));
      }
      _resizing = true;
      await widget.controller.resize(width, height);
      _resizeTimer = null;
      setState(() {});
      _resizing = false;
      completer.complete();
    });
    return completer.future;
  }

  @override
  void didUpdateWidget(_SizedFilamentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.height != widget.height || oldWidget.width != widget.width) {
      _resize();
    }
  }

  @override
  void dispose() {
    _appLifecycleListener.dispose();
    super.dispose();
  }

  bool _wasRenderingOnInactive = false;

  void _handleStateChange(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.detached:
        print("Detached");

        if (widget.controller.textureDetails != null) {
          await widget.controller.destroyViewer();
          await widget.controller.destroyTexture();
        }
        break;
      case AppLifecycleState.hidden:
        print("Hidden");
        if (Platform.isIOS && widget.controller.textureDetails != null) {
          await widget.controller.destroyViewer();
          await widget.controller.destroyTexture();
        }
        break;
      case AppLifecycleState.inactive:
        print("Inactive");
        // on Windows in particular, restoring a window after minimizing stalls the renderer (and the whole application) for a considerable length of time.
        // disabling rendering on minimize seems to fix the issue (so I wonder if there's some kind of command buffer that's filling up while the window is minimized).
        _wasRenderingOnInactive = widget.controller.rendering;
        await widget.controller.setRendering(false);
        break;
      case AppLifecycleState.paused:
        print("Paused");
        break;
      case AppLifecycleState.resumed:
        print("Resumed");
        if (!Platform.isWindows) {
          if (widget.controller.textureDetails == null) {
            var size = ((context.findRenderObject()) as RenderBox).size;
            widget.controller
                .createViewer(size.width.ceil(), size.height.ceil());
          }
        } else {
          await _resize();
        }
        await widget.controller.setRendering(_wasRenderingOnInactive);
        break;
    }
    _lastState = state;
  }

  @override
  Widget build(BuildContext context) {
    // if an error was encountered in creating a viewer, display the error message and don't even try to display a Texture widget.
    if (_error != null) {
      return Container(
          color: Colors.white,
          child: Column(children: [
            const Text("A fatal error was encountered"),
            Text(_error!)
          ]));
    }

    if (widget.controller.textureDetails == null || _resizeTimer != null) {
      return widget.initial ?? Container(color: Colors.red);
    }
    // see [FilamentControllerFFI.resize] for an explanation of how we deal with resizing
    var texture = Texture(
      key: ObjectKey("texture_${widget.controller.textureDetails!.textureId}"),
      textureId: widget.controller.textureDetails!.textureId,
      filterQuality: FilterQuality.none,
      freeze: false,
    );

    return Stack(children: [
      Positioned.fill(
        child: Platform.isLinux || Platform.isWindows
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationX(
                      pi), // TODO - this rotation is due to OpenGL texture coordinate working in a different space from Flutter, can we move this to the C++ side somewhere?
                  child: texture)
              : texture)
    ]);
  }
}

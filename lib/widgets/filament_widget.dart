import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:polyvox_filament/filament_controller.dart';

import 'dart:async';

typedef ResizeCallback = void Function(Size oldSize, Size newSize);

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

  late var _oldSize = size;

  @override
  void performLayout() {
    super.performLayout();
    if (size != _oldSize) {
      onLayoutChangedCallback(_oldSize, size);
      _oldSize = size;
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
  TextureDetails? _textureDetails;

  late final AppLifecycleListener _listener;
  AppLifecycleState? _lastState;

  String? _error;

  int? _width;
  int? _height;

  void _handleStateChange(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.detached:
        print("Detached");
        _textureDetails = null;

        await widget.controller.destroyViewer();
        await widget.controller.destroyTexture();
        break;
      case AppLifecycleState.hidden:
        print("Hidden");
        if (Platform.isIOS) {
          _textureDetails = null;
          await widget.controller.destroyViewer();
          await widget.controller.destroyTexture();
        }
        break;
      case AppLifecycleState.inactive:
        print("Inactive");
        break;
      case AppLifecycleState.paused:
        print("Paused");
        break;
      case AppLifecycleState.resumed:
        print("Resumed");
        if (!Platform.isWindows) {
          if (_textureDetails == null) {
            var size = ((context.findRenderObject()) as RenderBox).size;
            print("Size after resuming : $size");
            _height = size.height.ceil();
            _width = size.width.ceil();
            await widget.controller
                .createViewer(_width!, _height!);
            print("Created viewer Size after resuming");
          }
        }
        break;
    }
    _lastState = state;
  }

  @override
  void initState() {
    _listener = AppLifecycleListener(
      onStateChange: _handleStateChange,
    );

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
      try {
        _textureDetails = await widget.controller
            .createViewer(_width!, _height!);
        
      } catch (err) {
        setState(() {
          _error = err.toString();
        });
      }
    });

    super.initState();
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  Timer? _resizeTimer;

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

    // if no texture ID is available, display the [initial] widget (solid red by default)
    late Widget content;

    if ( _textureDetails == null || _textureDetails!.height != _height || _textureDetails!.width != _width) {
      content = widget.initial ?? Container(color: Colors.red);
    } else {
      content = Texture(
        key: ObjectKey("texture_${_textureDetails!.textureId}"),
        textureId: _textureDetails!.textureId,
        filterQuality: FilterQuality.none,
        freeze: false,
      );
    }

    // see [FilamentControllerFFI.resize] for an explanation of how we deal with resizing
    return ResizeObserver(
        onResized: (Size oldSize, Size newSize) async {

          _resizeTimer?.cancel();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _resizeTimer = Timer(const Duration(milliseconds:50), () async {
              var newWidth = newSize.width.ceil();
              var newHeight = newSize.height.ceil();
              _textureDetails = await widget.controller
                  .resize(newWidth, newHeight);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _width = newWidth;
                  _height = newHeight;
                });
              });
            });
          });
        },
        child: Stack(children: [
          Positioned.fill(
              child: Platform.isLinux || Platform.isWindows
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationX(
                          pi), // TODO - this rotation is due to OpenGL texture coordinate working in a different space from Flutter, can we move this to the C++ side somewhere?
                      child: content)
                  : content)
        ]));
  }
}

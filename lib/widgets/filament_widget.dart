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
  final void Function()? onResize;

  const FilamentWidget(
      {Key? key, required this.controller, this.onResize, this.initial})
      : super(key: key);

  @override
  _FilamentWidgetState createState() => _FilamentWidgetState();
}

class _FilamentWidgetState extends State<FilamentWidget> {
  StreamSubscription? _textureIdListener;
  int? _textureId;

  late final AppLifecycleListener _listener;
  AppLifecycleState? _lastState;

  bool _resizing = false;

  String? _error;

  Timer? _resizeTimer;

  void _handleStateChange(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.detached:
        print("Detached");
        _textureId = null;

        await widget.controller.destroyViewer();
        await widget.controller.destroyTexture();
        break;
      case AppLifecycleState.hidden:
        print("Hidden");
        if (Platform.isIOS) {
          _textureId = null;
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
        if (_textureId == null) {
          var size = ((context.findRenderObject()) as RenderBox).size;
          print("Size after resuming : $size");
          await widget.controller
              .createViewer(size.width.toInt(), size.height.toInt());
          print("Created viewer Size after resuming");
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

      try {
        await widget.controller.createViewer(size.width.toInt(), size.height.toInt());
      } catch (err) {
        setState(() {
          _error = err.toString();
        });
      }
    });

    _textureIdListener = widget.controller.textureId.listen((int? textureId) {
      var size = ((context.findRenderObject()) as RenderBox).size;
      print(
          "Received new texture ID $textureId at size $size (current textureID  $_textureId)");
      setState(() {
        _textureId = textureId;
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    _textureIdListener?.cancel();
    _listener.dispose();
    _resizeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
          color: Colors.white,
          child: Column(children: [
            const Text("A fatal error was encountered"),
            Text(_error!)
          ]));
    }
    return LayoutBuilder(builder: ((context, constraints) {
      if (_textureId == null) {
        return widget.initial ?? Container(color: Colors.red);
      }
      var texture = Texture(
        key: ObjectKey("texture_$_textureId"),
        textureId: _textureId!,
        filterQuality: FilterQuality.none,
      );
      return SizedBox(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          child: ResizeObserver(
              onResized: (Size oldSize, Size newSize) async {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  _resizeTimer?.cancel();

                  _resizeTimer = Timer(Duration(milliseconds: 500), () async {
                    // setState(() {
                    //   _resizing = true;
                    // });

                    // TODO - we could snapshot the widget to display while we resize?

                    print("Resizing to $newSize");
                    // await widget.controller
                    //     .resize(newSize.width.toInt(), newSize.height.toInt());
                    // WidgetsBinding.instance.addPostFrameCallback((_) async {
                    //   setState(() {
                    //     _resizing = false;
                    //     widget.onResize?.call();
                    //   });
                    // });
                  });
                });
              },
              child: _resizing
                  ? Container()
                  : Platform.isLinux || Platform.isWindows
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationX(
                              pi), // TODO - this rotation is due to OpenGL texture coordinate working in a different space from Flutter, can we move this to the C++ side somewhere?
                          child: texture)
                      : texture));
    }));
  }
}

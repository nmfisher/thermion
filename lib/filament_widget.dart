import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

import 'dart:async';
import 'filament_controller.dart';

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
  final void Function()? onResize;

  const FilamentWidget({Key? key, required this.controller, this.onResize})
      : super(key: key);

  @override
  _FilamentWidgetState createState() => _FilamentWidgetState();
}

class _FilamentWidgetState extends State<FilamentWidget> {
  StreamSubscription? _textureIdListener;
  int? _textureId;
  bool _resizing = false;

  late final AppLifecycleListener _listener;
  AppLifecycleState? _lastState;

  void _handleStateChange(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.detached:
        print("Detached");
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
      var size = ((context.findRenderObject()) as RenderBox).size;
      widget.controller.createViewer(size.width.toInt(), size.height.toInt());
    });

    _textureIdListener = widget.controller.textureId.listen((int? textureId) {
      var size = ((context.findRenderObject()) as RenderBox).size;
      print("Set texture ID to $textureId, current size is $size");
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: ((context, constraints) {
      if (_textureId == null) {
        return Container(color: Colors.red);
      }

      var texture = Texture(
        key: ObjectKey("texture_$_textureId"),
        textureId: _textureId!,
        filterQuality: FilterQuality.high,
      );
      return SizedBox(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          child: ResizeObserver(
              onResized: (Size oldSize, Size newSize) async {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  setState(() {
                    _resizing = true;
                  });

                  await widget.controller
                      .resize(newSize.width.toInt(), newSize.height.toInt());
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    setState(() {
                      _resizing = false;
                      widget.onResize?.call();
                    });
                  });
                });
              },
              child: _resizing
                  ? Container()
                  : Platform.isLinux
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationX(
                              pi), // TODO - this rotation is due to OpenGL texture coordinate working in a different space from Flutter, can we move this to the C++ side somewhere?
                          child: texture)
                      : texture));
    }));
  }
}

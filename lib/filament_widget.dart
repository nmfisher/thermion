import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
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

  const FilamentWidget({Key? key, required this.controller}) : super(key: key);

  @override
  _FilamentWidgetState createState() => _FilamentWidgetState();
}

class _FilamentWidgetState extends State<FilamentWidget> {
  StreamSubscription? _initializationListener;
  StreamSubscription? _textureIdListener;
  int? _textureId;
  bool _resizing = false;
  bool _hasViewer = false;

  @override
  void initState() {
    _initializationListener =
        widget.controller.onInitializationRequested.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        var size = ((context.findRenderObject()) as RenderBox).size;
        print(
            "Requesting creation of Filament back-end texture/viewer for viewport size $size");
        await widget.controller
            .createViewer(size.width.toInt(), size.height.toInt());
        setState(() {
          _hasViewer = true;
        });

        _initializationListener!.cancel();
        _initializationListener = null;

        WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
          var size = ((context.findRenderObject()) as RenderBox).size;
          widget.controller.resize(size.width.toInt(), size.height.toInt());
          print("RESIZED IN POST FRAME CALLBACK TO $size");
        });
        setState(() {});
      });
    });
    _textureIdListener = widget.controller.textureId.listen((int? textureId) {
      setState(() {
        _textureId = textureId;
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    _initializationListener?.cancel();
    _textureIdListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: ((context, constraints) {
      print("constraints $constraints");
      if (_textureId == null) {
        return Container(color: Colors.transparent);
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
                if (!_hasViewer) {
                  return;
                }
                print("RESIZE OBSERVER $newSize");
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  setState(() {
                    _resizing = true;
                  });

                  await widget.controller
                      .resize(newSize.width.toInt(), newSize.height.toInt());
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    setState(() {
                      _resizing = false;
                    });
                  });
                });
              },
              child: Platform.isLinux
                  ? _resizing
                      ? Container()
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationX(
                              pi), // TODO - this rotation is due to OpenGL texture coordinate working in a different space from Flutter, can we move this to the C++ side somewhere?
                          child: texture)
                  : texture));
    }));
  }
}

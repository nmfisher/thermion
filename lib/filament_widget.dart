import 'dart:io';
import 'dart:math';

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
  StreamSubscription? _listener;

  bool _resizing = false;

  @override
  void initState() {
    _listener = widget.controller.onInitializationRequested.listen((_) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        var size = ((context.findRenderObject()) as RenderBox).size;
        print(
            "Requesting creation of Filament back-end texture/viewer for viewport size $size");
        await widget.controller
            .createViewer(size.width.toInt(), size.height.toInt());
        print("Filament texture/viewer created.");
        _listener!.cancel();
        _listener = null;
      });
      setState(() {});
    });

    super.initState();
  }

  void dispose() {
    _listener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: widget.controller.textureId,
        builder: (ctx, AsyncSnapshot<int?> textureId) {
          if (textureId.data == null) {
            return Container();
          }

          var texture = Texture(
            key: ObjectKey("texture_${textureId.data}"),
            textureId: textureId.data!,
            filterQuality: FilterQuality.high,
          );
          return LayoutBuilder(
              builder: ((context, constraints) => SizedBox(
                  height: constraints.maxHeight,
                  width: constraints.maxWidth,
                  child: ResizeObserver(
                      onResized: (Size oldSize, Size newSize) async {
                        setState(() {
                          _resizing = true;
                        });

                        await widget.controller.resize(
                            newSize.width.toInt(), newSize.height.toInt());
                        setState(() {
                          _resizing = false;
                        });
                      },
                      child: Platform.isLinux
                          ? _resizing
                              ? Container()
                              : Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.rotationX(pi),
                                  child: texture)
                          : texture))));
        });
  }
}

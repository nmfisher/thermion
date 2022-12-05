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
  bool _ready = false;
  StreamSubscription? _listener;

  @override
  void initState() {
    _listener = widget.controller.onInitializationRequested.listen((_) {
      if(_ready) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
        var size = ((context.findRenderObject()) as RenderBox).size;
        print("Requesting creation of Filament back-end texture/viewer for viewport size $size");
        await widget.controller
            .createTextureViewer(size.width.toInt(), size.height.toInt());
        print("Filament texture/viewer created.");
        setState(() {
          _ready = true;
        });
        _listener!.cancel();
        _listener = null;
      });
      // we need to make sure a new frame is requested, otherwise the callback may not run
      setState(() {
          
      });
    });

    super.initState();
  }

  void dispose() {
    _listener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Container();
    }
    return ResizeObserver(
        onResized: (Size oldSize, Size newSize) async {
          await widget.controller
              .resize(newSize.width.toInt(), newSize.height.toInt());
        },
        child: Texture(
          textureId: widget.controller.textureId,
          filterQuality: FilterQuality.none,
        ));
  }
}

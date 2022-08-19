import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
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

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      var size = ((context.findRenderObject()) as RenderBox).size;
      print("Requesting texture creation for Filament of size $size");
      await widget.controller
          .initialize(size.width.toInt(), size.height.toInt());
      print("Filament texture available");
      setState(() {
        _ready = true;
      });
    });

    super.initState();
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

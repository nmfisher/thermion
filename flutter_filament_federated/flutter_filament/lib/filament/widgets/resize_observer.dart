import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

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

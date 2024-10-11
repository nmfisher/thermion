import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:thermion_flutter/src/widgets/src/resize_observer.dart';
import 'package:thermion_flutter/src/widgets/src/transparent_filament_widget.dart';
import 'package:thermion_flutter/thermion_flutter.dart' as t;
import 'package:thermion_flutter_platform_interface/thermion_flutter_window.dart';

class ThermionWidgetWindows extends StatefulWidget {
  
  final t.ThermionViewer viewer;

  final t.View view;

  ///
  ///
  ///
  final Widget? initial;

  ///
  /// A callback that will be invoked whenever this widget (and the underlying texture is resized).
  ///
  final Future Function(Size size, t.View view, double pixelRatio)? onResize;

  const ThermionWidgetWindows({super.key, required this.viewer, this.initial, this.onResize, required this.view});
  
  
  @override
  State<StatefulWidget> createState() => _ThermionWidgetWindowsState();
}

class _ThermionWidgetWindowsState extends State<ThermionWidgetWindows> {

  ThermionFlutterWindow? _window;

  @override
  void initState() {
    super.initState();

     WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await widget.viewer.initialized;

      var dpr = MediaQuery.of(context).devicePixelRatio;

      var size = ((context.findRenderObject()) as RenderBox).size;
      var width = (size.width * dpr).ceil();
      var height = (size.height * dpr).ceil();

      _window = await t.ThermionFlutterPlatform.instance.createWindow(width, height, 0, 0);

      await widget.view.updateViewport(_window!.width, _window!.height);

      try {
        await widget.onResize?.call(
            Size(_window!.width.toDouble(), _window!.height.toDouble()),
            widget.view,
            dpr);
      } catch (err, st) {
        print(err);
        print(st);
      }

      if (mounted) {
        setState(() {});
      }

      _requestFrame();

      widget.viewer.onDispose(() async {
        var window = _window;
        if (mounted) {
          setState(() {});
        }
        await window?.destroy();
      });
    });
  }

  bool _rendering = false;

  void _requestFrame() {
    WidgetsBinding.instance.scheduleFrameCallback((d) async {
      if (widget.viewer.rendering && !_rendering) {
        _rendering = true;
        await widget.viewer.requestFrame();
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

      if (newSize.width == _window?.width &&
          newSize.height == _window?.height) {
        return;
      }

      final completer = Completer();

      _resizing.add(completer.future);

      final dpr = MediaQuery.of(context).devicePixelRatio;

      newSize *= dpr;

      var newWidth = newSize.width.ceil();
      var newHeight = newSize.height.ceil();

      await _window?.resize(
        newWidth,
        newHeight,
        0,
        0,
      );

      await widget.view.updateViewport(_window!.width, _window!.height);

      await widget.onResize?.call(
          Size(_window!.width.toDouble(), _window!.height.toDouble()),
          widget.view,
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
    if (_window == null) {
      return widget.initial ?? Container(color: Colors.red);
    }

    return ResizeObserver(
        onResized: _resize,
        child: CustomPaint(painter:TransparencyPainter()));
  }

}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_flutter/src/widgets/src/pixel_ratio_aware.dart';
import 'package:vector_math/vector_math_64.dart';

extension OffsetExtension on Offset {
  Vector2 toVector2() {
    return Vector2(dx, dy);
  }
}

///
/// A widget that captures swipe/pointer events.
/// This is a dumb listener; events are forwarded to a [InputHandler].
///
class ThermionListenerWidget extends StatefulWidget {
  ///
  /// The content to display below the gesture detector/listener widget.
  /// This will usually be a ThermionWidget (so you can navigate by directly interacting with the viewport), but this is not necessary.
  /// It is equally possible to render the viewport/gesture controls elsewhere in the widget hierarchy. The only requirement is that they share the same [FilamentViewer].
  ///
  final Widget? child;

  ///
  /// The handler to use for interpreting gestures/pointer movements.
  ///
  final InputHandler gestureHandler;

  const ThermionListenerWidget({
    Key? key,
    required this.gestureHandler,
    this.child,
  }) : super(key: key);

  @override
  State<ThermionListenerWidget> createState() => _ThermionListenerWidgetState();
}

class _ThermionListenerWidgetState extends State<ThermionListenerWidget> {
  bool get isDesktop =>
      kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  final _keyMap = {
    PhysicalKeyboardKey.keyW: PhysicalKey.W,
    PhysicalKeyboardKey.keyA: PhysicalKey.A,
    PhysicalKeyboardKey.keyS: PhysicalKey.S,
    PhysicalKeyboardKey.keyD: PhysicalKey.D,
  };

  bool _handleKeyEvent(KeyEvent event) {
    PhysicalKey? key = _keyMap[event.physicalKey];

    if (key == null) {
      return false;
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      widget.gestureHandler.keyDown(key!);
    } else if (event is KeyUpEvent) {
      widget.gestureHandler.keyUp(key!);
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    super.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
  }

  Widget _desktop(double pixelRatio) {
    return Listener(
      onPointerHover: (event) => widget.gestureHandler.onPointerHover(
          event.localPosition.toVector2() * pixelRatio,
          event.delta.toVector2() * pixelRatio),
      onPointerSignal: (PointerSignalEvent pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          widget.gestureHandler.onPointerScroll(
              pointerSignal.localPosition.toVector2() * pixelRatio,
              pointerSignal.scrollDelta.dy * pixelRatio);
        }
      },
      onPointerPanZoomStart: (pzs) {
        throw Exception("TODO - is this a pinch zoom on laptop trackpad?");
      },
      onPointerDown: (d) => widget.gestureHandler.onPointerDown(
          d.localPosition.toVector2() * pixelRatio,
          d.buttons & kMiddleMouseButton != 0),
      onPointerMove: (d) => widget.gestureHandler.onPointerMove(
          d.localPosition.toVector2() * pixelRatio,
          d.delta.toVector2() * pixelRatio,
          d.buttons & kMiddleMouseButton != 0),
      onPointerUp: (d) => widget.gestureHandler
          .onPointerUp(d.buttons & kMiddleMouseButton != 0),
      child: widget.child,
    );
  }

  Widget _mobile(double pixelRatio) {
    return _MobileListenerWidget(
        gestureHandler: widget.gestureHandler, pixelRatio: pixelRatio);
  }

  @override
  Widget build(BuildContext context) {
    return PixelRatioAware(builder: (ctx, pixelRatio) {
      return FutureBuilder(
          initialData: 1.0,
          future: widget.gestureHandler.initialized,
          builder: (_, initialized) {
            if (initialized.data != true) {
              return widget.child ?? Container();
            }
            return Stack(children: [
              if (widget.child != null) Positioned.fill(child: widget.child!),
              if (isDesktop) Positioned.fill(child: _desktop(pixelRatio)),
              if (!isDesktop) Positioned.fill(child: _mobile(pixelRatio))
            ]);
          });
    });
  }
}

class _MobileListenerWidget extends StatefulWidget {
  final InputHandler gestureHandler;
  final double pixelRatio;

  const _MobileListenerWidget({Key? key, required this.gestureHandler, required this.pixelRatio})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _MobileListenerWidgetState();
}

class _MobileListenerWidgetState extends State<_MobileListenerWidget> {
  bool isPan = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) => widget.gestureHandler
          .onPointerDown(details.localPosition.toVector2() * widget.pixelRatio, false),
      onDoubleTap: () {
        widget.gestureHandler.setActionForType(InputType.SCALE1,
            isPan ? InputAction.TRANSLATE : InputAction.ROTATE);
      },
      onScaleStart: (details) async {
        await widget.gestureHandler.onScaleStart();
      },
      onScaleUpdate: (details) async {
        await widget.gestureHandler.onScaleUpdate();
      },
      onScaleEnd: (details) async {
        await widget.gestureHandler.onScaleUpdate();
      },
    );
  }
}

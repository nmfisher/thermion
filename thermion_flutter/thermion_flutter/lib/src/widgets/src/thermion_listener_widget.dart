import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide KeyEvent;
import 'package:thermion_dart/thermion_dart.dart' hide KeyEvent;
import 'package:thermion_dart/thermion_dart.dart' as t;
import 'package:thermion_flutter/src/widgets/src/pixel_ratio_aware.dart';

extension OffsetExtension on Offset {
  Vector2 toVector2() {
    return Vector2(dx, dy);
  }
}

final physicalKeyMap = {
  PhysicalKeyboardKey.keyW: PhysicalKey.w,
  PhysicalKeyboardKey.keyA: PhysicalKey.a,
  PhysicalKeyboardKey.keyS: PhysicalKey.s,
  PhysicalKeyboardKey.keyD: PhysicalKey.d,
  PhysicalKeyboardKey.escape: PhysicalKey.esc,
  PhysicalKeyboardKey.delete: PhysicalKey.del,
  PhysicalKeyboardKey.keyG: PhysicalKey.g,
  PhysicalKeyboardKey.keyR: PhysicalKey.r,
  PhysicalKeyboardKey.keyX: PhysicalKey.x,
  PhysicalKeyboardKey.keyY: PhysicalKey.y,
  PhysicalKeyboardKey.keyZ: PhysicalKey.z,
  PhysicalKeyboardKey.shiftLeft: PhysicalKey.shift,
  PhysicalKeyboardKey.space: PhysicalKey.space,
  PhysicalKeyboardKey.backquote: PhysicalKey.backtick,
  PhysicalKeyboardKey.period: PhysicalKey.period,
  PhysicalKeyboardKey.digit0: PhysicalKey.key0,
  PhysicalKeyboardKey.digit1: PhysicalKey.key1,
  PhysicalKeyboardKey.digit2: PhysicalKey.key2,
  PhysicalKeyboardKey.digit3: PhysicalKey.key3,
  PhysicalKeyboardKey.digit4: PhysicalKey.key4,
  PhysicalKeyboardKey.digit5: PhysicalKey.key5,
  PhysicalKeyboardKey.digit6: PhysicalKey.key6,
  PhysicalKeyboardKey.digit7: PhysicalKey.key7,
  PhysicalKeyboardKey.digit8: PhysicalKey.key8,
  PhysicalKeyboardKey.digit9: PhysicalKey.key9,
  PhysicalKeyboardKey.numpad0: PhysicalKey.numpad0,
  PhysicalKeyboardKey.numpad1: PhysicalKey.numpad1,
  PhysicalKeyboardKey.numpad2: PhysicalKey.numpad2,
  PhysicalKeyboardKey.numpad3: PhysicalKey.numpad3,
  PhysicalKeyboardKey.numpad4: PhysicalKey.numpad4,
  PhysicalKeyboardKey.numpad5: PhysicalKey.numpad5,
  PhysicalKeyboardKey.numpad6: PhysicalKey.numpad6,
  PhysicalKeyboardKey.numpad7: PhysicalKey.numpad7,
  PhysicalKeyboardKey.numpad8: PhysicalKey.numpad8,
  PhysicalKeyboardKey.numpad9: PhysicalKey.numpad9,
  PhysicalKeyboardKey.numpadDecimal: PhysicalKey.numpadPeriod,
  PhysicalKeyboardKey.enter: PhysicalKey.enter,
  PhysicalKeyboardKey.numpadEnter: PhysicalKey.numpadEnter
};

final logicalKeyMap = {
  LogicalKeyboardKey.keyW: LogicalKey.w,
  LogicalKeyboardKey.keyA: LogicalKey.a,
  LogicalKeyboardKey.keyS: LogicalKey.s,
  LogicalKeyboardKey.keyD: LogicalKey.d,
  LogicalKeyboardKey.escape: LogicalKey.esc,
  LogicalKeyboardKey.delete: LogicalKey.del,
  LogicalKeyboardKey.keyG: LogicalKey.g,
  LogicalKeyboardKey.keyR: LogicalKey.r,
  LogicalKeyboardKey.keyX: LogicalKey.x,
  LogicalKeyboardKey.keyY: LogicalKey.y,
  LogicalKeyboardKey.keyZ: LogicalKey.z,
  LogicalKeyboardKey.shift: LogicalKey.shift,
  LogicalKeyboardKey.shiftLeft: LogicalKey.shift,
  LogicalKeyboardKey.space: LogicalKey.space,
  LogicalKeyboardKey.backquote: LogicalKey.backtick,
  LogicalKeyboardKey.digit0: LogicalKey.key0,
  LogicalKeyboardKey.digit1: LogicalKey.key1,
  LogicalKeyboardKey.digit2: LogicalKey.key2,
  LogicalKeyboardKey.digit3: LogicalKey.key3,
  LogicalKeyboardKey.digit4: LogicalKey.key4,
  LogicalKeyboardKey.digit5: LogicalKey.key5,
  LogicalKeyboardKey.digit6: LogicalKey.key6,
  LogicalKeyboardKey.digit7: LogicalKey.key7,
  LogicalKeyboardKey.digit8: LogicalKey.key8,
  LogicalKeyboardKey.digit9: LogicalKey.key9,
  LogicalKeyboardKey.numpad0: LogicalKey.numpad0,
  LogicalKeyboardKey.numpad1: LogicalKey.numpad1,
  LogicalKeyboardKey.numpad2: LogicalKey.numpad2,
  LogicalKeyboardKey.numpad3: LogicalKey.numpad3,
  LogicalKeyboardKey.numpad4: LogicalKey.numpad4,
  LogicalKeyboardKey.numpad5: LogicalKey.numpad5,
  LogicalKeyboardKey.numpad6: LogicalKey.numpad6,
  LogicalKeyboardKey.numpad7: LogicalKey.numpad7,
  LogicalKeyboardKey.numpad8: LogicalKey.numpad8,
  LogicalKeyboardKey.numpad9: LogicalKey.numpad9,
  LogicalKeyboardKey.numpadDecimal: LogicalKey.numpadPeriod,
  LogicalKeyboardKey.enter: LogicalKey.enter,
  LogicalKeyboardKey.numpadEnter: LogicalKey.numpadEnter
};

///
/// Forwards cross-platform touch/mouse events to an
/// [InputHandler].
///
class ThermionListenerWidget extends StatefulWidget {
  /// The content to display below the gesture detector/listener widget.
  /// This will usually be a ThermionWidget (so you can navigate by directly
  /// interacting with the viewport), but this is not necessary. It is equally
  /// possible to render the viewport/gesture controls elsewhere in the widget
  /// hierarchy.
  final Widget? child;

  /// A focus node for input events.
  ///
  ///
  final FocusNode? focusNode;

  ///
  /// The handler to use for interpreting gestures/pointer movements.
  ///
  final InputHandler inputHandler;

  ///
  ///
  ///
  final bool addKeyboardListener;

  ///
  ///
  ///
  final bool propagateEvents;

  ///
  ///
  ///
  const ThermionListenerWidget(
      {Key? key,
      required this.inputHandler,
      this.focusNode,
      this.child,
      this.addKeyboardListener = true,
      this.propagateEvents = true})
      : super(key: key);

  @override
  State<ThermionListenerWidget> createState() => _ThermionListenerWidgetState();
}

class _ThermionListenerWidgetState extends State<ThermionListenerWidget> {
  bool get isDesktop =>
      kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    if (widget.addKeyboardListener) {
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    }
  }

  @override
  void dispose() {
    super.dispose();
    if (widget.addKeyboardListener) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
  }

  bool _handleKeyEvent(KeyEvent event) {
    final physicalKey = physicalKeyMap[event.physicalKey];
    final logicalKey = logicalKeyMap[event.logicalKey];

    if (physicalKey == null || logicalKey == null) {
      return false;
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      widget.inputHandler.handle(t.KeyEvent(
          KeyEventType.down, logicalKey, physicalKey,
          synthesized: event.synthesized));
    } else if (event is KeyUpEvent) {
      widget.inputHandler.handle(t.KeyEvent(
          KeyEventType.up, logicalKey, physicalKey,
          synthesized: event.synthesized));
      return true;
    }
    return !widget.propagateEvents;
  }

  t.MouseButton? _mouseButtonFromEvent(PointerEvent event) {
    t.MouseButton? button;

    if (event.buttons & kMiddleMouseButton != 0) {
      button = MouseButton.middle;
    } else if (event.buttons & kPrimaryMouseButton != 0) {
      button = MouseButton.left;
    } else if (event.buttons & kSecondaryMouseButton != 0) {
      button = MouseButton.right;
    }
    return button;
  }

  Widget _desktop(double pixelRatio) {
    return Focus(
        focusNode: widget.focusNode,
        child: Listener(
          onPointerHover: (event) async {
            widget.inputHandler.handle(MouseEvent(
                MouseEventType.hover,
                _mouseButtonFromEvent(event),
                event.localPosition.toVector2() * pixelRatio,
                event.delta.toVector2() * pixelRatio));
          },
          onPointerSignal: (PointerSignalEvent pointerSignal) async {
            if (pointerSignal is PointerScrollEvent) {
              widget.inputHandler.handle(ScrollEvent(
                  localPosition:
                      pointerSignal.localPosition.toVector2() * pixelRatio,
                  delta: pointerSignal.scrollDelta.dy * pixelRatio));
            }
          },
          onPointerPanZoomStart: (pzs) {
            throw Exception("TODO - is this a pinch zoom on laptop trackpad?");
          },
          onPointerDown: (event) async {
            widget.focusNode?.requestFocus();

            widget.inputHandler.handle(MouseEvent(
                MouseEventType.buttonDown,
                _mouseButtonFromEvent(event),
                event.localPosition.toVector2() * pixelRatio,
                event.delta.toVector2() * pixelRatio));
          },
          onPointerMove: (PointerMoveEvent event) {
            widget.inputHandler.handle(MouseEvent(
                MouseEventType.move,
                _mouseButtonFromEvent(event),
                event.localPosition.toVector2() * pixelRatio,
                event.delta.toVector2() * pixelRatio));
          },
          onPointerUp: (event) {
            widget.inputHandler.handle(MouseEvent(
                MouseEventType.buttonUp,
                _mouseButtonFromEvent(event),
                event.localPosition.toVector2() * pixelRatio,
                event.delta.toVector2() * pixelRatio));
          },
          child: widget.child,
        ));
  }

  Widget _mobile(double pixelRatio) {
    return _MobileListenerWidget(
        inputHandler: widget.inputHandler,
        pixelRatio: pixelRatio,
        child: widget.child);
  }

  @override
  Widget build(BuildContext context) {
    return PixelRatioAware(builder: (ctx, pixelRatio) {
      return SizedBox.expand(
          child: isDesktop ? _desktop(pixelRatio) : _mobile(pixelRatio));
    });
  }
}

class _MobileListenerWidget extends StatefulWidget {
  final InputHandler inputHandler;
  final double pixelRatio;
  final Widget? child;

  const _MobileListenerWidget(
      {Key? key,
      required this.inputHandler,
      required this.pixelRatio,
      this.child})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _MobileListenerWidgetState();
}

class _MobileListenerWidgetState extends State<_MobileListenerWidget> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) {
          widget.inputHandler.handle(TouchEvent(TouchEventType.tap,
              details.localPosition.toVector2() * widget.pixelRatio, null));
        },
        onDoubleTap: () {
          widget.inputHandler
              .handle(TouchEvent(TouchEventType.doubleTap, null, null));
        },
        onScaleStart: (ScaleStartDetails event) async {
          widget.inputHandler.handle(ScaleStartEvent(
              numPointers: event.pointerCount,
              localFocalPoint: (
                event.focalPoint.dx * widget.pixelRatio,
                event.focalPoint.dy * widget.pixelRatio
              )));
        },
        onScaleUpdate: (ScaleUpdateDetails event) async {
          widget.inputHandler.handle(ScaleUpdateEvent(
            numPointers: event.pointerCount,
            localFocalPoint: (
              event.focalPoint.dx * widget.pixelRatio,
              event.focalPoint.dy * widget.pixelRatio
            ),
            localFocalPointDelta: (
              event.focalPointDelta.dx * widget.pixelRatio,
              event.focalPointDelta.dy * widget.pixelRatio
            ),
            rotation: event.rotation,
            horizontalScale: event.horizontalScale,
            verticalScale: event.verticalScale,
            scale: event.scale,
          ));
        },
        onScaleEnd: (details) async {
          widget.inputHandler
              .handle(ScaleEndEvent(numPointers: details.pointerCount));
        },
        child: widget.child);
  }
}

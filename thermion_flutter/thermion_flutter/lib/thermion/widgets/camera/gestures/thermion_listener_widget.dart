import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/thermion_gesture_handler.dart';

///
/// A widget that captures swipe/pointer events.
/// This is a dumb listener; events are forwarded to a [ThermionGestureHandler].
///
class ThermionListenerWidget extends StatelessWidget {
  ///
  /// The content to display below the gesture detector/listener widget.
  /// This will usually be a ThermionWidget (so you can navigate by directly interacting with the viewport), but this is not necessary.
  /// It is equally possible to render the viewport/gesture controls elsewhere in the widget hierarchy. The only requirement is that they share the same [FilamentViewer].
  ///
  final Widget? child;

  ///
  /// The handler to use for interpreting gestures/pointer movements.
  ///
  final ThermionGestureHandler gestureHandler;

  const ThermionListenerWidget({
    Key? key,
    required this.gestureHandler,
    this.child,
  }) : super(key: key);

  bool get isDesktop =>
      kIsWeb || Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  Widget _desktop() { 
    return Listener(
      onPointerHover: (event) =>
          gestureHandler.onPointerHover(event.localPosition, event.delta),
      onPointerSignal: (PointerSignalEvent pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          gestureHandler.onPointerScroll(
              pointerSignal.localPosition, pointerSignal.scrollDelta.dy);
        }
      },
      onPointerPanZoomStart: (pzs) {
        throw Exception("TODO - is this a pinch zoom on laptop trackpad?");
      },
      onPointerDown: (d) =>
          gestureHandler.onPointerDown(d.localPosition, d.buttons),
      onPointerMove: (d) =>
          gestureHandler.onPointerMove(d.localPosition, d.delta, d.buttons),
      onPointerUp: (d) => gestureHandler.onPointerUp(d.buttons),
      child: child,
    );
  }

  Widget _mobile() { 
    return _MobileListenerWidget(
      gestureHandler: gestureHandler);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: gestureHandler.initialized,
        builder: (_, initialized) {
          if (initialized.data != true) {
            return child ?? Container();
          }
          return Stack(children: [
            if (child != null) Positioned.fill(child: child!),
            if (isDesktop)
              Positioned.fill(
                  child: _desktop()),
            if (!isDesktop)
              Positioned.fill(
                  child: _mobile())
          ]);
        });
  }
}


class _MobileListenerWidget extends StatefulWidget {
  final ThermionGestureHandler gestureHandler;

  const _MobileListenerWidget(
      {Key? key, required this.gestureHandler})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _MobileListenerWidgetState();
}

class _MobileListenerWidgetState
    extends State<_MobileListenerWidget> {
  GestureAction current = GestureAction.PAN_CAMERA;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) =>
              widget.gestureHandler.onPointerDown(details.localPosition, 0),
          onDoubleTap: () {
            if (current == GestureAction.PAN_CAMERA) {
              widget.gestureHandler.setActionForType(
                  GestureType.SCALE1, GestureAction.ROTATE_CAMERA);
              current = GestureAction.ROTATE_CAMERA;
            } else {
              widget.gestureHandler.setActionForType(
                  GestureType.SCALE1, GestureAction.PAN_CAMERA);
              current = GestureAction.PAN_CAMERA;
            }
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

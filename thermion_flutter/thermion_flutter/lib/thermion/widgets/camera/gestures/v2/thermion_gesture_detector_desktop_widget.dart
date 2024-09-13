import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/thermion_gesture_handler.dart';

class ThermionGestureDetectorDesktop extends StatelessWidget {

  final ThermionGestureHandler gestureHandler;

  const ThermionGestureDetectorDesktop({
    Key? key,
    required this.gestureHandler,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerHover: (event) =>
          gestureHandler.onPointerHover(event.localPosition),
      onPointerSignal: (PointerSignalEvent pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          gestureHandler.onPointerScroll(
              pointerSignal.localPosition, pointerSignal.scrollDelta.dy);
        }
      },
      onPointerPanZoomStart: (pzs) {
        throw Exception("TODO - is this a pinch zoom on laptop trackpad?");
      },
      onPointerDown: (d) {
          gestureHandler.onPointerDown(d.localPosition, d.buttons);
      },
      onPointerMove: (d) =>
          gestureHandler.onPointerMove(d.localPosition, d.delta, d.buttons),
      onPointerUp: (d) => gestureHandler.onPointerUp(d.buttons),
      child: Container(color: Colors.transparent,),
    );
  }
}

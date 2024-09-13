import 'package:flutter/widgets.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/thermion_gesture_handler.dart';

class ThermionGestureDetectorMobile extends StatefulWidget {
  final Widget? child;
  final ThermionGestureHandler gestureHandler;

  const ThermionGestureDetectorMobile(
      {Key? key, required this.gestureHandler, this.child})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _ThermionGestureDetectorMobileState();
}

class _ThermionGestureDetectorMobileState
    extends State<ThermionGestureDetectorMobile> {
  GestureAction current = GestureAction.PAN_CAMERA;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
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
          child: widget.child,
        ),
      ),
    ]);
  }
}

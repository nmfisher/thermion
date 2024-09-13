import 'package:flutter/widgets.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/thermion_gesture_handler.dart';

class ThermionGestureDetectorMobile extends StatefulWidget {
  final Widget? child;
  final ThermionGestureHandler gestureHandler;

  const ThermionGestureDetectorMobile({
    Key? key,
    required this.gestureHandler,
    this.child,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _ThermionGestureDetectorMobileState();
}

class _ThermionGestureDetectorMobileState
    extends State<ThermionGestureDetectorMobile> {
  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) =>
              widget.gestureHandler.onPointerDown(details.localPosition, 0),
          onDoubleTap: () {
            var current = widget.gestureHandler.getActionForType(GestureType.SCALE);
            if(current == GestureAction.PAN_CAMERA) {
              widget.gestureHandler.setActionForType(GestureType.SCALE, GestureAction.ROTATE_CAMERA);
            } else {
              widget.gestureHandler.setActionForType(GestureType.SCALE, GestureAction.PAN_CAMERA);
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

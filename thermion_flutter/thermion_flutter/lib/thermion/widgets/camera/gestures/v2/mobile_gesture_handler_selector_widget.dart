import 'package:flutter/widgets.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/thermion_gesture_handler.dart';

class MobileGestureHandlerSelectorWidget extends StatelessWidget {
  final ThermionGestureHandler handler;

  const MobileGestureHandlerSelectorWidget({super.key, required this.handler});
  @override
  Widget build(BuildContext context) {
    throw Exception("TODO");
    // return GestureDetector(
    //   onTap: () {

    //       var curIdx =
    //           GestureType.values.indexOf(handler.gestureType);
    //       var nextIdx =
    //           curIdx == GestureType.values.length - 1 ? 0 : curIdx + 1;
    //       handler.setGestureType(GestureType.values[nextIdx]);
    //     });
    //   },
    //   child: Container(
    //     padding: const EdgeInsets.all(50),
    //     child: Icon(_icons[widget.gestureHandler.gestureType],
    //         color: Colors.green),
    //   ),
    // );
  }
}

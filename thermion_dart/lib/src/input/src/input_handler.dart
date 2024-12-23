import 'dart:async';
import 'package:vector_math/vector_math_64.dart';

enum InputType {
  LMB_DOWN,
  LMB_HOLD_AND_MOVE,
  LMB_UP,
  LMB_HOVER,
  MMB_DOWN,
  MMB_HOLD_AND_MOVE,

  MMB_UP,
  MMB_HOVER,
  SCALE1,
  SCALE2, // two fingers pinchin in/out
  SCALE2_ROTATE, // two fingers rotating in a circle
  SCALE2_MOVE, // two fingers sliding along a line
  SCROLLWHEEL,
  POINTER_MOVE,
  KEYDOWN_W,
  KEYDOWN_A,
  KEYDOWN_S,
  KEYDOWN_D,
}

enum PhysicalKey { W, A, S, D }

enum InputAction { TRANSLATE, ROTATE, PICK, ZOOM, NONE }

abstract class InputHandler {
  
  @Deprecated("Use @transformUpdated instead")
  Stream get cameraUpdated => transformUpdated;

  Stream<Matrix4> get transformUpdated;

  Future? onPointerHover(Vector2 localPosition, Vector2 delta);
  Future? onPointerScroll(Vector2 localPosition, double scrollDelta);
  Future? onPointerDown(Vector2 localPosition, bool isMiddle);
  Future? onPointerMove(
      Vector2 localPosition, Vector2 delta, bool isMiddle);
  Future? onPointerUp(bool isMiddle);
  Future? onScaleStart(
      Vector2 focalPoint, int pointerCount, Duration? sourceTimestamp);
  Future? onScaleUpdate(
      Vector2 focalPoint,
      Vector2 focalPointDelta,
      double horizontalScale,
      double verticalScale,
      double scale,
      int pointerCount,
      double rotation,
      Duration? sourceTimestamp);
  Future? onScaleEnd(int pointerCount, double velocity);
  Future<bool> get initialized;
  Future dispose();

  void setActionForType(InputType gestureType, InputAction gestureAction);
  InputAction? getActionForType(InputType gestureType);

  void keyDown(PhysicalKey key);
  void keyUp(PhysicalKey key);

}

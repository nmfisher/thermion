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
  SCALE2,
  SCROLLWHEEL,
  POINTER_MOVE,
  KEYDOWN_W,
  KEYDOWN_A,
  KEYDOWN_S,
  KEYDOWN_D,
}

enum PhysicalKey { W, A, S, D }

enum InputAction { TRANSLATE, ROTATE, PICK, NONE }

abstract class InputHandler {
  
  Future<void> onPointerHover(Vector2 localPosition, Vector2 delta);
  Future<void> onPointerScroll(Vector2 localPosition, double scrollDelta);
  Future<void> onPointerDown(Vector2 localPosition, bool isMiddle);
  Future<void> onPointerMove(Vector2 localPosition, Vector2 delta, bool isMiddle);
  Future<void> onPointerUp(bool isMiddle);
  Future<void> onScaleStart();
  Future<void> onScaleUpdate();
  Future<void> onScaleEnd();
  Future<bool> get initialized;
  Future dispose();

  void setActionForType(InputType gestureType, InputAction gestureAction);
  InputAction? getActionForType(InputType gestureType);

  void keyDown(PhysicalKey key);
  void keyUp(PhysicalKey key);
}

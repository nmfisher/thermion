import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/delegates.dart';

enum GestureType {
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
  POINTER_MOVE
}

enum GestureAction {
  PAN_CAMERA,
  ROTATE_CAMERA,
  ZOOM_CAMERA,
  TRANSLATE_ENTITY,
  ROTATE_ENTITY,
  NONE
}

enum ThermionGestureState {
  NULL,
  ROTATING,
  PANNING,
  ZOOMING, // aka SCROLL
}

abstract class ThermionGestureHandler {
  Future<void> onPointerHover(Offset localPosition, Offset delta);
  Future<void> onPointerScroll(Offset localPosition, double scrollDelta);
  Future<void> onPointerDown(Offset localPosition, int buttons);
  Future<void> onPointerMove(Offset localPosition, Offset delta, int buttons);
  Future<void> onPointerUp(int buttons);
  Future<void> onScaleStart();
  Future<void> onScaleUpdate();
  Future<void> onScaleEnd();
  Future<bool> get initialized;
  void dispose();

  void setActionForType(GestureType gestureType, GestureAction gestureAction);
  GestureAction? getActionForType(GestureType gestureType);
}

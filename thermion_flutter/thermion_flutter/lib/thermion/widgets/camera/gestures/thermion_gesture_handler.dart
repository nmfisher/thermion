import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/delegates.dart';

enum GestureType {
  POINTER1_DOWN,
  POINTER1_MOVE,
  POINTER1_UP,
  POINTER1_HOVER,
  POINTER2_DOWN,
  POINTER2_MOVE,
  POINTER2_UP,
  POINTER2_HOVER,
  SCALE1,
  SCALE2,
  POINTER_ZOOM,
}

enum GestureAction {
  PAN_CAMERA,
  ROTATE_CAMERA,
  ZOOM_CAMERA,
  TRANSLATE_ENTITY,
  ROTATE_ENTITY
}

enum ThermionGestureState {
  NULL,
  ROTATING,
  PANNING,
  ZOOMING, // aka SCROLL
}

abstract class ThermionGestureHandler {
  Future<void> onPointerHover(Offset localPosition);
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

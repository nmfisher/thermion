import 'package:vector_math/vector_math_64.dart';

sealed class InputEvent {}

enum MouseButton { left, middle, right }

enum MouseEventType { hover, move, buttonDown, buttonUp }

class MouseEvent extends InputEvent {
  final MouseEventType type;
  final MouseButton? button;
  final Vector2 localPosition;
  final Vector2 delta;

  MouseEvent(this.type, this.button, this.localPosition, this.delta);
}

enum TouchEventType {
  // move,
  tap,
  doubleTap,
}

class TouchEvent extends InputEvent {
  final TouchEventType type;
  final Vector2? localPosition;
  final Vector2? delta;

  TouchEvent(this.type, this.localPosition, this.delta);
}

enum ScaleEventType { start, update, end }

class ScaleStartEvent extends InputEvent {
  final int numPointers;
  final ScaleEventType type = ScaleEventType.start;
  final (double, double) localFocalPoint;

  ScaleStartEvent({
    required this.numPointers,
    required this.localFocalPoint,
  });
}

class ScaleEndEvent extends InputEvent {
  final int numPointers;
  final ScaleEventType type = ScaleEventType.end;

  ScaleEndEvent({
    required this.numPointers,
  });
}

class ScaleUpdateEvent extends InputEvent {
  final int numPointers;
  final ScaleEventType type = ScaleEventType.update;
  final (double, double) localFocalPoint;
  final (double, double)? localFocalPointDelta;
  final double rotation;
  final double scale;
  final double horizontalScale;
  final double verticalScale;

  ScaleUpdateEvent(
      {required this.numPointers,
      required this.localFocalPoint,
      required this.localFocalPointDelta,
      required this.rotation,
      required this.scale,
      required this.horizontalScale,
      required this.verticalScale});
}

class ScrollEvent extends InputEvent {
  final Vector2 localPosition;
  final double delta;

  ScrollEvent({required this.localPosition, required this.delta});
}

class KeyEvent extends InputEvent {
  final KeyEventType type;
  final LogicalKey logicalKey;
  final PhysicalKey physicalKey;
  final bool synthesized;

  KeyEvent(this.type, this.logicalKey, this.physicalKey,
      {this.synthesized = false});
}

enum KeyEventType { down, up }

enum LogicalKey {
  w,
  a,
  s,
  d,
  g,
  r,
  x,
  y,
  z,
  shift,
  esc,
  del,
  space,
  backtick,
  key0,
  key1,
  key2,
  key3,
  key4,
  key5,
  key6,
  key7,
  key8,
  key9,
  period,
  numpad0,
  numpad1,
  numpad2,
  numpad3,
  numpad4,
  numpad5,
  numpad6,
  numpad7,
  numpad8,
  numpad9,
  numpadPeriod,
  numpadEnter,
  enter
}

enum PhysicalKey {
  w,
  a,
  s,
  d,
  g,
  r,
  x,
  y,
  z,
  shift,
  esc,
  del,
  space,
  backtick,
  key0,
  key1,
  key2,
  key3,
  key4,
  key5,
  key6,
  key7,
  key8,
  key9,
  enter,
  period,
  numpad0,
  numpad1,
  numpad2,
  numpad3,
  numpad4,
  numpad5,
  numpad6,
  numpad7,
  numpad8,
  numpad9,
  numpadPeriod,
  numpadEnter
}

enum InputAction { TRANSLATE, ROTATE, PICK, ZOOM, NONE }

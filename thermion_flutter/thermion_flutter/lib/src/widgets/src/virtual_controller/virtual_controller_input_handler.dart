import 'package:thermion_dart/thermion_dart.dart';

enum DPadDirection { up, down, left, right, none }

class VirtualControllerInputHandler {
  final InputHandler inputHandler;
  final double mouseSensitivity;

  final Map<DPadDirection, bool> _dPadStates = {
    DPadDirection.up: false,
    DPadDirection.down: false,
    DPadDirection.left: false,
    DPadDirection.right: false,
  };

  Vector2? _lastAnalogPosition;

  VirtualControllerInputHandler({
    required this.inputHandler,
    this.mouseSensitivity = 0.01,
  });

  void handleDPadPress(DPadDirection direction, bool pressed) {
    _dPadStates[direction] = pressed;

    switch (direction) {
      case DPadDirection.up:
        _sendKeyEvent(LogicalKey.w, PhysicalKey.w, pressed);
        break;
      case DPadDirection.down:
        _sendKeyEvent(LogicalKey.s, PhysicalKey.s, pressed);
        break;
      case DPadDirection.left:
        _sendKeyEvent(LogicalKey.a, PhysicalKey.a, pressed);
        break;
      case DPadDirection.right:
        _sendKeyEvent(LogicalKey.d, PhysicalKey.d, pressed);
        break;
      case DPadDirection.none:
        break;
    }
  }

  void handleAnalogStart(Vector2 position) {
    _lastAnalogPosition = position;
  }

  void handleAnalogMove(Vector2 position) {
    if (_lastAnalogPosition == null) {
      _lastAnalogPosition = position;
      return;
    }

    final delta = (position - _lastAnalogPosition!) * mouseSensitivity;

    // Generate mouse movement event with larger delta for more rotation
    inputHandler.handle(
      MouseEvent(
        MouseEventType.move,
        null, // No button for analog stick movement
        position,
        delta * 10.0, // Scale up the delta for more noticeable rotation
      ),
    );

    _lastAnalogPosition = position;
  }

  void handleAnalogEnd() {
    _lastAnalogPosition = null;
  }

  void _sendKeyEvent(
    LogicalKey logicalKey,
    PhysicalKey physicalKey,
    bool pressed,
  ) {
    final eventType = pressed ? KeyEventType.down : KeyEventType.up;

    inputHandler.handle(
      KeyEvent(eventType, logicalKey, physicalKey, synthesized: true),
    );
  }

  void dispose() {
    // Release all D-pad keys
    for (final direction in DPadDirection.values) {
      if (direction != DPadDirection.none && _dPadStates[direction] == true) {
        handleDPadPress(direction, false);
      }
    }
    _lastAnalogPosition = null;
  }
}

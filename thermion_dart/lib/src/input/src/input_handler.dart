import 'dart:async';
import 'input_types.dart';

// An abstract interface for handling user device input events.
abstract class InputHandler {
  // Handle a single InputEvent.
  void handle(InputEvent event);

  // Destroy this instance and dispose of all resources and hooks.
  Future dispose();
}

class InputSensitivityOptions {
  final double touchSensitivity;
  final double touchScaleSensitivity;
  final double mouseSensitivity;
  final double mousePanSensitivity;
  final double keySensitivity;
  final double scrollWheelSensitivity;

  const InputSensitivityOptions({
    this.touchSensitivity = 0.001,
    this.touchScaleSensitivity = 2.0,
    this.mouseSensitivity = 0.001,
    this.mousePanSensitivity = 0.01,
    this.scrollWheelSensitivity = 0.01,
    this.keySensitivity = 0.1,
  });
}

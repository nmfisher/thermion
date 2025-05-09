import 'dart:async';
import 'input_types.dart';

///
/// An interface for handling user device input events.
///
abstract class InputHandler {
  ///
  ///
  ///
  Future? handle(InputEvent event);

  ///
  ///
  ///
  Future dispose();
}

class InputSensitivityOptions {
  final double touchSensitivity;
  final double touchScaleSensitivity;
  final double mouseSensitivity;
  final double keySensitivity;
  final double scrollWheelSensitivity;

  const InputSensitivityOptions(
      {this.touchSensitivity = 0.001,
      this.touchScaleSensitivity = 2.0,
      this.mouseSensitivity = 0.001,
      this.scrollWheelSensitivity = 0.01,
      this.keySensitivity = 0.1});
}

import 'dart:async';
import 'package:thermion_dart/thermion_dart/entities/entity_transform_controller.dart';
import 'package:flutter/services.dart';

class HardwareKeyboardPoll {
  final EntityTransformController _controller;
  late Timer _timer;
  HardwareKeyboardPoll(this._controller) {
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.keyW)) {
        _controller.forwardPressed();
      } else {
        _controller.forwardReleased();
      }

      if (RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.keyS)) {
        _controller.backPressed();
      } else {
        _controller.backReleased();
      }

      if (RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.keyA)) {
        _controller.strafeLeftPressed();
      } else {
        _controller.strafeLeftReleased();
      }

      if (RawKeyboard.instance.keysPressed.contains(LogicalKeyboardKey.keyD)) {
        _controller.strafeRightPressed();
      } else {
        _controller.strafeRightReleased();
      }
    });
  }

  void dispose() {
    _timer.cancel();
  }
}

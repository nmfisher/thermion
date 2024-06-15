import 'dart:async';
import 'dart:math';

import 'package:thermion_dart/thermion_dart/entities/filament_entity.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class EntityTransformController {
  final ThermionViewer controller;
  final ThermionEntity _entity;

  late Timer _ticker;

  double translationSpeed;
  double rotationRadsPerSecond;

  bool _forward = false;
  bool _strafeLeft = false;
  bool _strafeRight = false;
  bool _back = false;
  bool _rotateLeft = false;
  bool _rotateRight = false;
  double _rotY = 0;

  int? forwardAnimationIndex;
  int? backwardAnimationIndex;
  int? strafeLeftAnimationIndex;
  int? strafeRightAnimationIndex;

  EntityTransformController(this.controller, this._entity,
      {this.translationSpeed = 1,
      this.rotationRadsPerSecond = pi / 2,
      this.forwardAnimationIndex,
      this.backwardAnimationIndex,
      this.strafeLeftAnimationIndex,
      this.strafeRightAnimationIndex}) {
    var translationSpeedPerTick = translationSpeed / (1000 / 16.667);
    var rotationRadsPerTick = rotationRadsPerSecond / (1000 / 16.667);
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _update(translationSpeedPerTick, rotationRadsPerTick);
    });
  }

  bool _enabled = true;
  void enable() {
    _enabled = true;
  }

  void disable() {
    _enabled = false;
  }

  void _update(
      double translationSpeedPerTick, double rotationRadsPerTick) async {
    if (!_enabled) {
      return;
    }
    var _position = v.Vector3.zero();
    bool updateTranslation = false;
    if (_forward) {
      _position.add(v.Vector3(0, 0, -translationSpeedPerTick));
      updateTranslation = true;
    }
    if (_back) {
      _position.add(v.Vector3(0, 0, translationSpeedPerTick));
      updateTranslation = true;
    }
    if (_strafeLeft) {
      _position.add(v.Vector3(-translationSpeedPerTick, 0, 0));
      updateTranslation = true;
    }
    if (_strafeRight) {
      _position.add(v.Vector3(translationSpeedPerTick, 0, 0));
      updateTranslation = true;
    }

    // TODO - use pitch/yaw/roll
    bool updateRotation = false;
    var _rotation = v.Quaternion.identity();

    double rads = 0.0;
    if (_rotY != 0) {
      rads = _rotY * pi / 1000;
      var rotY = v.Quaternion.axisAngle(v.Vector3(0, 1, 0), rads).normalized();
      _rotation = rotY;
      updateRotation = true;
      _rotY = 0;
    }

    if (updateTranslation) {
      await controller.queuePositionUpdate(
          _entity, _position.x, _position.y, _position.z,
          relative: true);
    }
    if (updateRotation) {
      await controller.queueRotationUpdateQuat(_entity, _rotation,
          relative: true);
    }
  }

  void look(double deltaX) async {
    _rotY -= deltaX;
  }

  void dispose() {
    _ticker.cancel();
  }

  bool _playingForwardAnimation = false;
  bool _playingBackwardAnimation = false;

  void forwardPressed() async {
    _forward = true;
    if (forwardAnimationIndex != null && !_playingForwardAnimation) {
      await controller.playAnimation(_entity, forwardAnimationIndex!,
          loop: true, replaceActive: false);
      _playingForwardAnimation = true;
    }
  }

  void forwardReleased() async {
    _forward = false;
    await Future.delayed(Duration(milliseconds: 50));
    if (!_forward) {
      _playingForwardAnimation = false;
      if (forwardAnimationIndex != null) {
        await controller.stopAnimation(_entity, forwardAnimationIndex!);
      }
    }
  }

  void backPressed() async {
    _back = true;
    if (forwardAnimationIndex != null) {
      if (!_playingBackwardAnimation) {
        await controller.playAnimation(_entity, forwardAnimationIndex!,
            loop: true, replaceActive: false, reverse: true);
        _playingBackwardAnimation = true;
      }
    }
  }

  void backReleased() async {
    _back = false;
    if (forwardAnimationIndex != null) {
      await controller.stopAnimation(_entity, forwardAnimationIndex!);
    }
    _playingBackwardAnimation = false;
  }

  void strafeLeftPressed() {
    _strafeLeft = true;
  }

  void strafeLeftReleased() async {
    _strafeLeft = false;
  }

  void strafeRightPressed() {
    _strafeRight = true;
  }

  void strafeRightReleased() async {
    _strafeRight = false;
  }

  void Function()? _mouse1DownCallback;
  void onMouse1Down(void Function() callback) {
    _mouse1DownCallback = callback;
  }

  void mouse1Down() async {
    _mouse1DownCallback?.call();
  }

  void mouse1Up() async {}

  void mouse2Up() async {}

  void mouse2Down() async {}
}

import 'dart:async';
import 'dart:math';

import 'package:flutter_filament/filament_controller.dart';
import 'package:vector_math/vector_math_64.dart' as v;

class EntityTransformController {
  final FilamentController controller;
  final FilamentEntity _entity;

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

    // todo - better to use pitch/yaw/roll
    bool updateRotation = false;
    var _rotation = v.Quaternion.identity();

    double rads = 0.0;
    if (_rotY != 0) {
      rads = _rotY! * pi / 1000;
      var rotY = v.Quaternion.axisAngle(v.Vector3(0, 1, 0), rads).normalized();
      _rotation = rotY;
      updateRotation = true;
      _rotY = 0;
    }

    if (updateTranslation) {
      await controller.setPosition(
          _entity, _position.x, _position.y, _position.z,
          relative: true);
    }
    if (updateRotation) {
      var axis = _rotation.axis;
      await controller.setRotationQuat(_entity, _rotation, relative: true);
    }
  }

  void look(double deltaX) async {
    _rotY -= deltaX;
  }

  void dispose() {
    _ticker.cancel();
  }

  bool _playingForwardAnimation = false;

  void forwardPressed() async {
    _forward = true;
    if (forwardAnimationIndex != null) {
      if (!_playingForwardAnimation) {
        await controller.playAnimation(_entity, forwardAnimationIndex!,
            loop: true);
        _playingForwardAnimation = true;
      }
    }
  }

  Timer? _forwardTimer;
  Timer? _backwardsTimer;
  Timer? _strafeLeftTimer;
  Timer? _strafeRightTimer;

  void forwardReleased() async {
    _forwardTimer?.cancel();
    _forwardTimer = Timer(Duration(milliseconds: 50), () async {
      _forward = false;
      _playingForwardAnimation = false;
      if (forwardAnimationIndex != null) {
        await controller.stopAnimation(_entity, forwardAnimationIndex!);
      }
    });
  }

  void backPressed() {
    _back = true;
  }

  void backReleased() async {
    _backwardsTimer?.cancel();
    _backwardsTimer = Timer(Duration(milliseconds: 50), () {
      _back = false;
    });
  }

  void strafeLeftPressed() {
    _strafeLeft = true;
  }

  void strafeLeftReleased() async {
    _strafeLeftTimer?.cancel();
    _strafeLeftTimer = Timer(Duration(milliseconds: 50), () {
      _strafeLeft = false;
    });
  }

  void strafeRightPressed() {
    _strafeRight = true;
  }

  void strafeRightReleased() async {
    _strafeRightTimer?.cancel();
    _strafeRightTimer = Timer(Duration(milliseconds: 50), () {
      _strafeRight = false;
    });
  }
}

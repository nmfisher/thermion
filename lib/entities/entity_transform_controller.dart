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

  EntityTransformController(this.controller, this._entity,
      {this.translationSpeed = 1, this.rotationRadsPerSecond = pi / 2}) {
    var translationSpeedPerTick = translationSpeed / (1000 / 16.667);
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      _update(translationSpeedPerTick);
    });
  }

  void _update(double translationSpeedPerTick) async {
    var _position = v.Vector3.zero();
    var _rotation = v.Quaternion.identity();
    bool requiresUpdate = false;
    if (_forward) {
      _position.add(v.Vector3(0, 0, -translationSpeedPerTick));
      requiresUpdate = true;
    }
    if (_back) {
      _position.add(v.Vector3(0, 0, translationSpeedPerTick));
      requiresUpdate = true;
    }
    if (_strafeLeft) {
      _position.add(v.Vector3(-translationSpeedPerTick, 0, 0));
      requiresUpdate = true;
    }
    if (_strafeRight) {
      _position.add(v.Vector3(translationSpeedPerTick, 0, 0));
      requiresUpdate = true;
    }

    // todo - better to use pitch/yaw/roll
    if (_rotateLeft) {}
    if (_rotateRight) {}

    if (requiresUpdate) {
      await controller.setPosition(
          _entity, _position.x, _position.y, _position.z,
          relative: true);
    }
  }

  void dispose() {
    _ticker.cancel();
  }

  void forwardPressed() {
    print("forward");
    _forward = true;
  }

  Timer? _forwardTimer;
  Timer? _backwardsTimer;
  Timer? _strafeLeftTimer;
  Timer? _strafeRightTimer;

  void forwardReleased() async {
    _forwardTimer?.cancel();
    _forwardTimer = Timer(Duration(milliseconds: 50), () {
      _forward = false;
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

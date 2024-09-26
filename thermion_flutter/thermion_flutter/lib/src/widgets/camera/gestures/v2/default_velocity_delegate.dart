import 'dart:async';
import 'dart:ui';

import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/delegates.dart';
import 'package:vector_math/vector_math_64.dart';

class DefaultVelocityDelegate extends VelocityDelegate {
  Vector2? _velocity;
  Timer? _decelerationTimer;
  final double _decelerationFactor = 0.95;
  final double _minVelocity = 0.01;

  Vector2? get velocity => _velocity;

  @override
  void updateVelocity(Offset delta) {
    _velocity = Vector2(delta.dx, delta.dy);
  }

  @override
  void startDeceleration() {
    if (_velocity != null && _velocity!.length > _minVelocity) {
      _decelerationTimer = Timer.periodic(Duration(milliseconds: 16), (timer) {
        if (_velocity == null || _velocity!.length <= _minVelocity) {
          stopDeceleration();
          return;
        }

        _velocity = _velocity! * _decelerationFactor;

      });
    }
  }

  @override
  void stopDeceleration() {
    _decelerationTimer?.cancel();
    _decelerationTimer = null;
    _velocity = null;
  }

  @override
  void dispose() {
    stopDeceleration();
  }
}

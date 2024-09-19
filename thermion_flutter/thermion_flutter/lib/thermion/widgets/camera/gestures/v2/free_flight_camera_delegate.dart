import 'dart:async';
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/delegates.dart';
import 'package:vector_math/vector_math_64.dart';

class FreeFlightCameraDelegate implements CameraDelegate {
  final ThermionViewer viewer;
  final bool lockRoll;
  final Vector3? minBounds;
  final Vector3? maxBounds;

  final double rotationSensitivity;
  final double movementSensitivity;
  final double zoomSensitivity;
  final double panSensitivity;
  final double keyMoveSensitivity;

  static final _up = Vector3(0, 1, 0);
  static final _forward = Vector3(0, 0, -1);
  static final Vector3 _right = Vector3(1, 0, 0);

  Offset _accumulatedRotation = Offset.zero;
  Offset _accumulatedPan = Offset.zero;
  double _accumulatedZoom = 0.0;
  Vector2? _lastVelocity;

  Ticker? _ticker;
  Timer? _moveTimer;
  final Map<PhysicalKeyboardKey, bool> _pressedKeys = {};

  FreeFlightCameraDelegate(
    this.viewer, {

    this.lockRoll = false,
    this.minBounds,
    this.maxBounds,
    this.rotationSensitivity = 0.001,
    this.movementSensitivity = 0.1,
    this.zoomSensitivity = 0.1,
    this.panSensitivity = 0.01,
    this.keyMoveSensitivity = 0.1,
  }) {
    _initializeTicker();
    _startMoveLoop();
  }

  void _initializeTicker() {
    _ticker = Ticker(_onTick);
    _ticker!.start();
  }

  void _startMoveLoop() {
    _moveTimer = Timer.periodic(
        Duration(milliseconds: 16), (_) => _processKeyboardInput());
  }

  void _onTick(Duration elapsed) {
    _applyAccumulatedUpdates();
  }

  Future<void> _applyAccumulatedUpdates() async {
    if (_accumulatedRotation != Offset.zero ||
        _accumulatedPan != Offset.zero ||
        _accumulatedZoom != 0.0) {
      Matrix4 currentModelMatrix = await viewer.getCameraModelMatrix();
      Vector3 currentPosition = currentModelMatrix.getTranslation();
      Quaternion currentRotation =
          Quaternion.fromRotation(currentModelMatrix.getRotation());

      // Apply rotation
      if (_accumulatedRotation != Offset.zero) {
        double deltaX = _accumulatedRotation.dx * rotationSensitivity * viewer.pixelRatio;
        double deltaY = _accumulatedRotation.dy * rotationSensitivity * viewer.pixelRatio;
        double deltaZ = (_accumulatedRotation.dx + _accumulatedRotation.dy) * rotationSensitivity * 0.5 * viewer.pixelRatio;

        Quaternion yawRotation = Quaternion.axisAngle(_up, -deltaX);
        Quaternion pitchRotation = Quaternion.axisAngle(_right, -deltaY);
        Quaternion rollRotation = Quaternion.axisAngle(_forward, deltaZ);

        currentRotation = currentRotation * yawRotation * pitchRotation * rollRotation;
        currentRotation.normalize();

        _accumulatedRotation = Offset.zero;
      }

      // Apply pan
      if (_accumulatedPan != Offset.zero) {
        Vector3 right = _right.clone()..applyQuaternion(currentRotation);
        Vector3 up = _up.clone()..applyQuaternion(currentRotation);
        
        double deltaX = _accumulatedPan.dx * panSensitivity * viewer.pixelRatio;
        double deltaY = _accumulatedPan.dy * panSensitivity * viewer.pixelRatio;

        Vector3 newPosition = currentPosition + right * -deltaX + up * deltaY;
        newPosition = _constrainPosition(newPosition);

        currentPosition = newPosition;

        _accumulatedPan = Offset.zero;
      }

      // Apply zoom
      if (_accumulatedZoom != 0.0) {
        Vector3 forward = _forward.clone()..applyQuaternion(currentRotation);
        Vector3 newPosition = currentPosition + forward * _accumulatedZoom * zoomSensitivity;
        newPosition = _constrainPosition(newPosition);

        currentPosition = newPosition;
        _accumulatedZoom = 0.0;
      }

      Matrix4 newModelMatrix =
          Matrix4.compose(currentPosition, currentRotation, Vector3(1, 1, 1));
      await viewer.setCameraModelMatrix4(newModelMatrix);
    }
  }

  Vector3 _constrainPosition(Vector3 position) {
    if (minBounds != null) {
      position.x = position.x.clamp(minBounds!.x, double.infinity);
      position.y = position.y.clamp(minBounds!.y, double.infinity);
      position.z = position.z.clamp(minBounds!.z, double.infinity);
    }
    if (maxBounds != null) {
      position.x = position.x.clamp(double.negativeInfinity, maxBounds!.x);
      position.y = position.y.clamp(double.negativeInfinity, maxBounds!.y);
      position.z = position.z.clamp(double.negativeInfinity, maxBounds!.z);
    }
    return position;
  }

  @override
  Future<void> rotate(Offset delta, Vector2? velocity) async {
    _accumulatedRotation += delta;
    _lastVelocity = velocity;
  }

  @override
  Future<void> pan(Offset delta, Vector2? velocity) async {
    _accumulatedPan += delta;
    _lastVelocity = velocity;
  }

  @override
  Future<void> zoom(double scrollDelta, Vector2? velocity) async {
    _accumulatedZoom -= scrollDelta;
    _lastVelocity = velocity;
  }

  @override
  Future<void> onKeypress(PhysicalKeyboardKey key) async {
    _pressedKeys[key] = true;
  }
  
  @override
  Future<void> onKeyRelease(PhysicalKeyboardKey key) async {
    _pressedKeys.remove(key);
  }

  Future<void> _processKeyboardInput() async {
    double dx = 0, dy = 0, dz = 0;

    if (_pressedKeys[PhysicalKeyboardKey.keyW] == true)
      dz += keyMoveSensitivity;
    if (_pressedKeys[PhysicalKeyboardKey.keyS] == true)
      dz -= keyMoveSensitivity;
    if (_pressedKeys[PhysicalKeyboardKey.keyA] == true)
      dx -= keyMoveSensitivity;
    if (_pressedKeys[PhysicalKeyboardKey.keyD] == true)
      dx += keyMoveSensitivity;

    if (dx != 0 || dy != 0 || dz != 0) {
      await _moveCamera(dx, dy, dz);
    }
  }

  Future<void> _moveCamera(double dx, double dy, double dz) async {
    Matrix4 currentModelMatrix = await viewer.getCameraModelMatrix();
    Vector3 currentPosition = currentModelMatrix.getTranslation();
    Quaternion currentRotation =
        Quaternion.fromRotation(currentModelMatrix.getRotation());

    Vector3 forward = Vector3(0, 0, -1)..applyQuaternion(currentRotation);
    Vector3 right = Vector3(1, 0, 0)..applyQuaternion(currentRotation);
    Vector3 up = Vector3(0, 1, 0)..applyQuaternion(currentRotation);

    Vector3 moveOffset = right * dx + up * dy + forward * dz;
    Vector3 newPosition = currentPosition + moveOffset;
    newPosition = _constrainPosition(newPosition);

    Matrix4 newModelMatrix =
        Matrix4.compose(newPosition, currentRotation, Vector3(1, 1, 1));
    await viewer.setCameraModelMatrix4(newModelMatrix);
  }

  void dispose() {
    _ticker?.dispose();
    _moveTimer?.cancel();
  }
}
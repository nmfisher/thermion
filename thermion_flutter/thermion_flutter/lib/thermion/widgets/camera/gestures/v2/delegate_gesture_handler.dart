import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:logging/logging.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/default_pan_camera_delegate.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/default_velocity_delegate.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/default_zoom_camera_delegate.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/delegates.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/fixed_orbit_camera_rotation_delegate.dart';
import 'package:thermion_flutter/thermion_flutter.dart';

class DelegateGestureHandler implements ThermionGestureHandler {
  final ThermionViewer viewer;
  final Logger _logger = Logger("CustomGestureHandler");

  ThermionGestureState _currentState = ThermionGestureState.NULL;

  // Class-based delegates
  RotateCameraDelegate? rotateCameraDelegate;
  PanCameraDelegate? panCameraDelegate;
  ZoomCameraDelegate? zoomCameraDelegate;
  VelocityDelegate? velocityDelegate;

  // Timer for continuous movement
  Timer? _velocityTimer;
  static const _velocityUpdateInterval = Duration(milliseconds: 16); // ~60 FPS

  DelegateGestureHandler({
    required this.viewer,
    required this.rotateCameraDelegate,
    required this.panCameraDelegate,
    required this.zoomCameraDelegate,
    required this.velocityDelegate,
  });

  factory DelegateGestureHandler.withDefaults(ThermionViewer viewer) =>
      DelegateGestureHandler(
          viewer: viewer,
          rotateCameraDelegate: FixedOrbitRotateCameraDelegate(viewer),
          panCameraDelegate: DefaultPanCameraDelegate(viewer),
          zoomCameraDelegate: DefaultZoomCameraDelegate(viewer),
          velocityDelegate: DefaultVelocityDelegate());

  @override
  Future<void> onPointerDown(Offset localPosition, int buttons) async {
    velocityDelegate?.stopDeceleration();
    _stopVelocityTimer();
  }

  GestureType? _lastGestureType;

  @override
  Future<void> onPointerMove(
      Offset localPosition, Offset delta, int buttons) async {
    velocityDelegate?.updateVelocity(delta);

    GestureType gestureType;
    if (buttons == kPrimaryMouseButton) {
      gestureType = GestureType.POINTER1_MOVE;
    } else if (buttons == kMiddleMouseButton) {
      gestureType = GestureType.POINTER2_MOVE;
    } else {
      throw Exception("Unsupported button: $buttons");
    }

    var action = _actions[gestureType];

    switch (action) {
      case GestureAction.PAN_CAMERA:
        _currentState = ThermionGestureState.PANNING;
        await panCameraDelegate?.panCamera(delta, velocityDelegate?.velocity);
      case GestureAction.ROTATE_CAMERA:
        _currentState = ThermionGestureState.ROTATING;
        await rotateCameraDelegate?.rotateCamera(
            delta, velocityDelegate?.velocity);
      case null:
        // ignore;
        break;
      default:
        throw Exception("Unsupported gesture type : $gestureType ");
    }

    _lastGestureType = gestureType;
  }

  @override
  Future<void> onPointerUp(int buttons) async {
    _currentState = ThermionGestureState.NULL;
    velocityDelegate?.startDeceleration();
    _startVelocityTimer();
  }

  void _startVelocityTimer() {
    _stopVelocityTimer(); // Ensure any existing timer is stopped
    _velocityTimer = Timer.periodic(_velocityUpdateInterval, (timer) {
      _applyVelocity();
    });
  }

  void _stopVelocityTimer() {
    _velocityTimer?.cancel();
    _velocityTimer = null;
  }

  Future<void> _applyVelocity() async {
    final velocity = velocityDelegate?.velocity;
    if (velocity == null || velocity.length < 0.1) {
      _stopVelocityTimer();
      return;
    }

    final lastAction = _actions[_lastGestureType];
    switch (lastAction) {
      case GestureAction.PAN_CAMERA:
        await panCameraDelegate?.panCamera(
            Offset(velocity.x, velocity.y), velocity);
      case GestureAction.ROTATE_CAMERA:
        await rotateCameraDelegate?.rotateCamera(
            Offset(velocity.x, velocity.y), velocity);
      default:
        // Do nothing for other actions
        break;
    }

    velocityDelegate?.updateVelocity(Offset(velocity.x, velocity.y)); // Gradually reduce velocity
  }

  @override
  Future<void> onPointerHover(Offset localPosition) async {
    // TODO, currently noop
  }

  @override
  Future<void> onPointerScroll(Offset localPosition, double scrollDelta) async {
    if (_currentState != ThermionGestureState.NULL) {
      return;
    }

    if (_actions[GestureType.POINTER_ZOOM] != GestureAction.ZOOM_CAMERA) {
      throw Exception(
          "Unsupported action : ${_actions[GestureType.POINTER_ZOOM]}");
    }

    _currentState = ThermionGestureState.ZOOMING;

    try {
      await zoomCameraDelegate?.zoomCamera(
          scrollDelta, velocityDelegate?.velocity);
    } catch (e) {
      _logger.warning("Error during camera zoom: $e");
    } finally {
      _currentState = ThermionGestureState.NULL;
    }
  }

  @override
  void dispose() {
    _stopVelocityTimer();
    velocityDelegate?.dispose();
  }

  @override
  Future<bool> get initialized => viewer.initialized;

  @override
  Future<void> onScaleEnd() async {}

  @override
  Future<void> onScaleStart() async {}

  @override
  Future<void> onScaleUpdate() async {}

  final _actions = {
    GestureType.POINTER1_MOVE: GestureAction.PAN_CAMERA,
    GestureType.POINTER2_MOVE: GestureAction.ROTATE_CAMERA,
    GestureType.POINTER_ZOOM: GestureAction.ZOOM_CAMERA
  };

  @override
  void setActionForType(GestureType gestureType, GestureAction gestureAction) {
    _actions[gestureType] = gestureAction;
  }

  GestureAction? getActionForType(GestureType gestureType) {
    return _actions[gestureType];
  }
}

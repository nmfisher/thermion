import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:logging/logging.dart';
import 'package:thermion_flutter/thermion/widgets/camera/gestures/v2/delegates.dart';
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

  DelegateGestureHandler({
    required this.viewer,
    required this.rotateCameraDelegate,
    required this.panCameraDelegate,
    required this.zoomCameraDelegate,
    required this.velocityDelegate,
  });

  @override
  Future<void> onPointerDown(Offset localPosition, int buttons) async {
    velocityDelegate?.stopDeceleration();
  }

  @override
  Future<void> onPointerMove(
      Offset localPosition, Offset delta, int buttons) async {
    velocityDelegate?.updateVelocity(delta);

    GestureType gestureType;
    if (buttons == kPrimaryMouseButton) {
      gestureType = GestureType.POINTER1_MOVE;
    } else if (buttons == kSecondaryMouseButton) {
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
        await rotateCameraDelegate?.rotateCamera(delta, velocityDelegate?.velocity);
      case null:
        // ignore;
        break;
      default:
        throw Exception("Unsupported gesture type : $gestureType ");
    }
  }

  @override
  Future<void> onPointerUp(int buttons) async {
    _currentState = ThermionGestureState.NULL;
    velocityDelegate?.startDeceleration();
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
      await zoomCameraDelegate?.zoomCamera(scrollDelta, velocityDelegate?.velocity);
    } catch (e) {
      _logger.warning("Error during camera zoom: $e");
    } finally {
      _currentState = ThermionGestureState.NULL;
    }
  }

  @override
  void dispose() {
    // Clean up any resources if needed
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

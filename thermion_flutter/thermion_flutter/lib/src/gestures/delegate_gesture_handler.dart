import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:thermion_flutter/src/gestures/default_pick_delegate.dart';
import 'package:thermion_flutter/src/gestures/default_velocity_delegate.dart';
import 'package:thermion_flutter/src/gestures/delegates.dart';
import 'package:thermion_flutter/src/gestures/fixed_orbit_camera_rotation_delegate.dart';
import 'package:thermion_flutter/src/gestures/free_flight_camera_delegate.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:vector_math/vector_math_64.dart';

class DelegateGestureHandler implements ThermionGestureHandler {
  final ThermionViewer viewer;
  final Logger _logger = Logger("CustomGestureHandler");

  CameraDelegate? cameraDelegate;
  VelocityDelegate? velocityDelegate;
  PickDelegate? pickDelegate;

  Ticker? _ticker;

  Map<GestureType, Offset> _accumulatedDeltas = {};
  double _accumulatedScrollDelta = 0.0;
  int _activePointers = 0;
  bool _isMiddleMouseButtonPressed = false;

  VoidCallback? _keyboardListenerDisposer;

  final Map<GestureType, GestureAction> _actions = {
    GestureType.LMB_HOLD_AND_MOVE: GestureAction.PAN_CAMERA,
    GestureType.MMB_HOLD_AND_MOVE: GestureAction.ROTATE_CAMERA,
    GestureType.SCROLLWHEEL: GestureAction.ZOOM_CAMERA,
    GestureType.POINTER_MOVE: GestureAction.NONE,
  };

  DelegateGestureHandler({
    required this.viewer,
    required this.cameraDelegate,
    required this.velocityDelegate,
    this.pickDelegate,
    Map<GestureType, GestureAction>? actions,
  }) {
    _initializeKeyboardListener();
    if (actions != null) {
      _actions.addAll(actions);
    }
    _initializeAccumulatedDeltas();
  }

  factory DelegateGestureHandler.fixedOrbit(ThermionViewer viewer,
          {double minimumDistance = 10.0,
          double? Function(Vector3)? getDistanceToTarget,
          PickDelegate? pickDelegate}) =>
      DelegateGestureHandler(
        viewer: viewer,
        pickDelegate: pickDelegate,
        cameraDelegate: FixedOrbitRotateCameraDelegate(viewer,
            getDistanceToTarget: getDistanceToTarget,
            minimumDistance: minimumDistance),
        velocityDelegate: DefaultVelocityDelegate(),
        actions: {GestureType.MMB_HOLD_AND_MOVE:GestureAction.ROTATE_CAMERA}
      );

  factory DelegateGestureHandler.flight(ThermionViewer viewer,
          {PickDelegate? pickDelegate}) =>
      DelegateGestureHandler(
        viewer: viewer,
        pickDelegate: pickDelegate,
        cameraDelegate: FreeFlightCameraDelegate(viewer),
        velocityDelegate: DefaultVelocityDelegate(),
        actions: {GestureType.POINTER_MOVE: GestureAction.ROTATE_CAMERA},
      );

  void _initializeAccumulatedDeltas() {
    for (var gestureType in GestureType.values) {
      _accumulatedDeltas[gestureType] = Offset.zero;
    }
  }

  Future<void> _applyAccumulatedUpdates() async {
    for (var gestureType in GestureType.values) {
      Offset delta = _accumulatedDeltas[gestureType] ?? Offset.zero;
      if (delta != Offset.zero) {
        velocityDelegate?.updateVelocity(delta);

        var action = _actions[gestureType];
        switch (action) {
          case GestureAction.PAN_CAMERA:
            await cameraDelegate?.pan(delta, velocityDelegate?.velocity);
            break;
          case GestureAction.ROTATE_CAMERA:
            await cameraDelegate?.rotate(delta, velocityDelegate?.velocity);
            break;
          case GestureAction.NONE:
            // Do nothing
            break;
          default:
            _logger.warning(
                "Unsupported gesture action: $action for type: $gestureType");
            break;
        }

        _accumulatedDeltas[gestureType] = Offset.zero;
      }
    }

    if (_accumulatedScrollDelta != 0.0) {
      await cameraDelegate?.zoom(
          _accumulatedScrollDelta, velocityDelegate?.velocity);
      _accumulatedScrollDelta = 0.0;
    }
  }

  @override
  Future<void> onPointerDown(Offset localPosition, int buttons) async {
    velocityDelegate?.stopDeceleration();
    _activePointers++;
    if (buttons & kMiddleMouseButton != 0) {
      _isMiddleMouseButtonPressed = true;
    }
    if (buttons & kPrimaryButton != 0) {
      final action = _actions[GestureType.LMB_DOWN];
      switch (action) {
        case GestureAction.PICK_ENTITY:
          pickDelegate?.pick(localPosition);
        default:
        // noop
      }
    }
    await _applyAccumulatedUpdates();
  }

  @override
  Future<void> onPointerMove(
      Offset localPosition, Offset delta, int buttons) async {
    GestureType gestureType = _getGestureTypeFromButtons(buttons);
    if (gestureType == GestureType.MMB_HOLD_AND_MOVE ||
        (_actions[GestureType.POINTER_MOVE] == GestureAction.ROTATE_CAMERA &&
            gestureType == GestureType.POINTER_MOVE)) {
      _accumulatedDeltas[GestureType.MMB_HOLD_AND_MOVE] =
          (_accumulatedDeltas[GestureType.MMB_HOLD_AND_MOVE] ?? Offset.zero) +
              delta;
    } else {
      _accumulatedDeltas[gestureType] =
          (_accumulatedDeltas[gestureType] ?? Offset.zero) + delta;
    }
    await _applyAccumulatedUpdates();
  }

  @override
  Future<void> onPointerUp(int buttons) async {
    _activePointers--;
    if (_activePointers == 0) {
      velocityDelegate?.startDeceleration();
    }
    if (buttons & kMiddleMouseButton != 0) {
      _isMiddleMouseButtonPressed = false;
    }
  }

  GestureType _getGestureTypeFromButtons(int buttons) {
    if (buttons & kPrimaryMouseButton != 0) {
      return GestureType.LMB_HOLD_AND_MOVE;
    }
    if (buttons & kMiddleMouseButton != 0 || _isMiddleMouseButtonPressed) {
      return GestureType.MMB_HOLD_AND_MOVE;
    }
    return GestureType.POINTER_MOVE;
  }

  @override
  Future<void> onPointerHover(Offset localPosition, Offset delta) async {
    if (_actions[GestureType.POINTER_MOVE] == GestureAction.ROTATE_CAMERA) {
      _accumulatedDeltas[GestureType.POINTER_MOVE] =
          (_accumulatedDeltas[GestureType.POINTER_MOVE] ?? Offset.zero) + delta;
    }
  }

  @override
  Future<void> onPointerScroll(Offset localPosition, double scrollDelta) async {
    if (_actions[GestureType.SCROLLWHEEL] != GestureAction.ZOOM_CAMERA) {
      throw Exception(
          "Unsupported action: ${_actions[GestureType.SCROLLWHEEL]}");
    }

    try {
      _accumulatedScrollDelta += scrollDelta;
    } catch (e) {
      _logger.warning("Error during scroll accumulation: $e");
    }
    await _applyAccumulatedUpdates();
  }

  @override
  void dispose() {
    velocityDelegate?.dispose();
    _keyboardListenerDisposer?.call();
    _ticker?.dispose();
  }

  @override
  Future<bool> get initialized => viewer.initialized;

  @override
  Future<void> onScaleEnd() async {}

  @override
  Future<void> onScaleStart() async {}

  @override
  Future<void> onScaleUpdate() async {}

  @override
  void setActionForType(GestureType gestureType, GestureAction gestureAction) {
    _actions[gestureType] = gestureAction;
  }

  @override
  GestureAction? getActionForType(GestureType gestureType) {
    return _actions[gestureType];
  }

  void _initializeKeyboardListener() {
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _keyboardListenerDisposer = () {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    };
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (_actions[GestureType.KEYDOWN] == GestureAction.NONE) {
      return false;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      cameraDelegate?.onKeypress(event.physicalKey);
      return true;
    } else if (event is KeyUpEvent) {
      cameraDelegate?.onKeyRelease(event.physicalKey);
      return true;
    }
    return false;
  }
}

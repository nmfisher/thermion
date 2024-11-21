import 'dart:async';
import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';

import 'implementations/fixed_orbit_camera_rotation_delegate.dart';
import 'implementations/free_flight_camera_delegate.dart';

class DelegateInputHandler implements InputHandler {
  final ThermionViewer viewer;

  Stream<List<InputType>> get gestures => _gesturesController.stream;
  final _gesturesController = StreamController<List<InputType>>.broadcast();

  Stream get cameraUpdated => _cameraUpdatedController.stream;
  final _cameraUpdatedController = StreamController.broadcast();

  final _logger = Logger("DelegateInputHandler");

  InputHandlerDelegate? transformDelegate;
  PickDelegate? pickDelegate;

  final Set<PhysicalKey> _pressedKeys = {};

  final _inputDeltas = <InputType, Vector3>{};

  Map<InputType, InputAction> _actions = {
    InputType.LMB_HOLD_AND_MOVE: InputAction.TRANSLATE,
    InputType.SCALE1: InputAction.TRANSLATE,
    InputType.SCALE2: InputAction.ZOOM,
    InputType.MMB_HOLD_AND_MOVE: InputAction.ROTATE,
    InputType.SCROLLWHEEL: InputAction.TRANSLATE,
    InputType.POINTER_MOVE: InputAction.NONE,
    InputType.KEYDOWN_W: InputAction.TRANSLATE,
    InputType.KEYDOWN_S: InputAction.TRANSLATE,
    InputType.KEYDOWN_A: InputAction.TRANSLATE,
    InputType.KEYDOWN_D: InputAction.TRANSLATE,
  };

  final _axes = <InputType, Matrix3>{};

  void setTransformForAction(InputType inputType, Matrix3 transform) {
    _axes[inputType] = transform;
  }

  DelegateInputHandler({
    required this.viewer,
    required this.transformDelegate,
    this.pickDelegate,
    Map<InputType, InputAction>? actions,
  }) {
    if (actions != null) {
      _actions = actions;
    }

    if (pickDelegate != null) {
      if (_actions[InputType.LMB_DOWN] != null) {
        throw Exception();
      }
      _actions[InputType.LMB_DOWN] = InputAction.PICK;
    }

    for (var gestureType in InputType.values) {
      _inputDeltas[gestureType] = Vector3.zero();
    }

    viewer.registerRequestFrameHook(process);
  }

  factory DelegateInputHandler.fixedOrbit(ThermionViewer viewer,
          {double minimumDistance = 10.0,
          Vector3? target,
          ThermionEntity? entity,
          PickDelegate? pickDelegate}) =>
      DelegateInputHandler(
          viewer: viewer,
          pickDelegate: pickDelegate,
          transformDelegate: FixedOrbitRotateInputHandlerDelegate(viewer,
              minimumDistance: minimumDistance),
          actions: {
            InputType.MMB_HOLD_AND_MOVE: InputAction.ROTATE,
            InputType.SCALE1: InputAction.ROTATE,
            InputType.SCALE2: InputAction.ZOOM,
            InputType.SCROLLWHEEL: InputAction.ZOOM
          });

  factory DelegateInputHandler.flight(ThermionViewer viewer,
          {PickDelegate? pickDelegate,
          bool freeLook = false,
          double panSensitivity = 0.1,
          double zoomSensitivity = 0.1,
          double movementSensitivity = 0.1,
          double rotateSensitivity = 0.01,
          double? clampY,
          ThermionEntity? entity}) =>
      DelegateInputHandler(
          viewer: viewer,
          pickDelegate: pickDelegate,
          transformDelegate: FreeFlightInputHandlerDelegate(viewer,
              clampY: clampY,
              entity: entity,
              rotationSensitivity: rotateSensitivity,
              zoomSensitivity: zoomSensitivity,
              panSensitivity: panSensitivity,
              movementSensitivity: movementSensitivity),
          actions: {
            InputType.MMB_HOLD_AND_MOVE: InputAction.ROTATE,
            InputType.SCROLLWHEEL: InputAction.ZOOM,
            InputType.LMB_HOLD_AND_MOVE: InputAction.TRANSLATE,
            InputType.KEYDOWN_A: InputAction.TRANSLATE,
            InputType.KEYDOWN_W: InputAction.TRANSLATE,
            InputType.KEYDOWN_S: InputAction.TRANSLATE,
            InputType.KEYDOWN_D: InputAction.TRANSLATE,
            InputType.SCALE1: InputAction.TRANSLATE,
            InputType.SCALE2: InputAction.ZOOM,
            if (freeLook) InputType.POINTER_MOVE: InputAction.ROTATE,
          });

  bool _processing = false;
  Future<void> process() async {
    _processing = true;
    for (var gestureType in _inputDeltas.keys) {
      var vector = _inputDeltas[gestureType]!;
      var action = _actions[gestureType];
      if (action == null) {
        continue;
      }
      final transform = _axes[gestureType];
      if (transform != null) {
        vector = transform * vector;
      }

      await transformDelegate?.queue(action, vector);
    }
    final keyTypes = <InputType>[];
    for (final key in _pressedKeys) {
      InputAction? keyAction;
      InputType? keyType = null;
      Vector3? vector;

      switch (key) {
        case PhysicalKey.W:
          keyType = InputType.KEYDOWN_W;
          vector = Vector3(0, 0, -1);
          break;
        case PhysicalKey.A:
          keyType = InputType.KEYDOWN_A;
          vector = Vector3(-1, 0, 0);
          break;
        case PhysicalKey.S:
          keyType = InputType.KEYDOWN_S;
          vector = Vector3(0, 0, 1);
          break;
        case PhysicalKey.D:
          keyType = InputType.KEYDOWN_D;
          vector = Vector3(1, 0, 0);
          break;
      }

      // ignore: unnecessary_null_comparison
      if (keyType != null) {
        keyAction = _actions[keyType];

        if (keyAction != null) {
          var transform = _axes[keyAction];
          if (transform != null) {
            vector = transform * vector;
          }
          transformDelegate?.queue(keyAction, vector!);
          keyTypes.add(keyType);
        }
      }
    }

    await transformDelegate?.execute();
    var updates = _inputDeltas.keys.followedBy(keyTypes).toList();
    if (updates.isNotEmpty) {
      _gesturesController.add(updates);
      _cameraUpdatedController.add(true);
    }

    _inputDeltas.clear();
    _processing = false;
  }

  @override
  Future<void> onPointerDown(Vector2 localPosition, bool isMiddle) async {
    if (!isMiddle) {
      final action = _actions[InputType.LMB_DOWN];
      switch (action) {
        case InputAction.PICK:
          pickDelegate?.pick(localPosition);
        default:
        // noop
      }
    }
  }

  @override
  Future<void> onPointerMove(
      Vector2 localPosition, Vector2 delta, bool isMiddle) async {
    if (_processing) {
      return;
    }
    if (isMiddle) {
      _inputDeltas[InputType.MMB_HOLD_AND_MOVE] =
          (_inputDeltas[InputType.MMB_HOLD_AND_MOVE] ?? Vector3.zero()) +
              Vector3(delta.x, delta.y, 0.0);
    } else {
      _inputDeltas[InputType.LMB_HOLD_AND_MOVE] =
          (_inputDeltas[InputType.LMB_HOLD_AND_MOVE] ?? Vector3.zero()) +
              Vector3(delta.x, delta.y, 0.0);
    }
  }

  @override
  Future<void> onPointerUp(bool isMiddle) async {}

  @override
  Future<void> onPointerHover(Vector2 localPosition, Vector2 delta) async {
    if (_processing) {
      return;
    }
    _inputDeltas[InputType.POINTER_MOVE] =
        (_inputDeltas[InputType.POINTER_MOVE] ?? Vector3.zero()) +
            Vector3(delta.x, delta.y, 0.0);
  }

  @override
  Future<void> onPointerScroll(
      Vector2 localPosition, double scrollDelta) async {
    if (_processing) {
      return;
    }
    try {
      _inputDeltas[InputType.SCROLLWHEEL] =
          (_inputDeltas[InputType.SCROLLWHEEL] ?? Vector3.zero()) +
              Vector3(0, 0, scrollDelta > 0 ? 1 : -1);
    } catch (e) {
      _logger.warning("Error during scroll accumulation: $e");
    }
  }

  @override
  Future dispose() async {
    viewer.unregisterRequestFrameHook(process);
  }

  @override
  Future<bool> get initialized => viewer.initialized;

  @override
  void setActionForType(InputType gestureType, InputAction gestureAction) {
    _actions[gestureType] = gestureAction;
  }

  @override
  InputAction? getActionForType(InputType gestureType) {
    return _actions[gestureType];
  }

  void keyDown(PhysicalKey key) {
    _pressedKeys.add(key);
  }

  void keyUp(PhysicalKey key) {
    _pressedKeys.remove(key);
  }

  @override
  Future<void> onScaleEnd(int pointerCount, double velocity) async {}

  @override
  Future<void> onScaleStart(Vector2 localPosition, int pointerCount,
      Duration? sourceTimestamp) async {
    // noop
  }

  double? _lastScale;

  @override
  Future<void> onScaleUpdate(
      Vector2 focalPoint,
      Vector2 focalPointDelta,
      double horizontalScale,
      double verticalScale,
      double scale,
      int pointerCount,
      double rotation,
      Duration? sourceTimestamp) async {
    if (pointerCount == 1) {
      _inputDeltas[InputType.SCALE1] =
          Vector3(focalPointDelta.x, focalPointDelta.y, 0);
    } else if (pointerCount == 2) {
      var zoomDelta = 0.0;
      if (_lastScale == null) {
        if (scale < 0) {
          zoomDelta = 1;
        } else if (scale > 0) {
          zoomDelta = -1;
        }
        _lastScale = scale;
      } else {
        zoomDelta = scale < _lastScale! ? 1 : -1;
        _lastScale = scale;
      }

      _inputDeltas[InputType.SCALE2] = Vector3(0, 0, zoomDelta);
    } else {
      throw UnimplementedError("Only pointerCount <= 2 supported");
    }
  }
}

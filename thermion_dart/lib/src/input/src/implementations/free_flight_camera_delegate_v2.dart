import 'dart:async';
import 'package:vector_math/vector_math_64.dart';
import '../../../viewer/viewer.dart';
import '../../input.dart';

/// Free-flight camera delegate.
///
/// Input events only accumulate deltas synchronously (no FFI traffic); the
/// combined camera update is applied once per frame from a request-frame
/// hook, with keyboard motion scaled by the frame delta. This keeps
/// high-rate pointers (240-1000 Hz) from issuing a camera read-modify-write
/// per event and makes WASD speed independent of the display frame rate.
class FreeFlightInputHandlerDelegateV2 extends InputHandlerDelegate {
  final View view;
  final FilamentApp app;
  final InputSensitivityOptions sensitivity;
  final bool moveOnHover;

  final _heldKeys = <PhysicalKey>{};
  late final RequestFrameHook _onFrame;

  /// Pointer rotation (radians) accumulated since the last applied frame.
  Vector2 _accumulatedRotation = Vector2.zero();

  /// Translation accumulated from scroll/touch since the last applied frame.
  Vector3 _accumulatedTranslation = Vector3.zero();

  double? _scaleDelta;

  /// Accumulated two-finger pinch (sum of per-event scale deltas) since the
  /// last applied frame. Converted to a z translation in the frame hook
  /// against the camera distance, matching the old per-event formula but
  /// sampled once per frame.
  double _accumulatedScaleDelta = 0;

  /// Cached camera handle; [View.getCamera] is a synchronous FFI call that
  /// returns the same underlying camera for the view's lifetime.
  Camera? _camera;

  FreeFlightInputHandlerDelegateV2(
    this.view,
    this.app, {
    this.sensitivity = const InputSensitivityOptions(),
    this.moveOnHover = false,
  }) {
    _onFrame = _handleFrame;
    app.registerRequestFrameHook(_onFrame);
  }

  Future<void> _handleFrame(int frameTimeNanos, Duration delta) async {
    var translation = Vector3.zero();

    // Scale keyboard motion by elapsed time, normalized to a 60 fps frame so
    // existing keySensitivity values keep their tuned speed at 60 Hz while
    // higher/lower refresh rates no longer change it.
    final frameScale = delta.inMicroseconds / (1000 * 1000) * 60.0;
    for (final key in _heldKeys) {
      switch (key) {
        case PhysicalKey.w:
          translation += Vector3(0, 0, -sensitivity.keySensitivity);
        case PhysicalKey.s:
          translation += Vector3(0, 0, sensitivity.keySensitivity);
        case PhysicalKey.a:
          translation += Vector3(-sensitivity.keySensitivity, 0, 0);
        case PhysicalKey.d:
          translation += Vector3(sensitivity.keySensitivity, 0, 0);
        default:
          break;
      }
    }
    if (frameScale > 0 && translation.length2 > 0) {
      translation.scale(frameScale);
    }

    final rotation = _accumulatedRotation;
    final pointerTranslation = _accumulatedTranslation;
    _accumulatedRotation = Vector2.zero();
    _accumulatedTranslation = Vector3.zero();

    if (rotation.length2 + pointerTranslation.length2 + translation.length2 == 0.0 && _accumulatedScaleDelta == 0) {
      return;
    }

    try {
      final camera = _camera ??= await view.getCamera();
      final current = await camera.getModelMatrix();
      var zoomTranslation = Vector3.zero();
      if (_accumulatedScaleDelta != 0) {
        zoomTranslation = Vector3(0, 0, _accumulatedScaleDelta * current.getTranslation().length.abs());
      }
      _accumulatedScaleDelta = 0;
      final updated =
          current *
          Matrix4.compose(
            translation + pointerTranslation + zoomTranslation,
            Quaternion.axisAngle(Vector3(0, 1, 0), rotation.x) * Quaternion.axisAngle(Vector3(1, 0, 0), rotation.y),
            Vector3.all(1),
          );
      await camera.setModelMatrix(updated);
    } catch (_) {
      // Camera may have been disposed.
      _camera = null;
    }
  }

  @override
  Future<void> handle(List<InputEvent> events) async {
    // Synchronous accumulation only: applying camera updates here would do a
    // read-modify-write per input event (up to 8-16 times per frame with a
    // high-rate mouse) and race the per-frame application.
    for (final event in events) {
      switch (event) {
        case ScrollEvent(delta: final delta):
          _accumulatedTranslation.z += sensitivity.scrollWheelSensitivity * delta;
        case MouseEvent(type: final type, button: _, localPosition: _, delta: final delta):
          switch (type) {
            case MouseEventType.hover:
              if (!moveOnHover) {
                continue;
              }
              _accumulatedRotation += delta.scaled(sensitivity.mouseSensitivity);
            case MouseEventType.move:
              _accumulatedRotation += delta.scaled(sensitivity.mouseSensitivity);
            default:
              break;
          }
        case TouchEvent(type: final type, delta: _):
          switch (type) {
            case TouchEventType.tap:
            case TouchEventType.doubleTap:
              break;
          }
        case ScaleStartEvent(numPointers: _):
          _scaleDelta = 1;
        case ScaleUpdateEvent(
          numPointers: final numPointers,
          localFocalPoint: _,
          localFocalPointDelta: final localFocalPointDelta,
          scale: final scale,
        ):
          if (numPointers == 1) {
            _accumulatedTranslation += Vector3(
              localFocalPointDelta!.$1 * sensitivity.touchSensitivity,
              localFocalPointDelta.$2 * sensitivity.touchSensitivity,
              0,
            );
          } else {
            _accumulatedScaleDelta += (_scaleDelta! - scale) * sensitivity.touchScaleSensitivity;
            _scaleDelta = scale;
          }
        case ScaleEndEvent(numPointers: _):
          break;
        case KeyEvent(type: final type, logicalKey: _, physicalKey: var physicalKey):
          switch (type) {
            case KeyEventType.down:
              _heldKeys.add(physicalKey);
            case KeyEventType.up:
              _heldKeys.remove(physicalKey);
          }
      }
    }
  }

  @override
  Future dispose() async {
    await app.unregisterRequestFrameHook(_onFrame);
    _heldKeys.clear();
    _camera = null;
  }
}

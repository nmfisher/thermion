import 'dart:async';
import 'package:vector_math/vector_math_64.dart';
import '../../../viewer/viewer.dart';
import '../../input.dart';

class FreeFlightInputHandlerDelegateV2 extends InputHandlerDelegate {
  final View view;
  final FilamentApp app;
  final InputSensitivityOptions sensitivity;
  final bool moveOnHover;

  final _heldKeys = <PhysicalKey>{};
  late final Future<void> Function() _onFrame;

  FreeFlightInputHandlerDelegateV2(
    this.view,
    this.app, {
    this.sensitivity = const InputSensitivityOptions(),
    this.moveOnHover = false,
  }) {
    _onFrame = _handleFrame;
    app.registerRequestFrameHook(_onFrame);
  }

  Future<void> _handleFrame() async {
    if (_heldKeys.isEmpty) return;

    Vector3 translation = Vector3.zero();
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

    if (translation.length2 > 0) {
      try {
        final camera = await view.getCamera();
        final current = await camera.getModelMatrix();
        final updated = current * Matrix4.compose(translation, Quaternion.identity(), Vector3.all(1));
        await camera.setModelMatrix(updated);
      } catch (_) {
        // Camera may have been disposed
      }
    }
  }

  double? _scaleDelta;

  @override
  Future<void> handle(List<InputEvent> events) async {
    Vector2 rotation = Vector2.zero();
    Vector3 translation = Vector3.zero();

    final activeCamera = await view.getCamera();

    Matrix4 current = await activeCamera.getModelMatrix();

    for (final event in events) {
      switch (event) {
        case ScrollEvent(delta: final delta):
          translation += Vector3(0, 0, sensitivity.scrollWheelSensitivity * delta);
        case MouseEvent(type: final type, button: _, localPosition: _, delta: final delta):
          switch (type) {
            case MouseEventType.hover:
              if (!moveOnHover) {
                continue;
              }
              rotation += delta.scaled(sensitivity.mouseSensitivity);
            case MouseEventType.move:
              rotation += delta.scaled(sensitivity.mouseSensitivity);
            default:
              break;
          }
          break;
        case TouchEvent(type: final type, delta: _):
          switch (type) {
            // case TouchEventType.move:
            //   rotation += delta!;
            case TouchEventType.tap:
            case TouchEventType.doubleTap:
              break;
          }
          break;
        case ScaleStartEvent(numPointers: _):
          _scaleDelta = 1;
          break;
        case ScaleUpdateEvent(
          numPointers: final numPointers,
          localFocalPoint: _,
          localFocalPointDelta: final localFocalPointDelta,
          scale: final scale,
        ):
          if (numPointers == 1) {
            translation += Vector3(
              localFocalPointDelta!.$1 * sensitivity.touchSensitivity,
              localFocalPointDelta.$2 * sensitivity.touchSensitivity,
              0,
            );
          } else {
            translation = Vector3(
              0,
              0,
              (_scaleDelta! - scale) * sensitivity.touchScaleSensitivity * current.getTranslation().length.abs(),
            );
            _scaleDelta = scale;
          }
          break;
        case ScaleEndEvent(numPointers: _):
          break;
        case KeyEvent(type: final type, logicalKey: _, physicalKey: var physicalKey):
          switch (type) {
            case KeyEventType.down:
              _heldKeys.add(physicalKey);
            case KeyEventType.up:
              _heldKeys.remove(physicalKey);
          }
          break;
      }
    }

    if (rotation.length2 + translation.length2 == 0.0) {
      return;
    }

    var updated =
        current *
        Matrix4.compose(
          translation,
          Quaternion.axisAngle(Vector3(0, 1, 0), rotation.x) * Quaternion.axisAngle(Vector3(1, 0, 0), rotation.y),
          Vector3.all(1),
        );

    await activeCamera.setModelMatrix(updated);

    return updated;
  }

  @override
  Future dispose() async {
    await app.unregisterRequestFrameHook(_onFrame);
    _heldKeys.clear();
  }
}

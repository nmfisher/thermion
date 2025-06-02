import 'dart:async';
import 'package:vector_math/vector_math_64.dart';
import '../../../viewer/viewer.dart';
import '../../input.dart';

class FreeFlightInputHandlerDelegateV2 extends InputHandlerDelegate {
  final View view;

  final InputSensitivityOptions sensitivity;

  FreeFlightInputHandlerDelegateV2(this.view,
      {this.sensitivity = const InputSensitivityOptions()});

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
          translation +=
              Vector3(0, 0, sensitivity.scrollWheelSensitivity * delta);
        case MouseEvent(
            type: final type,
            button: final button,
            localPosition: final localPosition,
            delta: final delta
          ):
          switch (type) {
            case MouseEventType.hover:
            case MouseEventType.move:
              rotation += delta.scaled(sensitivity.mouseSensitivity);
            default:
              break;
          }
          break;
        case TouchEvent(type: final type, delta: final delta):
          switch (type) {
            // case TouchEventType.move:
            //   rotation += delta!;
            case TouchEventType.tap:
            case TouchEventType.doubleTap:
              break;
          }
          break;
        case ScaleStartEvent(numPointers: final numPointers):
          _scaleDelta = 1;
          break;
        case ScaleUpdateEvent(
            numPointers: final numPointers,
            localFocalPoint: final localFocalPoint,
            localFocalPointDelta: final localFocalPointDelta,
            scale: final scale,
          ):
          if (numPointers == 1) {
            translation +=
                Vector3(localFocalPointDelta!.$1 * sensitivity.touchSensitivity, localFocalPointDelta!.$2 * sensitivity.touchSensitivity, 0);
          } else {
            translation = Vector3(0,0, (_scaleDelta! - scale) * sensitivity.touchScaleSensitivity * current.getTranslation().length.abs() );
            _scaleDelta = scale;
          }
          break;
        case ScaleEndEvent(numPointers: final numPointers):
          break;
        case KeyEvent(type: final type, logicalKey: var logicalKey, physicalKey: var physicalKey  ):
          switch (physicalKey) {
            case PhysicalKey.a:
              translation += Vector3(
                -sensitivity.keySensitivity,
                0,
                0,
              );
              break;
            case PhysicalKey.s:
              translation += Vector3(0, 0, sensitivity.keySensitivity);
              break;
            case PhysicalKey.d:
              translation += Vector3(
                sensitivity.keySensitivity,
                0,
                0,
              );
              break;
            case PhysicalKey.w:
              translation += Vector3(
                0,
                0,
                -sensitivity.keySensitivity,
              );
              break;
            default:
          }
          break;
      }
    }

    if (rotation.length2 + translation.length2 == 0.0) {
      return;
    }

    var updated = current *
        Matrix4.compose(
            translation,
            Quaternion.axisAngle(Vector3(0, 1, 0), rotation.x) *
                Quaternion.axisAngle(Vector3(1, 0, 0), rotation.y),
            Vector3.all(1));

    await activeCamera.setModelMatrix(updated);

    return updated;
  }
}

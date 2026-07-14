import 'dart:async';
import 'package:thermion_dart/src/input/src/implementations/fixed_orbit_camera_delegate_v2.dart';
import 'package:thermion_dart/src/input/src/implementations/free_flight_camera_delegate_v2.dart';
import 'package:thermion_dart/thermion_dart.dart';

typedef PointerEventDetails = (Vector2 localPosition, Vector2 delta);

abstract class InputHandlerDelegate {
  Future handle(List<InputEvent> events) async {
    // noop, override to implement
  }

  // Whether this delegate has consumed the most recent batch of events.
  // When true, [ChainedDelegate] will stop propagating to subsequent delegates.
  bool get consumesEvents => false;

  Future dispose() async {
    // noop, override if you need
  }
}

///
/// An [InputHandler] that delegates input events to an [InputHandlerDelegate].
/// Events are processed immediately without batching.
///
class DelegateInputHandler implements InputHandler {
  final ThermionViewer viewer;
  InputHandlerDelegate? delegate;

  DelegateInputHandler({
    required this.viewer,
    this.delegate,
  });

  factory DelegateInputHandler.fixedOrbit(ThermionViewer viewer,
      {double minimumDistance = 0.1,
      Vector3? target,
      InputSensitivityOptions sensitivity = const InputSensitivityOptions(),
      bool moveOnHover = false}) {
    return DelegateInputHandler(
        viewer: viewer,
        delegate: OrbitInputHandlerDelegate(
          viewer.view,
          moveOnHover: moveOnHover,
          sensitivity: sensitivity,
          minZoomDistance: minimumDistance,
          maxZoomDistance: 1000.0,
        ));
  }

  factory DelegateInputHandler.flight(
    ThermionViewer viewer, {
    bool freeLook = false,
    bool moveOnHover = false,
    InputSensitivityOptions sensitivity = const InputSensitivityOptions(),
  }) =>
      DelegateInputHandler(
        viewer: viewer,
        delegate: FreeFlightInputHandlerDelegateV2(viewer.view,
            sensitivity: sensitivity, moveOnHover: moveOnHover),
      );

  @override
  Future dispose() async {
    await delegate?.dispose();
  }

  @override
  Future handle(InputEvent event) async {
    if (delegate == null) return;
    await delegate!.handle([event]);
  }
}

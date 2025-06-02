import 'dart:async';
import 'package:logging/logging.dart';
import 'package:thermion_dart/src/input/src/implementations/fixed_orbit_camera_delegate_v2.dart';
import 'package:thermion_dart/src/input/src/implementations/free_flight_camera_delegate_v2.dart';
import 'package:thermion_dart/thermion_dart.dart';

typedef PointerEventDetails = (Vector2 localPosition, Vector2 delta);

abstract class InputHandlerDelegate {
  Future handle(List<InputEvent> events);
}

///
/// An [InputHandler] that accumulates pointer/key events every frame,
/// delegating the actual update to an [InputHandlerDelegate].
///
class DelegateInputHandler implements InputHandler {
  final ThermionViewer viewer;

  late final _logger = Logger(this.runtimeType.toString());

  Stream<List<InputEvent>> get events => _gesturesController.stream;

  final _gesturesController = StreamController<List<InputEvent>>.broadcast();
  final _events = <InputEvent>[];
  final List<InputHandlerDelegate> delegates;

  final bool batch;

  bool _ready = false;
  bool _processing = false;

  DelegateInputHandler(
      {required this.viewer, required this.delegates, this.batch = true}) {
    FilamentApp.instance!.registerRequestFrameHook(process);
    viewer.initialized.then((_) {
      this._ready = true;
    });
  }

  factory DelegateInputHandler.fixedOrbit(ThermionViewer viewer,
      {double minimumDistance = 0.1,
      Vector3? target,
      InputSensitivityOptions sensitivity = const InputSensitivityOptions(),
      ThermionEntity? entity}) {
    return DelegateInputHandler(viewer: viewer, delegates: [
      OrbitInputHandlerDelegate(viewer.view,
          sensitivity: sensitivity,
          minZoomDistance: minimumDistance,
          maxZoomDistance: 1000.0)
    ]);
  }

  factory DelegateInputHandler.flight(ThermionViewer viewer,
          {bool freeLook = false,
          InputSensitivityOptions sensitivity = const InputSensitivityOptions(),
          ThermionEntity? entity}) =>
      DelegateInputHandler(viewer: viewer, delegates: [
        FreeFlightInputHandlerDelegateV2(viewer.view, sensitivity: sensitivity)
      ]);

  Future<void> process() async {
    _processing = true;

    final delegate = delegates.first;

    late final Map<LogicalKey, KeyEvent> keyDown;
    // if batch is true, we treat any tick containing keydown/keyup for the same key as a keydown
    if (batch) {
      late final Map<LogicalKey, KeyEvent> keyUp = {};
      keyDown = {};

      for (final event in _events) {
        if (event is KeyEvent) {
          switch (event.type) {
            case KeyEventType.up:
              keyUp[event.logicalKey] = event;
            case KeyEventType.down:
              keyDown[event.logicalKey] = event;
          }
        }
      }
      for (final key in keyUp.keys) {
        _events.remove(keyDown[key]);
        _events.remove(keyUp[key]);
      }
    }

    await delegate.handle(_events.sublist(0));
    _events.clear();
    if (batch) {
      _events.addAll(keyDown.values);
    }

    _processing = false;
  }

  @override
  Future dispose() async {
    FilamentApp.instance!.unregisterRequestFrameHook(process);
  }

  @override
  Future handle(InputEvent event) async {
    if (!_ready || _processing) {
      return;
    }

    _events.add(event);
    if (!this.batch) {
      await process();
    }
  }
}

import 'dart:async';
import 'package:logging/logging.dart';
import 'package:thermion_dart/src/input/src/implementations/fixed_orbit_camera_delegate_v2.dart';
import 'package:thermion_dart/src/input/src/implementations/free_flight_camera_delegate_v2.dart';
import 'package:thermion_dart/thermion_dart.dart';

typedef PointerEventDetails = (Vector2 localPosition, Vector2 delta);

abstract class InputHandlerDelegate {
  Future handle(List<InputEvent> events) async {
    // noop, override to implement
  }
  Future dispose() async {
    // noop, override if you need
  }
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
  InputHandlerDelegate? delegate;

  final bool batch;

  bool _ready = false;
  bool _processing = false;



  DelegateInputHandler({
    required this.viewer,
    this.delegate,
    this.batch = false,

  }) {
    FilamentApp.instance!.registerRequestFrameHook(process);
    viewer.initialized.then((_) {
      this._ready = true;
    });
  }

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
        ),
        batch: true);
  }

  factory DelegateInputHandler.flight(
    ThermionViewer viewer, {
    bool freeLook = false,
    bool moveOnHover = false,
    InputSensitivityOptions sensitivity = const InputSensitivityOptions(),
  }) =>
      DelegateInputHandler(
        batch: true,
        viewer: viewer,
        
        delegate: FreeFlightInputHandlerDelegateV2(viewer.view,
            sensitivity: sensitivity,moveOnHover: moveOnHover),
      );

  Future<void> process() async {
    if (delegate == null) {
      return;
    }
    _processing = true;

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

    await delegate!.handle(_events.sublist(0));
    _events.clear();
    if (batch) {
      _events.addAll(keyDown.values);
    }

    _processing = false;
  }

  @override
  Future dispose() async {
    FilamentApp.instance!.unregisterRequestFrameHook(process);
    delegate?.dispose();
  }

  @override
  Future handle(InputEvent event) async {
    if (!_ready || _processing || delegate == null) {
      return;
    }

    _events.add(event);
    if (!this.batch) {
      await process();
    }
  }
}

import 'dart:async';
import 'dart:collection';

import 'package:logging/logging.dart';
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
///
/// Events are queued in dispatch order and drained serially: each batch is
/// fully handled (delegates await FFI calls mid-handler) before the next
/// batch starts, so overlapping [handle] calls can never interleave inside
/// a delegate or complete out of order.
///
/// New events are rejected once [dispose] begins, and the queue is drained
/// before the delegate itself is disposed. Handler errors are captured and
/// logged rather than escaping as uncaught asynchronous exceptions.
///
class DelegateInputHandler implements InputHandler {
  final ThermionViewer viewer;
  InputHandlerDelegate? delegate;

  late final _logger = Logger(runtimeType.toString());

  final _pendingEvents = Queue<InputEvent>();

  // The tail of the event pipeline. Each scheduled drain is chained onto the
  // previous one; errors never propagate into this future.
  Future<void> _eventPipeline = Future<void>.value();
  bool _pipelineScheduled = false;

  // Set as soon as dispose() is called: new events are dropped from that
  // point on, and queued events are still drained before delegate teardown.
  bool _disposeStarted = false;
  bool _disposed = false;

  DelegateInputHandler({required this.viewer, this.delegate});

  factory DelegateInputHandler.fixedOrbit(
    ThermionViewer viewer, {
    double minimumDistance = 0.1,
    Vector3? target,
    InputSensitivityOptions sensitivity = const InputSensitivityOptions(),
    bool moveOnHover = false,
  }) {
    return DelegateInputHandler(
      viewer: viewer,
      delegate: OrbitInputHandlerDelegate(
        viewer.view,
        moveOnHover: moveOnHover,
        sensitivity: sensitivity,
        minZoomDistance: minimumDistance,
        maxZoomDistance: 1000.0,
      ),
    );
  }

  factory DelegateInputHandler.flight(
    ThermionViewer viewer, {
    bool freeLook = false,
    bool moveOnHover = false,
    InputSensitivityOptions sensitivity = const InputSensitivityOptions(),
  }) => DelegateInputHandler(
    viewer: viewer,
    delegate: FreeFlightInputHandlerDelegateV2(
      viewer.view,
      viewer.app,
      sensitivity: sensitivity,
      moveOnHover: moveOnHover,
    ),
  );

  @override
  Future dispose() async {
    if (_disposed) {
      return;
    }
    _disposeStarted = true;

    // Finish any in-flight batch, plus everything queued behind it, so the
    // delegate observes a consistent event stream before being torn down.
    await _eventPipeline;
    _pendingEvents.clear();

    final delegate = this.delegate;
    this.delegate = null;
    await delegate?.dispose();
    _disposed = true;
  }

  @override
  void handle(InputEvent event) {
    if (_disposeStarted || _disposed) {
      return;
    }
    _enqueue(event);
    _schedulePipeline();
  }

  // High-frequency pointer streams are coalesced while a backlog is waiting:
  // if the previously queued event is a move/hover of the same type, fold it
  // into this one (deltas accumulate, the latest position wins) and drop it.
  // Delegates consume either the delta or the difference between successive
  // positions, never both, so this preserves the gesture.
  void _enqueue(InputEvent event) {
    if (_pendingEvents.isNotEmpty) {
      final previous = _pendingEvents.last;
      if (previous is MouseEvent &&
          event is MouseEvent &&
          previous.type == event.type &&
          (event.type == MouseEventType.move || event.type == MouseEventType.hover)) {
        _pendingEvents.removeLast();
        event = MouseEvent(event.type, event.button, event.localPosition, previous.delta + event.delta);
      }
    }
    _pendingEvents.add(event);
  }

  void _schedulePipeline() {
    if (_pipelineScheduled) {
      return;
    }
    _pipelineScheduled = true;
    _eventPipeline = _eventPipeline.then((_) async {
      _pipelineScheduled = false;
      while (_pendingEvents.isNotEmpty && !_disposed) {
        final events = List<InputEvent>.of(_pendingEvents);
        _pendingEvents.clear();
        final delegate = this.delegate;
        if (delegate == null) {
          return;
        }
        try {
          await delegate.handle(events);
        } catch (error, stackTrace) {
          _logger.severe(
            "Input delegate failed to handle ${events.length} event(s); "
            "continuing with the next batch",
            error,
            stackTrace,
          );
        }
      }
    });
  }
}

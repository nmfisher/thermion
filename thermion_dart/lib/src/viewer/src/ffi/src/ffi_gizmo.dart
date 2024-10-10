import 'dart:async';
import 'dart:ffi';

import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_dart.g.dart';

import '../../../../utils/src/gizmo.dart';
import '../../../viewer.dart';

class FFIGizmo extends BaseGizmo {
  Pointer<TGizmo> pointer;

  late NativeCallable<GizmoPickCallbackFunction> _nativeCallback;
  FFIGizmo(
      this.pointer, ThermionViewer viewer) : super(x: 0, y: 0, z: 0, center: 0, viewer: viewer) {
    _nativeCallback =
        NativeCallable<GizmoPickCallbackFunction>.listener(_onPickResult);
  }

  ///
  /// The result(s) of calling [pickGizmo] (see below).
  ///
  // Stream<PickResult> get onPick => _pickResultController.stream;
  // final _pickResultController = StreamController<PickResult>.broadcast();

  void Function(PickResult)? _callback;

  void onPick(void Function(PickResult) callback) {
    _callback = callback;
  }

  void _onPickResult(DartEntityId entityId, int x, int y, Pointer<TView> view) {
    _callback?.call((entity: entityId, x: x, y: y));
  }

  ///
  /// Used to test whether a Gizmo is at the given viewport coordinates.
  /// Called by `FilamentGestureDetector` on a mouse/finger down event. You probably don't want to call this yourself.
  /// This is asynchronous and will require 2-3 frames to complete - subscribe to the [gizmoPickResult] stream to receive the results of this method.
  /// [x] and [y] must be in local logical coordinates (i.e. where 0,0 is at top-left of the ThermionWidget).
  ///
  @override
  Future pick(int x, int y) async {
    Gizmo_pick(pointer, x.toInt(), y, _nativeCallback.nativeFunction);
  }

  @override
  Future setVisibility(bool visible) async {
    Gizmo_setVisibility(pointer, visible);
  }
}

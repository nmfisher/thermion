import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:thermion_dart/thermion_dart/entities/abstract_gizmo.dart';
import 'package:vector_math/vector_math_64.dart';
import '../thermion_viewer.dart';

class Gizmo extends AbstractGizmo {
  final ThermionEntity x;
  final ThermionEntity y;
  final ThermionEntity z;

  final ThermionEntity center;

  final ThermionViewer _viewer;

  ThermionEntity? _activeAxis;
  ThermionEntity? _activeEntity;
  bool get isActive => _activeAxis != null;

  final Set<ThermionEntity> ignore;

  Aabb2 boundingBox = Aabb2();

  Gizmo(this.x, this.y, this.z, this.center, this._viewer,
      {this.ignore = const <ThermionEntity>{}}) {
    _viewer.pickResult.listen(_onPickResult);
  }

  Future _reveal() async {
    await _viewer.reveal(x, null);
    await _viewer.reveal(y, null);
    await _viewer.reveal(z, null);
    await _viewer.reveal(center, null);
  }

  final _stopwatch = Stopwatch();

  var _translation = Vector3.zero();

  void translate(double transX, double transY) async {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }
    if (_activeAxis == x) {
      _translation += Vector3(transX, 0.0, 0.0);
    } else {
      _translation += Vector3(0.0, transY, 0.0);
    }

    if (_stopwatch.elapsedMilliseconds > 16) {
      await _viewer.queuePositionUpdate(
          _activeEntity!, _translation.x, _translation.y, _translation.z,
          relative: true);
      _stopwatch.reset();
      _translation = Vector3.zero();
    }
  }

  void reset() {
    _activeAxis = null;
  }

  void _onPickResult(FilamentPickResult result) async {
    if (ignore.contains(result)) {
      detach();
      return;
    }
    if (result.entity == x || result.entity == y || result.entity == z) {
      _activeAxis = result.entity;
    } else {
      attach(result.entity);
    }
  }

  void attach(ThermionEntity entity) async {
    _activeAxis = null;
    _activeEntity = entity;
    await _reveal();

    await _viewer.setParent(x, entity);
    await _viewer.setParent(y, entity);
    await _viewer.setParent(z, entity);
    await _viewer.setParent(center, entity);
    boundingBox = await _viewer.getBoundingBox(x);
  }

  void detach() async {
    await _viewer.setParent(x, 0);
    await _viewer.setParent(y, 0);
    await _viewer.setParent(z, 0);
    await _viewer.setParent(center, 0);
    await _viewer.hide(x, null);
    await _viewer.hide(y, null);
    await _viewer.hide(z, null);
    await _viewer.hide(center, null);
  }
}

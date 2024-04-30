import 'package:dart_filament/dart_filament/entities/filament_entity.dart';
import 'package:dart_filament/dart_filament/filament_viewer_impl.dart';
import 'package:vector_math/vector_math_64.dart';

import '../abstract_filament_viewer.dart';

class Gizmo {
  final FilamentEntity x;
  Vector3 _x = Vector3(0.1, 0, 0);
  final FilamentEntity y;
  Vector3 _y = Vector3(0.0, 0.1, 0);
  final FilamentEntity z;
  Vector3 _z = Vector3(0.0, 0.0, 0.1);

  final FilamentViewer controller;

  FilamentEntity? _activeAxis;
  FilamentEntity? _activeEntity;
  bool get isActive => _activeAxis != null;

  Gizmo(this.x, this.y, this.z, this.controller) {
    controller.pickResult.listen(_onPickResult);
  }

  Future _reveal() async {
    await controller.reveal(x, null);
    await controller.reveal(y, null);
    await controller.reveal(z, null);
  }

  void translate(double x, double y) async {
    late Vector3 vec;
    if (_activeAxis == x) {
      vec = _x;
    } else if (_activeAxis == y) {
      vec = _y;
    } else if (_activeAxis == z) {
      vec = _z;
    }
    await controller.queuePositionUpdate(
        _activeEntity!, x * vec.x, -y * vec.y, -x * vec.z,
        relative: true);
  }

  void reset() {
    _activeAxis = null;
  }

  void _onPickResult(FilamentPickResult result) async {
    if (result.entity == x || result.entity == y || result.entity == z) {
      _activeAxis = result.entity;
    } else {
      attach(result.entity);
    }
  }

  void attach(FilamentEntity entity) async {
    _activeAxis = null;
    _activeEntity = entity;
    await _reveal();
    await controller.setParent(x, entity);
    await controller.setParent(y, entity);
    await controller.setParent(z, entity);
  }

  void detach() async {
    await controller.setParent(x, 0);
    await controller.setParent(y, 0);
    await controller.setParent(z, 0);
    await controller.hide(x, null);
    await controller.hide(y, null);
    await controller.hide(z, null);
  }
}

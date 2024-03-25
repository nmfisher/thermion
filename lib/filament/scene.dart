import 'dart:async';
import 'package:flutter_filament/filament/entities/gizmo.dart';
import 'package:flutter_filament/filament/filament_controller.dart';

///
/// For now, this class just holds the entities that have been loaded (though not necessarily visible in the Filament Scene).
///
class SceneImpl extends Scene {
  final Gizmo _gizmo;
  Gizmo get gizmo => _gizmo;

  FilamentController controller;

  SceneImpl(this._gizmo, this.controller);

  @override
  FilamentEntity? selected;

  final _onUpdatedController = StreamController<bool>.broadcast();
  @override
  Stream<bool> get onUpdated => _onUpdatedController.stream;

  final _onLoadController = StreamController<FilamentEntity>.broadcast();
  @override
  Stream<FilamentEntity> get onLoad => _onLoadController.stream;

  final _onUnloadController = StreamController<FilamentEntity>.broadcast();
  @override
  Stream<FilamentEntity> get onUnload => _onUnloadController.stream;

  final _lights = <FilamentEntity>{};
  final _entities = <FilamentEntity>{};

  void registerLight(FilamentEntity entity) {
    _lights.add(entity);
    _onLoadController.sink.add(entity);
    _onUpdatedController.add(true);
  }

  void unregisterLight(FilamentEntity entity) async {
    var children = await controller.getChildEntities(entity, true);
    if (selected == entity || children.contains(selected)) {
      selected = null;
      _gizmo.detach();
    }
    _lights.remove(entity);
    _onUnloadController.add(entity);
    _onUpdatedController.add(true);
  }

  void unregisterEntity(FilamentEntity entity) async {
    var children = await controller.getChildEntities(entity, true);
    if (selected == entity || children.contains(selected)) {
      selected = null;
      _gizmo.detach();
    }
    _entities.remove(entity);
    _onUnloadController.add(entity);
    _onUpdatedController.add(true);
  }

  void registerEntity(FilamentEntity entity) {
    _entities.add(entity);
    _entities.add(entity);
    _onLoadController.sink.add(entity);
    _onUpdatedController.add(true);
  }

  void clearLights() {
    for (final light in _lights) {
      if (selected == light) {
        selected = null;
        _gizmo.detach();
      }
      _onUnloadController.add(light);
    }

    _lights.clear();
    _onUpdatedController.add(true);
  }

  void clearEntities() {
    for (final entity in _entities) {
      if (selected == entity) {
        selected = null;
        _gizmo.detach();
      }
      _onUnloadController.add(entity);
    }
    _entities.clear();
    _onUpdatedController.add(true);
  }

  ///
  /// Lists all entities currently loaded (not necessarily active in the scene).
  ///
  Iterable<FilamentEntity> listLights() {
    return _lights;
  }

  @override
  Iterable<FilamentEntity> listEntities() {
    return _entities;
  }

  void registerSelected(FilamentEntity entity) {
    selected = entity;
    _onUpdatedController.add(true);
  }

  void unregisterSelected() {
    selected = null;
    _onUpdatedController.add(true);
  }

  @override
  void select(FilamentEntity entity) {
    selected = entity;
    _gizmo.attach(entity);
    _onUpdatedController.add(true);
  }
}

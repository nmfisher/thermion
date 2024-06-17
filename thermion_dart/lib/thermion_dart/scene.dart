import 'dart:async';

import 'thermion_viewer.dart';

///
/// For now, this class just holds the entities that have been loaded (though not necessarily visible in the Filament Scene).
///
class SceneImpl extends Scene {

  ThermionViewer controller;

  SceneImpl(this.controller);

  @override
  ThermionEntity? selected;

  final _onUpdatedController = StreamController<bool>.broadcast();
  @override
  Stream<bool> get onUpdated => _onUpdatedController.stream;

  final _onLoadController = StreamController<ThermionEntity>.broadcast();
  @override
  Stream<ThermionEntity> get onLoad => _onLoadController.stream;

  final _onUnloadController = StreamController<ThermionEntity>.broadcast();
  @override
  Stream<ThermionEntity> get onUnload => _onUnloadController.stream;

  final _lights = <ThermionEntity>{};
  final _entities = <ThermionEntity>{};

  void registerLight(ThermionEntity entity) {
    _lights.add(entity);
    _onLoadController.sink.add(entity);
    _onUpdatedController.add(true);
  }

  void unregisterLight(ThermionEntity entity) async {
    var children = await controller.getChildEntities(entity, true);
    if (selected == entity || children.contains(selected)) {
      selected = null;
      controller.gizmo?.detach();
    }
    _lights.remove(entity);
    _onUnloadController.add(entity);
    _onUpdatedController.add(true);
  }

  void unregisterEntity(ThermionEntity entity) async {
    var children = await controller.getChildEntities(entity, true);
    if (selected == entity || children.contains(selected)) {
      selected = null;
      
      controller.gizmo?.detach();
    }
    _entities.remove(entity);
    _onUnloadController.add(entity);
    _onUpdatedController.add(true);
  }

  void registerEntity(ThermionEntity entity) {
    _entities.add(entity);
    _onLoadController.sink.add(entity);
    _onUpdatedController.add(true);
  }

  void clearLights() {
    for (final light in _lights) {
      if (selected == light) {
        selected = null;
        controller.gizmo?.detach();
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
        controller.gizmo?.detach();
      }
      _onUnloadController.add(entity);
    }
    _entities.clear();
    _onUpdatedController.add(true);
  }

  ///
  /// Lists all entities currently loaded (not necessarily active in the scene).
  ///
  Iterable<ThermionEntity> listLights() {
    return _lights;
  }

  @override
  Iterable<ThermionEntity> listEntities() {
    return _entities;
  }

  void registerSelected(ThermionEntity entity) {
    selected = entity;
    _onUpdatedController.add(true);
  }

  void unregisterSelected() {
    selected = null;
    _onUpdatedController.add(true);
  }

  @override
  void select(ThermionEntity entity) {
    selected = entity;
    controller.gizmo?.attach(entity);
    _onUpdatedController.add(true);
  }
}

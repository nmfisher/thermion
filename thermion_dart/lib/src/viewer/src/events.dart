import 'shared_types/shared_types.dart';

///
/// To ensure we can easily store/recreate a particular, [ThermionViewer] will raise an event whenever an
/// entity is added/removed.
///
enum EventType { EntityAdded, EntityRemoved, EntityHidden, EntityRevealed, ClearLights }

///
/// An "entity added" event must provide sufficient detail to enable that asset to be reloaded in future.
/// This requires a bit more legwork because entities may be lights (direct/indirect), geometry or gltf.
///
enum EntityType { Geometry, Gltf, DirectLight, IBL }

class SceneUpdateEvent {
  late final ThermionEntity? entity;
  late final EventType eventType;

  EntityType get addedEntityType {
    if (_directLight != null) {
      return EntityType.DirectLight;
    } else if (_ibl != null) {
      return EntityType.IBL;
    } else if (_gltf != null) {
      return EntityType.Gltf;
    } else if (_geometry != null) {
      return EntityType.Geometry;
    } else {
      throw Exception("Unknown entity type");
    }
  }

  DirectLight? _directLight;
  IBL? _ibl;
  GLTF? _gltf;
  Geometry? _geometry;

  SceneUpdateEvent.remove(this.entity) {
    this.eventType = EventType.EntityRemoved;
  }

  SceneUpdateEvent.reveal(this.entity) {
    this.eventType = EventType.EntityRevealed;
  }

  SceneUpdateEvent.hide(this.entity) {
    this.eventType = EventType.EntityHidden;
  }

  SceneUpdateEvent.addDirectLight(this.entity, this._directLight) {
    this.eventType = EventType.EntityAdded;
  }

  SceneUpdateEvent.addIbl(this.entity, this._ibl) {
    this.eventType = EventType.EntityAdded;
  }

  SceneUpdateEvent.addGltf(this.entity, this._gltf) {
    this.eventType = EventType.EntityAdded;
  }

  SceneUpdateEvent.addGeometry(this.entity, this._geometry) {
    this.eventType = EventType.EntityAdded;
  }

  SceneUpdateEvent.clearLights() {
    this.eventType = EventType.ClearLights;
  }

  DirectLight getDirectLight() {
    return _directLight!;
  }

  IBL getAsIBL() {
    return _ibl!;
  }

  GLTF getAsGLTF() {
    return _gltf!;
  }

  Geometry getAsGeometry() {
    return _geometry!;
  }
}

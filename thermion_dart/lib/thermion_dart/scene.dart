import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'dart:async';

///
/// For now, this class just holds the entities that have been loaded (though not necessarily visible in the Filament Scene).
///
abstract class Scene {
  ///
  /// The last entity clicked/tapped in the viewport (internally, the result of calling pick);
  ThermionEntity? selected;

  ///
  /// A Stream updated whenever an entity is added/removed from the scene.
  ///
  Stream<bool> get onUpdated;

  ///
  /// A Stream containing every ThermionEntity added to the scene (i.e. via [loadGlb], [loadGltf] or [addLight]).
  /// This is provided for convenience so you can set listeners in front-end widgets that can respond to entity loads without manually passing around the ThermionEntity returned from those methods.
  ///
  Stream<ThermionEntity> get onLoad;

  ///
  /// A Stream containing every ThermionEntity removed from the scene (i.e. via [removeEntity], [clearEntities], [removeLight] or [clearLights]).

  Stream<ThermionEntity> get onUnload;

  ///
  /// Lists all light entities currently loaded (not necessarily active in the scene). Does not account for instances.
  ///
  Iterable<ThermionEntity> listLights();

  ///
  /// Lists all entities currently loaded (not necessarily active in the scene). Does not account for instances.
  ///
  Iterable<ThermionEntity> listEntities();

  ///
  /// Attach the gizmo to the specified entity.
  ///
  void select(ThermionEntity entity);

  ///
  ///
  ///
  void registerEntity(ThermionEntity entity);

}
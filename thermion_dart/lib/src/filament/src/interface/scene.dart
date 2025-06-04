import 'package:thermion_dart/thermion_dart.dart';

abstract class Scene {
  
  /// Adds all renderable entities in [asset] to this scene.
  ///
  ///
  Future add(covariant ThermionAsset asset);
  
  /// Adds [entity] to this scene (which is assumed to have a Renderable 
  /// component).
  ///
  Future addEntity(ThermionEntity entity);

  /// Removes all renderable entities in [asset] from this scene.
  ///
  Future remove(covariant ThermionAsset asset);
}

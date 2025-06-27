import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/src/filament/src/interface/skybox.dart';
import 'package:thermion_dart/thermion_dart.dart';

abstract class Scene<T> extends NativeHandle<T> {
  
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
  ///
  Future remove(ThermionAsset asset);

  /// Removes [entity] from this scene.
  ///
  ///
  Future removeEntity(ThermionEntity entity);

  ///
  ///
  ///
  Future<ThermionAsset?> getAssetForHighlight(ThermionEntity entity);

  /// Renders an outline around [entity] with the given color.
  ///
  ///
  Future setStencilHighlight(ThermionAsset asset,
      {double r = 1.0,
      double g = 0.0,
      double b = 0.0,
      int? entity,
      int primitiveIndex = 0});

  /// Removes the outline around [entity]. Noop if there was no highlight.
  ///
  ///
  Future removeStencilHighlight(ThermionAsset asset);

  ///
  ///
  ///
  Future setIndirectLight(IndirectLight? indirectLight) {
    throw UnimplementedError();
  }

  ///
  ///
  ///
  Future<IndirectLight?> getIndirectLight() {
    throw UnimplementedError();
  }

  ///
  ///
  ///
  Future setSkybox(Skybox skybox) {
    throw UnimplementedError();
  }
}

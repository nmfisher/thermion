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

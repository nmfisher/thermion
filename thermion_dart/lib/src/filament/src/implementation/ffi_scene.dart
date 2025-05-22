import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFIScene extends Scene {
  final Pointer<TScene> scene;

  FFIScene(this.scene);

  @override
  Future add(covariant FFIAsset asset) async {
    SceneAsset_addToScene(asset.asset, scene);
  }

  @override
  Future addEntity(ThermionEntity entity) async {
    Scene_addEntity(scene, entity);
  }

  @override
  Future remove(covariant FFIAsset asset) async {
    SceneAsset_removeFromScene(asset.asset, scene);
  }
}

import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/scene.dart';
import 'package:thermion_dart/src/bindings/bindings.dart';

class FFIScene extends Scene {
  final Pointer<TScene> scene;

  FFIScene(this.scene);

  @override
  Future add(covariant FFIAsset asset) async {
    SceneAsset_addToScene(asset.asset, scene);
  }

  @override
  Future remove(covariant FFIAsset asset) async {
    SceneAsset_removeFromScene(asset.asset, scene);
  }
}

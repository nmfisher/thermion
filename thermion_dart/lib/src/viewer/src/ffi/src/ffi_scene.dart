import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_asset.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_filament_app.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_render_target.dart';
import 'package:thermion_dart/src/viewer/src/shared_types/scene.dart';
import 'callbacks.dart';


class FFIScene extends Scene {
  final Pointer<TScene> scene;
  final FFIFilamentApp app;

  FFIRenderTarget? renderTarget;

  FFIScene(this.scene, this.app) {}

  @override
  Future add(covariant FFIAsset asset) async {
    SceneAsset_addToScene(asset.asset, scene);
  }

  @override
  Future remove(covariant FFIAsset asset) async {
    SceneAsset_removeFromScene(asset.asset, scene);
  }
}

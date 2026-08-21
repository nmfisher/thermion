import 'package:thermion_dart/src/filament/src/implementation/ffi_indirect_light.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_skybox.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

class FFIScene extends Scene<Pointer<TScene>> {
  final Pointer<TScene> scene;

  final FFIFilamentApp _app;

  FFIScene(this.scene, this._app);

  Pointer<TScene> getNativeHandle() {
    return scene;
  }

  @override
  Future add(ThermionAsset asset) async {
    await withVoidCallback(
      (requestId, cb) => SceneAsset_addToSceneRenderThread(asset.getNativeHandle(), scene, requestId, cb),
    );
  }

  @override
  Future addEntity(ThermionEntity entity) async {
    await withVoidCallback((requestId, cb) => Scene_addEntityRenderThread(scene, entity, requestId, cb));
  }

  @override
  Future remove(ThermionAsset asset) async {
    await withVoidCallback(
      (requestId, cb) => SceneAsset_removeFromSceneRenderThread(asset.getNativeHandle(), scene, requestId, cb),
    );
  }

  @override
  Future removeEntity(ThermionEntity entity) async {
    await withVoidCallback((requestId, cb) => Scene_removeEntityRenderThread(scene, entity, requestId, cb));
  }

  IndirectLight? _indirectLight;

  Future setIndirectLight(IndirectLight? indirectLight) async {
    if (indirectLight == null) {
      await withVoidCallback((requestId, cb) => Scene_setIndirectLightRenderThread(scene, nullptr, requestId, cb));
      _indirectLight = null;
    } else {
      await withVoidCallback(
        (requestId, cb) =>
            Scene_setIndirectLightRenderThread(scene, (indirectLight as FFIIndirectLight).pointer, requestId, cb),
      );
      _indirectLight = indirectLight;
    }
  }

  ///
  ///
  ///
  Future<IndirectLight?> getIndirectLight() async {
    return _indirectLight;
  }

  ///
  ///
  ///
  Future setSkybox(Skybox? skybox) async {
    if (skybox == null) {
      await withVoidCallback((requestId, cb) => Scene_setSkyboxRenderThread(scene, nullptr, requestId, cb));
    } else {
      await withVoidCallback(
        (requestId, cb) => Scene_setSkyboxRenderThread(scene, (skybox as FFISkybox).pointer, requestId, cb),
      );
    }
  }

  ///
  ///
  ///
  Future<Skybox?> getSkybox() async {
    final ptr = Scene_getSkybox(scene);
    if (ptr == nullptr) {
      return null;
    }
    return FFISkybox(ptr, _app);
  }

  ///
  /// Destroys this scene and releases its resources.
  ///
  Future destroy() async {
    await withVoidCallback((requestId, cb) => Engine_destroySceneRenderThread(_app.engine, scene, requestId, cb));
  }
}

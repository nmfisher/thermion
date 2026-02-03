import 'package:thermion_dart/src/filament/src/implementation/ffi_indirect_light.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_skybox.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/src/filament/src/interface/skybox.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFIScene extends Scene<Pointer<TScene>> {

  final Pointer<TScene> scene;

  FFIScene(this.scene);

  Pointer<TScene> getNativeHandle() {
    return scene;
  }

  @override
  Future add(ThermionAsset asset) async {
    SceneAsset_addToScene(asset.getHandle(), scene);
  }

  ///
  ///
  ///
  @override
  Future addEntity(ThermionEntity entity) async {
    Scene_addEntity(scene, entity);
  }

  ///
  ///
  ///
  @override
  Future remove(ThermionAsset asset) async {
    SceneAsset_removeFromScene(asset.getHandle(), scene);
  }

  ///
  ///
  ///
  @override
  Future removeEntity(ThermionEntity entity) async {
    await withVoidCallback((requestId, cb) =>
        Scene_removeEntityRenderThread(scene, entity, requestId, cb));
  }

  IndirectLight? _indirectLight;

  ///
  ///
  ///
  Future setIndirectLight(IndirectLight? indirectLight) async {
    if (indirectLight == null) {
      await withVoidCallback((requestId, cb) =>
          Scene_setIndirectLightRenderThread(scene, nullptr, requestId, cb));
      _indirectLight = null;
    } else {
      await withVoidCallback((requestId, cb) =>
          Scene_setIndirectLightRenderThread(
              scene, (indirectLight as FFIIndirectLight).pointer, requestId, cb));
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
      await withVoidCallback((requestId, cb) =>
          Scene_setSkyboxRenderThread(scene, nullptr, requestId, cb));
    } else {
      await withVoidCallback((requestId, cb) =>
          Scene_setSkyboxRenderThread(scene, (skybox as FFISkybox).pointer, requestId, cb));
    }
  }

  ///
  /// Destroys this scene and releases its resources.
  ///
  Future destroy() async {
    await withVoidCallback((requestId, cb) =>
        Engine_destroySceneRenderThread(
            FilamentApp.instance!.engine, scene, requestId, cb));
  }
}

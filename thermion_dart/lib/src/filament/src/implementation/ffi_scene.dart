import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_indirect_light.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_skybox.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/src/filament/src/interface/skybox.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:logging/logging.dart';

class FFIScene extends Scene<Pointer<TScene>> {
  late final _logger = Logger(this.runtimeType.toString());

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
    Scene_removeEntity(scene, entity);
  }

  IndirectLight? _indirectLight;

  ///
  ///
  ///
  Future setIndirectLight(IndirectLight? indirectLight) async {
    if (indirectLight == null) {
      Scene_setIndirectLight(scene, nullptr);
      _indirectLight = null;
    } else {
      Scene_setIndirectLight(
          scene, (indirectLight as FFIIndirectLight).pointer);
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
  Future setSkybox(Skybox skybox) async {
    Scene_setSkybox(scene, (skybox as FFISkybox).pointer);
  }
}

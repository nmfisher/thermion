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

  ///
  ///
  ///
  @override
  Future removeStencilHighlight(ThermionAsset asset) async {
    if (!_highlightInstances.containsKey(asset)) {
      _logger
          .warning("No stencil highlight for asset (entity ${asset.entity})");
      return;
    }
    _logger
        .info("Removing stencil highlight for asset (entity ${asset.entity})");

    final highlight = _highlightInstances[asset]!;
    _highlightInstances.remove(asset);

    await remove(highlight);
    final materialInstance = await highlight.getMaterialInstanceAt();
    await FilamentApp.instance!.destroyAsset(highlight);
    await materialInstance.destroy();

    _logger
        .info("Removed stencil highlight for asset (entity ${asset.entity})");
  }

  final _highlightInstances = <ThermionAsset, ThermionAsset>{};

  Future<ThermionAsset?> getAssetForHighlight(ThermionEntity entity) async {
    for (final asset in _highlightInstances.keys) {
      var highlightAsset = _highlightInstances[asset]!;
      if (highlightAsset.entity == entity) {
        return asset;
      }
      for (final child in await highlightAsset.getChildEntities()) {
        if (child == entity) {
          return asset;
        }
      }
    }
    return null;
  }

  ///
  ///
  ///
  @override
  Future setStencilHighlight(ThermionAsset asset,
      {double r = 1.0,
      double g = 0.0,
      double b = 0.0,
      int? entity,
      int primitiveIndex = 0}) async {
    entity ??= asset.entity;

    if (_highlightInstances.containsKey(asset)) {
      _logger
          .info("Stencil highlight exists for asset (entity ${asset.entity})");
      var instance = _highlightInstances[asset];
      var highlightMaterialInstance = await instance!.getMaterialInstanceAt();
      await highlightMaterialInstance.setParameterFloat4(
          "baseColorFactor", r, g, b, 1.0);
    } else {
      var highlightMaterialInstance =
          await FilamentApp.instance!.createUnlitMaterialInstance();
      var highlightInstance = await asset
          .createInstance(materialInstances: [highlightMaterialInstance]);
      _highlightInstances[asset] = highlightInstance as FFIAsset;
      await highlightInstance.setCastShadows(false);
      await highlightInstance.setReceiveShadows(false);

      var sourceMaterialInstance =
          await asset.getMaterialInstanceAt(entity: entity);
      await sourceMaterialInstance.setStencilWriteEnabled(true);
      await sourceMaterialInstance.setDepthWriteEnabled(true);
      await sourceMaterialInstance
          .setStencilOpDepthStencilPass(StencilOperation.REPLACE);
      await sourceMaterialInstance
          .setStencilCompareFunction(SamplerCompareFunction.A);

      await sourceMaterialInstance
          .setStencilReferenceValue(View.STENCIL_HIGHLIGHT_REFERENCE_VALUE);

      await highlightMaterialInstance
          .setStencilCompareFunction(SamplerCompareFunction.NE);
      await highlightMaterialInstance
          .setStencilReferenceValue(View.STENCIL_HIGHLIGHT_REFERENCE_VALUE);
      await highlightMaterialInstance.setDepthCullingEnabled(true);
      await highlightMaterialInstance.setParameterFloat4(
          "baseColorFactor", r, g, b, 1.0);

      await add(highlightInstance);

      var transform = await FilamentApp.instance!
          .getWorldTransform(highlightInstance.entity);

      await FilamentApp.instance!.setTransform(highlightInstance.entity,
          Matrix4.diagonal3(Vector3(1.1, 1.1, 1.1)) * transform);

      await FilamentApp.instance!.setPriority(highlightInstance.entity, 7);

      await FilamentApp.instance!.setParent(highlightInstance.entity, entity);

      _logger
          .info("Added stencil highlight for asset (entity ${asset.entity})");
    }
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

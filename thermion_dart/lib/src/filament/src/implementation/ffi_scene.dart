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

  final _outlines = <ThermionAsset, FFIAsset>{};

  ///
  ///
  ///
  @override
  Future removeStencilHighlight(ThermionAsset asset) async {
    if (_outlines.containsKey(asset)) {
      final highlight = _outlines[asset]!;
      await remove(highlight);
    }
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

    if (!_outlines.containsKey(asset)) {
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

      var highlightMaterialInstance =
          await FilamentApp.instance!.createUnlitMaterialInstance();

      await highlightMaterialInstance
          .setStencilCompareFunction(SamplerCompareFunction.NE);
      await highlightMaterialInstance
          .setStencilReferenceValue(View.STENCIL_HIGHLIGHT_REFERENCE_VALUE);
      await highlightMaterialInstance.setDepthCullingEnabled(false);
      await highlightMaterialInstance.setParameterFloat4(
          "baseColorFactor", r, g, b, 1.0);

      var highlightInstance = await asset
          .createInstance(materialInstances: [highlightMaterialInstance]);
      await add(highlightInstance as FFIAsset);
      _outlines[asset] = highlightInstance as FFIAsset;

      var transform = await FilamentApp.instance!
          .getWorldTransform(highlightInstance.entity);

      await FilamentApp.instance!.setTransform(highlightInstance.entity,
          Matrix4.diagonal3(Vector3(1.1, 1.1, 1.1)) * transform);

      await FilamentApp.instance!.setPriority(highlightInstance.entity, 7);

      await FilamentApp.instance!.setParent(highlightInstance.entity, entity);
    }
  }
}

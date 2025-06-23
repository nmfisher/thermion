import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_indirect_light.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_skybox.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/src/filament/src/interface/skybox.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:logging/logging.dart';

class FFIScene extends Scene {
  late final _logger = Logger(this.runtimeType.toString());

  final Pointer<TScene> scene;

  FFIScene(this.scene);

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
    if (!_highlighted.contains(asset)) {
      _logger
          .warning("No stencil highlight for asset (entity ${asset.entity})");
      return;
    }
    _logger
        .info("Removing stencil highlight for asset (entity ${asset.entity})");
    _highlighted.remove(asset);
    final highlight = _highlightInstances[asset]!;

    await remove(highlight);
    await FilamentApp.instance!.destroyAsset(highlight);

    _logger
        .info("Removed stencil highlight for asset (entity ${asset.entity})");
  }

  static MaterialInstance? _highlightMaterialInstance;
  final _highlightInstances = <ThermionAsset, FFIAsset>{};
  final _highlighted = <ThermionAsset>{};

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

    if (_highlighted.contains(asset)) {
      _logger
          .info("Stencil highlight exists for asset (entity ${asset.entity})");
    } else {
      _highlighted.add(asset);
      _highlightMaterialInstance ??=
          await FilamentApp.instance!.createUnlitMaterialInstance();
      var highlightInstance = await asset
          .createInstance(materialInstances: [_highlightMaterialInstance!]);
      
      await highlightInstance.setCastShadows(false);
      await highlightInstance.setReceiveShadows(false);
      
      _highlightInstances[asset] = highlightInstance as FFIAsset;


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

      await _highlightMaterialInstance!
          .setStencilCompareFunction(SamplerCompareFunction.NE);
      await _highlightMaterialInstance!
          .setStencilReferenceValue(View.STENCIL_HIGHLIGHT_REFERENCE_VALUE);
      await _highlightMaterialInstance!.setDepthCullingEnabled(true);
      await _highlightMaterialInstance!
          .setParameterFloat4("baseColorFactor", r, g, b, 1.0);

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

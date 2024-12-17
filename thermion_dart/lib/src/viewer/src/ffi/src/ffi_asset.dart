import 'dart:typed_data';

import 'package:thermion_dart/src/viewer/src/ffi/src/callbacks.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_material.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_viewer_ffi.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFIAsset extends ThermionAsset {
  final Pointer<TSceneAsset> pointer;
  final Pointer<TSceneManager> sceneManager;
  Pointer<TRenderableManager> get renderableManager =>
      Engine_getRenderableManager(engine);
  final Pointer<TEngine> engine;
  FFIAsset? _highlight;
  final Pointer<TMaterialProvider> _unlitMaterialProvider;
  final bool isInstance;

  late final ThermionEntity entity;

  FFIAsset(
      this.pointer, this.sceneManager, this.engine, this._unlitMaterialProvider,
      {this.isInstance = false}) {
    entity = SceneAsset_getEntity(pointer);
  }

  @override
  Future<List<ThermionEntity>> getChildEntities() async {
    var count = SceneAsset_getChildEntityCount(pointer);
    var children = Int32List(count);
    SceneAsset_getChildEntities(pointer, children.address);
    return children;
  }

  @override
  Future<ThermionAsset> getInstance(int index) async {
    if (isInstance) {
      throw Exception(
          "This is itself an instance. Call getInstance on the original asset that this instance was created from");
    }
    var instance = SceneAsset_getInstance(pointer, index);
    if (instance == nullptr) {
      throw Exception("No instance available at index $index");
    }
    return FFIAsset(instance, sceneManager, engine, _unlitMaterialProvider);
  }

  ///
  ///
  ///
  @override
  Future<FFIAsset> createInstance(
      {covariant List<MaterialInstance>? materialInstances = null}) async {
    var created = await withPointerCallback<TSceneAsset>((cb) {
      var ptrList = Int64List(materialInstances?.length ?? 0);
      if (materialInstances != null && materialInstances.isNotEmpty) {
        ptrList.setRange(
            0,
            materialInstances.length,
            materialInstances
                .cast<FFIMaterialInstance>()
                .map((mi) => mi.pointer.address)
                .toList());
      }

      SceneAsset_createInstanceRenderThread(
          pointer,
          ptrList.address.cast<Pointer<TMaterialInstance>>(),
          materialInstances?.length ?? 0,
          cb);
    });
    if (created == FILAMENT_ASSET_ERROR) {
      throw Exception("Failed to create instance");
    }
    return FFIAsset(created, sceneManager, engine, _unlitMaterialProvider);
  }

  ///
  ///
  ///
  @override
  Future<int> getInstanceCount() async {
    return SceneAsset_getInstanceCount(pointer);
  }

  ///
  ///
  ///
  @override
  Future<List<ThermionAsset>> getInstances() async {
    var count = await getInstanceCount();
    final result = List<ThermionAsset>.generate(count, (i) {
      return FFIAsset(SceneAsset_getInstance(pointer, i), sceneManager, engine,
          _unlitMaterialProvider);
    });

    return result;
  }

  @override
  Future removeStencilHighlight() async {
    if (_highlight != null) {
      SceneManager_removeFromScene(sceneManager, _highlight!.entity);
      final childEntities = await _highlight!.getChildEntities();
      for (final child in childEntities) {
        SceneManager_removeFromScene(sceneManager, child);
      }
    }
  }

  @override
  Future setStencilHighlight(
      {double r = 1.0,
      double g = 0.0,
      double b = 0.0,
      int? entityIndex}) async {
    if (_highlight == null) {
      var targetEntity = this.entity;
      if (entityIndex != null) {
        final childEntities = await this.getChildEntities();
        targetEntity = childEntities[entityIndex!];
      }
      var sourceMaterialInstance = FFIMaterialInstance(
          RenderableManager_getMaterialInstanceAt(
              renderableManager, targetEntity, 0),
          sceneManager);

      await sourceMaterialInstance.setStencilWriteEnabled(true);
      await sourceMaterialInstance.setDepthWriteEnabled(true);
      await sourceMaterialInstance
          .setStencilOpDepthStencilPass(StencilOperation.REPLACE);

      await sourceMaterialInstance.setStencilReferenceValue(1);

      final materialInstancePtr =
          await withPointerCallback<TMaterialInstance>((cb) {
        final key = Struct.create<TMaterialKey>();
        MaterialProvider_createMaterialInstanceRenderThread(
            _unlitMaterialProvider, key.address, cb);
      });
      final highlightMaterialInstance =
          FFIMaterialInstance(materialInstancePtr, sceneManager);
      await highlightMaterialInstance
          .setStencilCompareFunction(SamplerCompareFunction.NE);
      await highlightMaterialInstance.setStencilReferenceValue(1);

      await highlightMaterialInstance.setDepthCullingEnabled(false);

      await highlightMaterialInstance.setParameterFloat("vertexScale", 1.03);
      await highlightMaterialInstance.setParameterFloat4(
          "baseColorFactor", r, g, b, 1.0);

      var highlightInstance = await this
          .createInstance(materialInstances: [highlightMaterialInstance]);
      _highlight = highlightInstance;

      await highlightMaterialInstance.setStencilReferenceValue(1);
      RenderableManager_setPriority(renderableManager, targetEntity, 0);
      final transformManager = Engine_getTransformManager(engine);
      TransformManager_setParent(
          transformManager, _highlight!.entity, entity, false);
    }

    var targetHighlightEntity = _highlight!.entity;

    if (entityIndex != null) {
      var highlightChildEntities = await _highlight!.getChildEntities();
      targetHighlightEntity = highlightChildEntities[entityIndex!];
    }

    RenderableManager_setPriority(renderableManager, targetHighlightEntity, 7);

    SceneManager_addToScene(sceneManager, targetHighlightEntity);
  }

  @override
  Future addToScene() async {
    SceneAsset_addToScene(pointer, SceneManager_getScene(sceneManager));
  }

  @override
  Future removeFromScene() async {
    SceneManager_removeFromScene(sceneManager, entity);
    for (final child in await getChildEntities()) {
      SceneManager_removeFromScene(sceneManager, child);
    }
  }
}

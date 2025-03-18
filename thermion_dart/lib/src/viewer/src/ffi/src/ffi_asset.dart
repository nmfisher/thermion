import 'dart:typed_data';

import 'package:thermion_dart/src/viewer/src/ffi/src/callbacks.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_filament_app.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_material.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_viewer_ffi.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class FFIAsset extends ThermionAsset {
  ///
  ///
  ///
  final Pointer<TSceneAsset> asset;

  ///
  ///
  ///
  final FFIFilamentApp app;

  ///
  ///
  ///
  FFIAsset? _highlight;

  ///
  ///
  ///
  final bool isInstance;

  ///
  ///
  ///
  late final ThermionEntity entity;

  FFIAsset(this.asset, this.app, {this.isInstance = false}) {
    entity = SceneAsset_getEntity(asset);
  }

  @override
  Future<List<ThermionEntity>> getChildEntities() async {
    var count = SceneAsset_getChildEntityCount(asset);
    var children = Int32List(count);
    SceneAsset_getChildEntities(asset, children.address);
    return children;
  }

  @override
  Future<ThermionAsset> getInstance(int index) async {
    if (isInstance) {
      throw Exception(
          "This is itself an instance. Call getInstance on the original asset that this instance was created from");
    }
    var instance = SceneAsset_getInstance(asset, index);
    if (instance == nullptr) {
      throw Exception("No instance available at index $index");
    }
    return FFIAsset(instance, app);
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
          asset,
          ptrList.address.cast<Pointer<TMaterialInstance>>(),
          materialInstances?.length ?? 0,
          cb);
    });
    if (created == FILAMENT_ASSET_ERROR) {
      throw Exception("Failed to create instance");
    }
    return FFIAsset(created, app);
  }

  ///
  ///
  ///
  @override
  Future<int> getInstanceCount() async {
    return SceneAsset_getInstanceCount(asset);
  }

  ///
  ///
  ///
  @override
  Future<List<ThermionAsset>> getInstances() async {
    var count = await getInstanceCount();
    final result = List<ThermionAsset>.generate(count, (i) {
      return FFIAsset(SceneAsset_getInstance(asset, i), app);
    });

    return result;
  }

  ///
  ///
  ///
  @override
  Future removeStencilHighlight() async {
    throw UnimplementedError();
    // if (_highlight != null) {
    //   SceneManager_removeFromScene(sceneManager, _highlight!.entity);
    //   final childEntities = await _highlight!.getChildEntities();
    //   for (final child in childEntities) {
    //     SceneManager_removeFromScene(sceneManager, child);
    //   }
    // }
  }

  ///
  ///
  ///
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
              app.renderableManager, targetEntity, 0), app);

      await sourceMaterialInstance.setStencilWriteEnabled(true);
      await sourceMaterialInstance.setDepthWriteEnabled(true);
      await sourceMaterialInstance
          .setStencilOpDepthStencilPass(StencilOperation.REPLACE);

      await sourceMaterialInstance.setStencilReferenceValue(1);

      final materialInstancePtr =
          await withPointerCallback<TMaterialInstance>((cb) {
        final key = Struct.create<TMaterialKey>();
        MaterialProvider_createMaterialInstanceRenderThread(
            app.ubershaderMaterialProvider, key.address, cb);
      });
      final highlightMaterialInstance =
          FFIMaterialInstance(materialInstancePtr, app);
      await highlightMaterialInstance
          .setStencilCompareFunction(SamplerCompareFunction.NE);
      await highlightMaterialInstance.setStencilReferenceValue(1);

      await highlightMaterialInstance.setDepthCullingEnabled(false);

      await highlightMaterialInstance.setParameterFloat4(
          "baseColorFactor", r, g, b, 1.0);

      var highlightInstance = await this
          .createInstance(materialInstances: [highlightMaterialInstance]);
      _highlight = highlightInstance;

      await highlightMaterialInstance.setStencilReferenceValue(1);
      RenderableManager_setPriority(app.renderableManager, targetEntity, 0);
      
      TransformManager_setParent(
          app.transformManager, _highlight!.entity, entity, false);
    }

    var targetHighlightEntity = _highlight!.entity;

    if (entityIndex != null) {
      var highlightChildEntities = await _highlight!.getChildEntities();
      targetHighlightEntity = highlightChildEntities[entityIndex!];
    }

    RenderableManager_setPriority(
        app.renderableManager, targetHighlightEntity, 7);

    throw UnimplementedError();
  }

  FFIAsset? boundingBoxAsset;

  Future<v64.Aabb3> getBoundingBox() async {
    final entities = <ThermionEntity>[];
    if (RenderableManager_isRenderable(app.renderableManager, entity)) {
      entities.add(entity);
    } else {
      entities.addAll(await getChildEntities());
    }

    var boundingBox = v64.Aabb3();

    for (final entity in entities) {
      final aabb3 = RenderableManager_getAabb(app.renderableManager, entity);
      final entityBB = v64.Aabb3.centerAndHalfExtents(
        v64.Vector3(aabb3.centerX, aabb3.centerY, aabb3.centerZ),
        v64.Vector3(aabb3.halfExtentX, aabb3.halfExtentY, aabb3.halfExtentZ),
      );
      boundingBox.hull(entityBB);
    }
    return boundingBox;
  }

  ///
  ///
  ///
  @override
  Future<void> setBoundingBoxVisibility(bool visible) async {
    if (boundingBoxAsset == null) {
      final boundingBox = await SceneAsset_getBoundingBox(asset);

      final min = [
        boundingBox.centerX - boundingBox.halfExtentX,
        boundingBox.centerY - boundingBox.halfExtentY,
        boundingBox.centerZ - boundingBox.halfExtentZ
      ];
      final max = [
        boundingBox.centerX + boundingBox.halfExtentX,
        boundingBox.centerY + boundingBox.halfExtentY,
        boundingBox.centerZ + boundingBox.halfExtentZ
      ];

      // Create vertices for the bounding box wireframe
      // 8 vertices for a cube
      final vertices = Float32List(8 * 3);

      // Bottom vertices
      vertices[0] = min[0];
      vertices[1] = min[1];
      vertices[2] = min[2]; // v0
      vertices[3] = max[0];
      vertices[4] = min[1];
      vertices[5] = min[2]; // v1
      vertices[6] = max[0];
      vertices[7] = min[1];
      vertices[8] = max[2]; // v2
      vertices[9] = min[0];
      vertices[10] = min[1];
      vertices[11] = max[2]; // v3

      // Top vertices
      vertices[12] = min[0];
      vertices[13] = max[1];
      vertices[14] = min[2]; // v4
      vertices[15] = max[0];
      vertices[16] = max[1];
      vertices[17] = min[2]; // v5
      vertices[18] = max[0];
      vertices[19] = max[1];
      vertices[20] = max[2]; // v6
      vertices[21] = min[0];
      vertices[22] = max[1];
      vertices[23] = max[2]; // v7

      // Indices for lines (24 indices for 12 lines)
      final indices = [
        // Bottom face
        0, 1, 1, 2, 2, 3, 3, 0,
        // Top face
        4, 5, 5, 6, 6, 7, 7, 4,
        // Vertical edges
        0, 4, 1, 5, 2, 6, 3, 7
      ];

      // Create unlit material instance for the wireframe
      final materialInstancePtr =
          await withPointerCallback<TMaterialInstance>((cb) {
        final key = Struct.create<TMaterialKey>();
        MaterialProvider_createMaterialInstanceRenderThread(
            app.ubershaderMaterialProvider, key.address, cb);
      });

      final material = FFIMaterialInstance(materialInstancePtr, app);
      await material.setParameterFloat4(
          "baseColorFactor", 1.0, 1.0, 0.0, 1.0); // Yellow wireframe

      // Create geometry for the bounding box
      final geometry = Geometry(
        vertices,
        indices,
        primitiveType: PrimitiveType.LINES,
      );

      throw UnimplementedError();

      // boundingBoxAsset = await viewer.createGeometry(
      //   geometry,
      //   materialInstances: [material],
      //   keepData: false,
      // ) as FFIAsset;

      await boundingBoxAsset!.setCastShadows(false);
      await boundingBoxAsset!.setReceiveShadows(false);

      TransformManager_setParent(Engine_getTransformManager(app.engine),
          boundingBoxAsset!.entity, entity, false);
    }
    // if (visible) {
    //   await boundingBoxAsset!.addToScene();
    // } else {
    //   await boundingBoxAsset!.removeFromScene();
    // }
  }

  ///
  ///
  ///
  @override
  Future setMaterialInstanceAt(FFIMaterialInstance instance) async {
    var childEntities = await getChildEntities();
    final entities = <ThermionEntity>[entity, ...childEntities];
    for (final entity in entities) {
      RenderableManager_setMaterialInstanceAt(
          Engine_getRenderableManager(app.engine), entity, 0, instance.pointer);
    }
  }

  Future setCastShadows(bool castShadows) async {
    RenderableManager_setCastShadows(
        app.renderableManager, this.entity, castShadows);
    for (final entity in await this.getChildEntities()) {
      RenderableManager_setCastShadows(
          app.renderableManager, entity, castShadows);
    }
  }

  Future setReceiveShadows(bool receiveShadows) async {
    RenderableManager_setReceiveShadows(
        app.renderableManager, this.entity, receiveShadows);
    for (final entity in await this.getChildEntities()) {
      RenderableManager_setReceiveShadows(
          app.renderableManager, entity, receiveShadows);
    }
  }
}

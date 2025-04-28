import 'dart:typed_data';

import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/layers.dart';
import 'package:thermion_dart/src/utils/src/matrix.dart';
import 'package:thermion_dart/src/bindings/bindings.dart';
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
  final Pointer<TAnimationManager> animationManager;

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

  late final _logger = Logger(this.runtimeType.toString());

  ///
  ///
  ///
  FFIAsset(this.asset, this.app, this.animationManager,
      {this.isInstance = false}) {
    entity = SceneAsset_getEntity(asset);
  }

  ///
  ///
  ///
  @override
  Future<List<ThermionEntity>> getChildEntities() async {
    var count = SceneAsset_getChildEntityCount(asset);
    var children = Int32List(count);
    SceneAsset_getChildEntities(asset, children.address);
    return children;
  }

  ///
  ///
  ///
  @override
  Future<List<String?>> getChildEntityNames() async {
    final childEntities = await getChildEntities();
    var names = <String?>[];
    for (final entity in childEntities) {
      var name = NameComponentManager_getName(app.nameComponentManager, entity);
      if (name == nullptr) {
        names.add(null);
      } else {
        names.add(name.cast<Utf8>().toDartString());
      }
    }
    return names;
  }

  ///
  ///
  ///
  @override
  Future<ThermionEntity?> getChildEntity(String childName) async {
    final childEntities = await getChildEntities();
    for (final entity in childEntities) {
      var name = NameComponentManager_getName(app.nameComponentManager, entity);
      if (name == childName) {
        return entity;
      }
    }
    return null;
  }

  ///
  ///
  ///
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
    return FFIAsset(instance, app, animationManager);
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
    return FFIAsset(created, app, animationManager);
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
      return FFIAsset(SceneAsset_getInstance(asset, i), app, animationManager);
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
        targetEntity = childEntities[entityIndex];
      }
      var sourceMaterialInstance = FFIMaterialInstance(
          RenderableManager_getMaterialInstanceAt(
              app.renderableManager, targetEntity, 0),
          app);

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
      targetHighlightEntity = highlightChildEntities[entityIndex];
    }

    RenderableManager_setPriority(
        app.renderableManager, targetHighlightEntity, 7);

    throw UnimplementedError();
  }

  ///
  ///
  ///
  ThermionAsset? boundingBoxAsset;

  ///
  ///
  ///
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
  Future<ThermionAsset> createBoundingBoxAsset() async {
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

      boundingBoxAsset = await FilamentApp.instance!.createGeometry(
        geometry,
        animationManager,
        materialInstances: [material],
        keepData: false,
      ) as FFIAsset;

      await boundingBoxAsset!.setCastShadows(false);
      await boundingBoxAsset!.setReceiveShadows(false);

      TransformManager_setParent(Engine_getTransformManager(app.engine),
          boundingBoxAsset!.entity, entity, false);
    }
    return boundingBoxAsset!;
  }

  ///
  ///
  ///
  @override
  Future<MaterialInstance> getMaterialInstanceAt(
      {ThermionEntity? entity, int index = 0}) async {
    entity ??= this.entity;
    var ptr = RenderableManager_getMaterialInstanceAt(
        Engine_getRenderableManager(app.engine), entity, 0);
    return FFIMaterialInstance(ptr, app);
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

  ///
  ///
  ///
  Future setCastShadows(bool castShadows) async {
    RenderableManager_setCastShadows(
        app.renderableManager, this.entity, castShadows);
    for (final entity in await this.getChildEntities()) {
      RenderableManager_setCastShadows(
          app.renderableManager, entity, castShadows);
    }
  }

  ///
  ///
  ///
  Future setReceiveShadows(bool receiveShadows) async {
    RenderableManager_setReceiveShadows(
        app.renderableManager, this.entity, receiveShadows);
    for (final entity in await this.getChildEntities()) {
      RenderableManager_setReceiveShadows(
          app.renderableManager, entity, receiveShadows);
    }
  }

  ///
  ///
  ///
  Future<bool> isCastShadowsEnabled({ThermionEntity? entity}) async {
    entity ??= this.entity;
    return RenderableManager_isShadowCaster(app.renderableManager, entity);
  }

  ///
  ///
  ///
  Future<bool> isReceiveShadowsEnabled({ThermionEntity? entity}) async {
    entity ??= this.entity;
    return RenderableManager_isShadowReceiver(app.renderableManager, entity);
  }

  ///
  ///
  ///
  Future transformToUnitCube() async {
    TransformManager_transformToUnitCube(
        app.transformManager, entity, SceneAsset_getBoundingBox(asset));
  }

  ///
  ///
  ///
  Future setVisibilityLayer(
      ThermionEntity entity, VisibilityLayers layer) async {
    RenderableManager_setVisibilityLayer(
        app.renderableManager, entity, layer.value);
  }

  ///
  ///
  ///
  @override
  Future setMorphTargetWeights(
      ThermionEntity entity, List<double> weights) async {
    if (weights.isEmpty) {
      throw Exception("Weights must not be empty");
    }
    var weightsPtr = allocator<Float>(weights.length);

    for (int i = 0; i < weights.length; i++) {
      weightsPtr[i] = weights[i];
    }
    var success = await withBoolCallback((cb) {
      AnimationManager_setMorphTargetWeightsRenderThread(
          animationManager, entity, weightsPtr, weights.length, cb);
    });
    allocator.free(weightsPtr);

    if (!success) {
      throw Exception(
          "Failed to set morph target weights, check logs for details");
    }
  }

  ///
  ///
  ///
  @override
  Future<List<String>> getMorphTargetNames({ThermionEntity? entity}) async {
    var names = <String>[];

    entity ??= this.entity;

    var count = AnimationManager_getMorphTargetNameCount(
        animationManager, asset, entity);
    var outPtr = allocator<Char>(255);
    for (int i = 0; i < count; i++) {
      AnimationManager_getMorphTargetName(
          animationManager, asset, entity, outPtr, i);
      names.add(outPtr.cast<Utf8>().toDartString());
    }
    allocator.free(outPtr);
    return names.cast<String>();
  }

  ///
  ///
  ///
  Future<List<String>> getBoneNames({int skinIndex = 0}) async {
    var count =
        AnimationManager_getBoneCount(animationManager, asset, skinIndex);
    var out = allocator<Pointer<Char>>(count);
    for (int i = 0; i < count; i++) {
      out[i] = allocator<Char>(255);
    }

    AnimationManager_getBoneNames(animationManager, asset, out, skinIndex);
    var names = <String>[];
    for (int i = 0; i < count; i++) {
      var namePtr = out[i];
      names.add(namePtr.cast<Utf8>().toDartString());
    }
    return names;
  }

  ///
  ///
  ///
  @override
  Future<List<String>> getAnimationNames() async {
    var animationCount =
        AnimationManager_getAnimationCount(animationManager, asset);
    var names = <String>[];
    var outPtr = allocator<Char>(255);
    for (int i = 0; i < animationCount; i++) {
      AnimationManager_getAnimationName(animationManager, asset, outPtr, i);
      names.add(outPtr.cast<Utf8>().toDartString());
    }
    allocator.free(outPtr);

    return names;
  }

  ///
  ///
  ///
  @override
  Future<double> getAnimationDuration(int animationIndex) async {
    return AnimationManager_getAnimationDuration(
        animationManager, asset, animationIndex);
  }

  ///
  ///
  ///
  Future<double> getAnimationDurationByName(String name) async {
    var animations = await getAnimationNames();
    var index = animations.indexOf(name);
    if (index == -1) {
      throw Exception("Failed to find animation $name");
    }
    return getAnimationDuration(index);
  }

  ///
  ///
  ///
  Future clearMorphAnimationData(ThermionEntity entity) async {
    if (!AnimationManager_clearMorphAnimation(animationManager, entity)) {
      throw Exception("Failed to clear morph animation");
    }
  }

  ///
  ///
  ///
  @override
  Future setMorphAnimationData(MorphAnimationData animation,
      {List<String>? targetMeshNames}) async {
    var meshEntities = await getChildEntities();

    var meshNames = meshEntities
        .map((e) => FilamentApp.instance!.getNameForEntity(e))
        .toList();
    if (targetMeshNames != null) {
      for (final targetMeshName in targetMeshNames) {
        if (!meshNames.contains(targetMeshName)) {
          throw Exception(
              "Error: mesh ${targetMeshName} does not exist under the specified entity. Available meshes : ${meshNames}");
        }
      }
    }

    // Entities are not guaranteed to have the same morph targets (or share the same order),
    // either from each other, or from those specified in [animation].
    // We therefore set morph targets separately for each mesh.
    // For each mesh, allocate enough memory to hold FxM 32-bit floats
    // (where F is the number of Frames, and M is the number of morph targets in the mesh).
    // we call [extract] on [animation] to return frame data only for morph targets that present in both the mesh and the animation
    for (int i = 0; i < meshNames.length; i++) {
      var meshName = meshNames[i];
      var meshEntity = meshEntities[i];

      if (targetMeshNames?.contains(meshName) == false) {
        // _logger.info("Skipping $meshName, not contained in target");
        continue;
      }

      var meshMorphTargets = await getMorphTargetNames(entity: meshEntity);

      var intersection = animation.morphTargets
          .toSet()
          .intersection(meshMorphTargets.toSet())
          .toList();

      if (intersection.isEmpty) {
        throw Exception(
            """No morph targets specified in animation are present on mesh $meshName. 
            If you weren't intending to animate every mesh, specify [targetMeshNames] when invoking this method.
            Animation morph targets: ${animation.morphTargets}\n
            Mesh morph targets ${meshMorphTargets}
            Child meshes: ${meshNames}""");
      }

      var indices = Uint32List.fromList(
          intersection.map((m) => meshMorphTargets.indexOf(m)).toList());

      // var frameData = animation.data;
      var frameData = animation.subset(intersection);

      assert(
          frameData.data.length == animation.numFrames * intersection.length);

      var result = AnimationManager_setMorphAnimation(
          animationManager,
          meshEntity,
          frameData.data.address,
          indices.address,
          indices.length,
          animation.numFrames,
          animation.frameLengthInMs);

      if (!result) {
        throw Exception("Failed to set morph animation data for ${meshName}");
      }
    }
  }

  ///
  /// Currently, scale is not supported.
  ///
  @override
  Future addBoneAnimation(BoneAnimationData animation,
      {int skinIndex = 0,
      double fadeOutInSecs = 0.0,
      double fadeInInSecs = 0.0,
      double maxDelta = 1.0}) async {
    if (animation.space != Space.Bone &&
        animation.space != Space.ParentWorldRotation) {
      throw UnimplementedError("TODO - support ${animation.space}");
    }
    if (skinIndex != 0) {
      throw UnimplementedError("TODO - support skinIndex != 0 ");
    }
    var boneNames = await getBoneNames();
    var restLocalTransformsRaw = allocator<Float>(boneNames.length * 16);
    AnimationManager_getRestLocalTransforms(animationManager, asset, skinIndex,
        restLocalTransformsRaw, boneNames.length);

    var restLocalTransforms = <Matrix4>[];
    for (int i = 0; i < boneNames.length; i++) {
      var values = <double>[];
      for (int j = 0; j < 16; j++) {
        values.add(restLocalTransformsRaw[(i * 16) + j]);
      }
      restLocalTransforms.add(Matrix4.fromList(values));
    }
    allocator.free(restLocalTransformsRaw);

    var numFrames = animation.frameData.length;

    var data = allocator<Float>(numFrames * 16);

    var bones = await Future.wait(List<Future<ThermionEntity>>.generate(
        boneNames.length, (i) => getBone(i)));

    for (int i = 0; i < animation.bones.length; i++) {
      var boneName = animation.bones[i];
      var entityBoneIndex = boneNames.indexOf(boneName);
      if (entityBoneIndex == -1) {
        _logger.warning("Bone $boneName not found, skipping");
        continue;
      }
      var boneEntity = bones[entityBoneIndex];

      var baseTransform = restLocalTransforms[entityBoneIndex];

      var world = Matrix4.identity();
      // this odd use of ! is intentional, without it, the WASM optimizer gets in trouble
      var parentBoneEntity =
          (await FilamentApp.instance!.getParent(boneEntity))!;
      while (true) {
        if (!bones.contains(parentBoneEntity!)) {
          break;
        }
        world = restLocalTransforms[bones.indexOf(parentBoneEntity!)] * world;
        parentBoneEntity =
            (await FilamentApp.instance!.getParent(parentBoneEntity))!;
      }

      world = Matrix4.identity()..setRotation(world.getRotation());
      var worldInverse = Matrix4.identity()..copyInverse(world);

      for (int frameNum = 0; frameNum < numFrames; frameNum++) {
        var rotation = animation.frameData[frameNum][i].rotation;
        var translation = animation.frameData[frameNum][i].translation;
        var frameTransform =
            Matrix4.compose(translation, rotation, Vector3.all(1.0));
        var newLocalTransform = frameTransform.clone();
        if (animation.space == Space.Bone) {
          newLocalTransform = baseTransform * frameTransform;
        } else if (animation.space == Space.ParentWorldRotation) {
          newLocalTransform =
              baseTransform * (worldInverse * frameTransform * world);
        }
        for (int j = 0; j < 16; j++) {
          data.elementAt((frameNum * 16) + j).value =
              newLocalTransform.storage[j];
        }
      }

      AnimationManager_addBoneAnimation(
          animationManager,
          asset,
          skinIndex,
          entityBoneIndex,
          data,
          numFrames,
          animation.frameLengthInMs,
          fadeOutInSecs,
          fadeInInSecs,
          maxDelta);
    }
    allocator.free(data);
  }

  ///
  ///
  ///
  Future<Matrix4> getLocalTransform({ThermionEntity? entity}) async {
    entity ??= this.entity;
    return double4x4ToMatrix4(
        TransformManager_getLocalTransform(app.transformManager, entity));
  }

  ///
  ///
  ///
  Future<Matrix4> getWorldTransform({ThermionEntity? entity}) async {
    entity ??= this.entity;
    return double4x4ToMatrix4(
        TransformManager_getWorldTransform(app.transformManager, entity));
  }

  ///
  ///
  ///
  Future setTransform(Matrix4 transform, {ThermionEntity? entity}) async {
    entity ??= this.entity;
    TransformManager_setTransform(
        app.transformManager, entity, matrix4ToDouble4x4(transform));
  }

  ///
  ///
  ///
  Future updateBoneMatrices(ThermionEntity entity) async {
    throw UnimplementedError();

    // var result = await withBoolCallback((cb) {
    //   update_bone_matrices_render_thread(_sceneManager!, entity, cb);
    // });
    // if (!result) {
    //   throw Exception("Failed to update bone matrices");
    // }
  }

  ///
  ///
  ///
  Future<Matrix4> getInverseBindMatrix(int boneIndex,
      {int skinIndex = 0}) async {
    var matrix = Float32List(16);
    AnimationManager_getInverseBindMatrix(
        animationManager, asset, skinIndex, boneIndex, matrix.address);
    return Matrix4.fromList(matrix);
  }

  ///
  ///
  ///
  Future<ThermionEntity> getBone(int boneIndex, {int skinIndex = 0}) async {
    if (skinIndex != 0) {
      throw UnimplementedError("TOOD");
    }
    return AnimationManager_getBone(
        animationManager, asset, skinIndex, boneIndex);
  }

  ///
  ///
  ///
  @override
  Future setBoneTransform(
      ThermionEntity entity, int boneIndex, Matrix4 transform,
      {int skinIndex = 0}) async {
    if (skinIndex != 0) {
      throw UnimplementedError("TOOD");
    }
    final ptr = allocator<Float>(16);
    for (int i = 0; i < 16; i++) {
      ptr[i] = transform.storage[i];
    }
    var result = await withBoolCallback((cb) {
      AnimationManager_setBoneTransformRenderThread(
          animationManager, entity, skinIndex, boneIndex, ptr, cb);
    });

    allocator.free(ptr);
    if (!result) {
      throw Exception("Failed to set bone transform");
    }
  }

  ///
  ///
  ///
  ///
  @override
  Future resetBones() async {
    AnimationManager_resetToRestPose(animationManager, asset);
  }

  ///
  ///
  ///
  @override
  Future playAnimation(int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      double startOffset = 0.0}) async {
    AnimationManager_playAnimation(animationManager, asset, index, loop,
        reverse, replaceActive, crossfade, startOffset);
  }

  ///
  ///
  ///
  @override
  Future stopAnimation(int animationIndex) async {
    AnimationManager_stopAnimation(animationManager, asset, animationIndex);
  }

  ///
  ///
  ///
  @override
  Future stopAnimationByName(String name) async {
    var animations = await getAnimationNames();
    await stopAnimation(animations.indexOf(name));
  }

  ///
  ///
  ///
  @override
  Future playAnimationByName(String name,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      bool wait = false}) async {
    var animations = await getAnimationNames();
    var index = animations.indexOf(name);
    var duration = await getAnimationDuration(index);
    await playAnimation(index,
        loop: loop,
        reverse: reverse,
        replaceActive: replaceActive,
        crossfade: crossfade);
    if (wait) {
      await Future.delayed(Duration(milliseconds: (duration * 1000).toInt()));
    }
  }

  ///
  ///
  ///
  @override
  Future setGltfAnimationFrame(int index, int animationFrame) async {
    AnimationManager_setGltfAnimationFrame(
        animationManager, asset, index, animationFrame);
  }

  ///
  ///
  ///
  @override
  Future addAnimationComponent(ThermionEntity entity) async {
    AnimationManager_addAnimationComponent(animationManager, entity);
  }

  ///
  ///
  ///
  Future removeAnimationComponent(ThermionEntity entity) async {
    AnimationManager_removeAnimationComponent(animationManager, entity);
  }
}

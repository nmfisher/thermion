import 'dart:async';

import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:logging/logging.dart';
import 'package:thermion_dart/src/utils/src/matrix.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class FFIAsset extends ThermionAsset {
  
  T getHandle<T>() {
    return asset as T;
  }

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
  bool get isInstance => instanceOwner != null;
  final FFIAsset? instanceOwner;



  ///
  ///
  ///
  late final ThermionEntity entity;

  late final _logger = Logger(this.runtimeType.toString());

  final bool keepData;

  ///
  ///
  ///
  FFIAsset(this.asset, this.app, this.animationManager,
      {this.instanceOwner = null, this.keepData = false}) {
    entity = SceneAsset_getEntity(asset);
  }

  Int32List? _childEntities;

  ///
  ///
  ///
  @override
  Future<List<ThermionEntity>> getChildEntities() async {
    if (_childEntities == null) {
      var count = SceneAsset_getChildEntityCount(asset);

      late Pointer stackPtr;
      if (FILAMENT_WASM) {
        stackPtr = stackSave();
      }
      var childEntities = makeInt32List(count);
      if (count > 0) {
        SceneAsset_getChildEntities(asset, childEntities.address);
      }
      _childEntities = Int32List.fromList(childEntities);

      if (FILAMENT_WASM) {
        stackRestore(stackPtr);
      }
    }

    return _childEntities!;
  }

  ///
  ///
  ///
  @override
  Future<List<String?>> getChildEntityNames() async {
    final childEntities = await getChildEntities();
    var names = <String?>[];
    for (final entity in childEntities) {
      var name = await FilamentApp.instance!.getNameForEntity(entity);
      names.add(name);
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
      var name = FilamentApp.instance!.getNameForEntity(entity);
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
    if(isInstance) {
      return instanceOwner!.createInstance(materialInstances: materialInstances);
    }
    if (!keepData) {
      throw Exception(
          "keepData must have been specified as true when this asset was created");
    }
    var ptrList = IntPtrList(materialInstances?.length ?? 0);
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      //stackPtr = stackSave();
    }

    if (materialInstances != null && materialInstances.isNotEmpty) {
      ptrList.setRange(
          0,
          materialInstances.length,
          materialInstances
              .cast<FFIMaterialInstance>()
              .map((mi) => mi.pointer.address)
              .toList());
    }

    var created = await withPointerCallback<TSceneAsset>((cb) {
      SceneAsset_createInstanceRenderThread(
          asset, ptrList.address.cast(), materialInstances?.length ?? 0, cb);
    });

    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
      ptrList.free();
    }

    if (created == nullptr) {
      throw Exception("Failed to create instance");
    }
    return FFIAsset(created, app, animationManager, instanceOwner: this, keepData: keepData);
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
      _logger.fine("Getting instance at index $i");
      final instance = SceneAsset_getInstance(asset, i);
      if (instance == nullptr) {
        throw Exception("Failed to get asset instance at index $i");
      }
      return FFIAsset(instance, app, animationManager);
    });

    return result;
  }

  ///
  ///
  ///
  Future dispose() async {
    _childEntities?.free();
  }

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
  @override
  Future<MaterialInstance> getMaterialInstanceAt(
      {ThermionEntity? entity, int index = 0}) async {
    if (entity == null) {
      if (RenderableManager_isRenderable(app.renderableManager, this.entity)) {
        entity ??= this.entity;
      } else {
        for (final child in await getChildEntities()) {
          if (RenderableManager_isRenderable(app.renderableManager, child)) {
            entity = child;
            break;
          }
        }
      }
    }

    if (entity == null) {
      throw Exception("Failed to find renderable entity");
    }

    var ptr = RenderableManager_getMaterialInstanceAt(
        Engine_getRenderableManager(app.engine), entity, 0);
    if (ptr == nullptr) {
      throw Exception("Failed to get material instance for asset");
    }
    return FFIMaterialInstance(ptr, app);
  }

  ///
  ///
  ///
  Future setMaterialInstanceForAll(FFIMaterialInstance instance) async {
    for (int i = 0; i < await getPrimitiveCount(entity: entity); i++) {
      if (RenderableManager_isRenderable(app.renderableManager, entity)) {
        await setMaterialInstanceAt(instance,
            entity: entity, primitiveIndex: i);
      }
    }
    for (final entity in await getChildEntities()) {
      if (!RenderableManager_isRenderable(app.renderableManager, entity)) {
        continue;
      }
      for (int i = 0; i < await getPrimitiveCount(entity: entity); i++) {
        await setMaterialInstanceAt(instance,
            entity: entity, primitiveIndex: i);
      }
    }
  }

  ///
  ///
  ///
  Future<Map<ThermionEntity, List<MaterialInstance>>>
      getMaterialInstancesAsMap() async {
    final result = <ThermionEntity, List<MaterialInstance>>{};
    var entities = [entity, ...await getChildEntities()];

    for (final entity in entities) {
      if (RenderableManager_isRenderable(app.renderableManager, entity)) {
        result[entity] = [];
        for (int i = 0; i < await getPrimitiveCount(entity: entity); i++) {
          result[entity]!
              .add(await getMaterialInstanceAt(entity: entity, index: i));
        }
      }
    }
    return result;
  }

  ///
  ///
  ///
  Future setMaterialInstancesFromMap(
      Map<ThermionEntity, List<MaterialInstance>> materialInstances) async {
    for (final entity in materialInstances.keys) {
      if (RenderableManager_isRenderable(app.renderableManager, entity)) {
        for (int i = 0; i < materialInstances[entity]!.length; i++) {
          final mi = materialInstances[entity]![i];
          await setMaterialInstanceAt(mi as FFIMaterialInstance,
              entity: entity, primitiveIndex: i);
        }
      }
    }
  }

  ///
  ///
  ///
  @override
  Future setMaterialInstanceAt(FFIMaterialInstance instance,
      {int? entity = null, int primitiveIndex = 0}) async {
    if (entity != null &&
        !RenderableManager_isRenderable(app.renderableManager, entity)) {
      _logger.warning("Provided entity is not renderable");
      return;
    }

    if (entity == null) {
      if (RenderableManager_isRenderable(app.renderableManager, this.entity)) {
        entity ??= this.entity;
      } else {
        for (final child in await getChildEntities()) {
          if (RenderableManager_isRenderable(app.renderableManager, child)) {
            entity = child;
            break;
          }
        }
      }
    }

    if (entity == null) {
      throw Exception("Failed to find renderable entity");
    }

    if (!RenderableManager_setMaterialInstanceAt(
        Engine_getRenderableManager(app.engine),
        entity,
        primitiveIndex,
        instance.pointer)) {
      _logger.warning(
          "Failed to set material instance for entity $entity at primitive index ${primitiveIndex}");
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
    if (!TransformManager_transformToUnitCube(
        app.transformManager, entity, SceneAsset_getBoundingBox(asset))) {
      throw Exception("Failed to set transform. See logs for details");
    }
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
    var weightsF32 = Float32List.fromList(weights);

    var success = await withBoolCallback((cb) {
      AnimationManager_setMorphTargetWeightsRenderThread(
          animationManager, entity, weightsF32.address, weights.length, cb);
    });
    weightsF32.free();

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

    if (count < 0) {
      throw Exception("Failed to retrieve morph target name count");
    }
    var outPtr = allocate<Char>(255);
    for (int i = 0; i < count; i++) {
      AnimationManager_getMorphTargetName(
          animationManager, asset, entity, outPtr, i);
      names.add(outPtr.cast<Utf8>().toDartString());
    }
    free(outPtr);
    return names.cast<String>();
  }

  ///
  ///
  ///
  Future<List<String>> getBoneNames({int skinIndex = 0}) async {
    var count =
        AnimationManager_getBoneCount(animationManager, asset, skinIndex);
    var out = allocate<PointerClass<Char>>(count);
    for (int i = 0; i < count; i++) {
      out[i] = allocate<Char>(255);
    }

    AnimationManager_getBoneNames(animationManager, asset, out, skinIndex);
    var names = <String>[];
    for (int i = 0; i < count; i++) {
      var namePtr = out[i];
      names.add(namePtr.cast<Utf8>().toDartString());
    }
    for (int i = 0; i < count; i++) {
      free(out[i]);
    }
    free(out);
    return names;
  }

  List<String>? _gltfAnimationNames;

  ///
  ///
  ///
  @override
  Future<List<String>> getGltfAnimationNames() async {
    if (_gltfAnimationNames == null) {
      var animationCount =
          AnimationManager_getGltfAnimationCount(animationManager, asset);
      if (animationCount == -1) {
        throw Exception("This is not a glTF asset");
      }
      _gltfAnimationNames = [];
      var outPtr = allocate<Char>(255);
      for (int i = 0; i < animationCount; i++) {
        AnimationManager_getGltfAnimationName(
            animationManager, asset, outPtr, i);
        _gltfAnimationNames!.add(outPtr.cast<Utf8>().toDartString());
      }
      free(outPtr);
    }

    return _gltfAnimationNames!;
  }

  ///
  ///
  ///
  @override
  Future<double> getGltfAnimationDuration(int animationIndex) async {
    final duration = AnimationManager_getGltfAnimationDuration(
        animationManager, asset, animationIndex);
    if (duration < 0) {
      throw Exception("Failed to get glTF animation duration");
    }
    return duration;
  }

  ///
  ///
  ///
  Future<double> getAnimationDurationByName(String name) async {
    var animations = await getGltfAnimationNames();
    var index = animations.indexOf(name);
    if (index == -1) {
      throw Exception("Failed to find animation $name");
    }
    return getGltfAnimationDuration(index);
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

      frameData.data.free();
      indices.free();

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
    var restLocalTransformsRaw = allocate<Float>(boneNames.length * 16);
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
    free(restLocalTransformsRaw);

    var numFrames = animation.frameData.length;

    var data = allocate<Float>(numFrames * 16);

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
          data[(frameNum * 16) + j] = newLocalTransform.storage[j];
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
    free(data);
  }

  ///
  ///
  ///
  Future<Matrix4> getLocalTransform({ThermionEntity? entity}) async {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }
    entity ??= this.entity;
    final transform = double4x4ToMatrix4(
        TransformManager_getLocalTransform(app.transformManager, entity));
    if (FILAMENT_WASM) {
      stackRestore(stackPtr);
    }
    return transform;
  }

  ///
  ///
  ///
  Future<Matrix4> getWorldTransform({ThermionEntity? entity}) async {
    return FilamentApp.instance!.getWorldTransform(entity ?? this.entity);
  }

  ///
  ///
  ///
  Future setTransform(Matrix4 transform, {ThermionEntity? entity}) async {
    await FilamentApp.instance!.setTransform(entity ?? this.entity, transform);
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
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      //stackPtr = stackSave();
    }
    var matrixIn = Float32List(16);
    AnimationManager_getInverseBindMatrix(
        animationManager, asset, skinIndex, boneIndex, matrixIn.address);
    var matrixOut = Matrix4.fromList(matrixIn);
    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
      matrixIn.free();
    }
    return matrixOut;
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
    final ptr = allocate<Float>(16);
    for (int i = 0; i < 16; i++) {
      ptr[i] = transform.storage[i];
    }
    var result = await withBoolCallback((cb) {
      AnimationManager_setBoneTransformRenderThread(
          animationManager, entity, skinIndex, boneIndex, ptr, cb);
    });

    free(ptr);
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
    await withVoidCallback((requestId, cb) =>
        AnimationManager_resetToRestPoseRenderThread(
            animationManager, asset, requestId, cb));
  }

  ///
  ///
  ///
  @override
  Future playGltfAnimation(int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      double startOffset = 0.0}) async {
    if (!AnimationManager_playGltfAnimation(animationManager, asset, index,
        loop, reverse, replaceActive, crossfade, startOffset)) {
      throw Exception("Failed to play glTF animation. Check logs for details");
    }
  }

  ///
  ///
  ///
  @override
  Future stopGltfAnimation(int animationIndex) async {
    if (!AnimationManager_stopGltfAnimation(
        animationManager, asset, animationIndex)) {
      throw Exception("Failed to stop glTF animation. Check logs for details");
    }
  }

  ///
  ///
  ///
  @override
  Future stopGltfAnimationByName(String name) async {
    var animations = await getGltfAnimationNames();
    await stopGltfAnimation(animations.indexOf(name));
  }

  ///
  ///
  ///
  @override
  Future playGltfAnimationByName(String name,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      bool wait = false}) async {
    var animations = await getGltfAnimationNames();
    var index = animations.indexOf(name);
    var duration = await getGltfAnimationDuration(index);
    await playGltfAnimation(index,
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
  Future addAnimationComponent() async {
    AnimationManager_addGltfAnimationComponent(animationManager, this.asset);
  }

  ///
  ///
  ///
  Future removeAnimationComponent() async {
    if (!AnimationManager_removeGltfAnimationComponent(
        animationManager, asset)) {
      _logger.warning("Failed to remove glTF animation component");
    }
    if (!AnimationManager_removeBoneAnimationComponent(
        animationManager, asset)) {
      _logger.warning("Failed to remove bone animation component");
    }
    AnimationManager_removeMorphAnimationComponent(animationManager, entity);

    for (final child in await getChildEntities()) {
      AnimationManager_removeMorphAnimationComponent(animationManager, child);
    }
  }

  ///
  ///
  ///
  Future<int> getPrimitiveCount({ThermionEntity? entity}) async {
    return FilamentApp.instance!.getPrimitiveCount(entity ??= this.entity);
  }
  
  ///
  ///
  ///
  @override
  Future<bool> containsChild(ThermionEntity entity) async {
    return (await getChildEntities()).contains(entity);
  }
}

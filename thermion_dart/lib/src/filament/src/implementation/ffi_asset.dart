import 'dart:async';

import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class FFIAsset extends ThermionAsset<Pointer<TSceneAsset>> {
  final Pointer<TSceneAsset> asset;

  Pointer<TSceneAsset> getNativeHandle() {
    return asset;
  }

  ///
  bool get isInstance => instanceOwner != null;
  final FFIAsset? instanceOwner;

  ///
  late final ThermionEntity entity;

  late final _logger = Logger(this.runtimeType.toString());

  final bool releaseSourceData;

  //
  FFIAsset(this.asset,
      {this.instanceOwner = null, this.releaseSourceData = false}) {
    entity = SceneAsset_getEntity(asset);
  }

  Int32List? _childEntities;

  //
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

  //
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

  //
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

  //
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
    return FFIAsset(instance);
  }

  //
  @override
  Future<FFIAsset> createInstance(
      {List<MaterialInstance>? materialInstances = null}) async {
    if (isInstance) {
      return instanceOwner!
          .createInstance(materialInstances: materialInstances);
    }
    if (releaseSourceData) {
      throw Exception("""releaseSourceData must have been specified as false"""
          """ when this asset was created""");
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
    return FFIAsset(created,
        instanceOwner: this, releaseSourceData: releaseSourceData);
  }

  //
  @override
  Future<int> getInstanceCount() async {
    return SceneAsset_getInstanceCount(asset);
  }

  //
  @override
  Future<List<ThermionAsset>> getInstances() async {
    var count = await getInstanceCount();
    final result = List<ThermionAsset>.generate(count, (i) {
      _logger.fine("Getting instance at index $i");
      final instance = SceneAsset_getInstance(asset, i);
      if (instance == nullptr) {
        throw Exception("Failed to get asset instance at index $i");
      }
      return FFIAsset(instance);
    });

    return result;
  }

  //
  Future dispose() async {
    _childEntities?.free();
  }

  //
  Future<v64.Aabb3> getBoundingBox() async {
    final entities = <ThermionEntity>[];
    if (FilamentApp.instance!.renderableManager.isRenderable(entity)) {
      entities.add(entity);
    } else {
      entities.addAll(await getChildEntities());
    }

    var boundingBox = v64.Aabb3();

    for (final entity in entities) {
      final aabb3 =
          FilamentApp.instance!.renderableManager.getBoundingBox(entity);
      boundingBox.hull(aabb3);
    }
    return boundingBox;
  }

  //
  @override
  Future<MaterialInstance> getMaterialInstanceAt(
      {ThermionEntity? entity, int index = 0}) async {
    if (entity == null) {
      if (FilamentApp.instance!.renderableManager.isRenderable(this.entity)) {
        entity ??= this.entity;
      } else {
        for (final child in await getChildEntities()) {
          if (FilamentApp.instance!.renderableManager.isRenderable(child)) {
            entity = child;
            break;
          }
        }
      }
    }

    if (entity == null) {
      throw Exception("Failed to find renderable entity");
    }

    var instance = await FilamentApp.instance!.renderableManager
        .getMaterialInstanceAt(entity, 0);
    if (instance == null) {
      throw Exception("Failed to get material instance for asset");
    }
    return instance;
  }

  //
  Future setMaterialInstanceForAll(FFIMaterialInstance instance) async {
    for (int i = 0; i < await getPrimitiveCount(entity: entity); i++) {
      if (FilamentApp.instance!.renderableManager.isRenderable(entity)) {
        await setMaterialInstanceAt(instance,
            entity: entity, primitiveIndex: i);
      }
    }
    for (final entity in await getChildEntities()) {
      if (!FilamentApp.instance!.renderableManager.isRenderable(entity)) {
        continue;
      }
      for (int i = 0; i < await getPrimitiveCount(entity: entity); i++) {
        await setMaterialInstanceAt(instance,
            entity: entity, primitiveIndex: i);
      }
    }
    // When called on the root asset, propagate to all instances.
    if (!isInstance) {
      for (final inst in await getInstances()) {
        await (inst as FFIAsset).setMaterialInstanceForAll(instance);
      }
    }
  }

  @override
  Future setFlatShading(bool flatShading) async {
    await withVoidCallback((requestId, cb) =>
        SceneAsset_setFlatShadingRenderThread(
            asset, flatShading, requestId, cb));
  }

  //
  Future<Map<ThermionEntity, List<MaterialInstance>>>
      getMaterialInstancesAsMap() async {
    final result = <ThermionEntity, List<MaterialInstance>>{};
    var entities = [entity, ...await getChildEntities()];

    for (final entity in entities) {
      if (FilamentApp.instance!.renderableManager.isRenderable(entity)) {
        result[entity] = [];
        for (int i = 0; i < await getPrimitiveCount(entity: entity); i++) {
          result[entity]!
              .add(await getMaterialInstanceAt(entity: entity, index: i));
        }
      }
    }
    return result;
  }

  //
  Future setMaterialInstancesFromMap(
      Map<ThermionEntity, List<MaterialInstance>> materialInstances) async {
    for (final entity in materialInstances.keys) {
      if (FilamentApp.instance!.renderableManager.isRenderable(entity)) {
        for (int i = 0; i < materialInstances[entity]!.length; i++) {
          final mi = materialInstances[entity]![i];
          await setMaterialInstanceAt(mi as FFIMaterialInstance,
              entity: entity, primitiveIndex: i);
        }
      }
    }
  }

  //
  @override
  Future setMaterialInstanceAt(MaterialInstance instance,
      {int? entity = null, int primitiveIndex = 0}) async {
    if (entity != null &&
        !FilamentApp.instance!.renderableManager.isRenderable(entity)) {
      _logger.warning("Provided entity is not renderable");
      return;
    }

    if (entity == null) {
      if (FilamentApp.instance!.renderableManager.isRenderable(this.entity)) {
        entity ??= this.entity;
      } else {
        for (final child in await getChildEntities()) {
          if (FilamentApp.instance!.renderableManager.isRenderable(child)) {
            entity = child;
            break;
          }
        }
      }
    }

    if (entity == null) {
      throw Exception("Failed to find renderable entity");
    }

    if (!await FilamentApp.instance!.renderableManager
        .setMaterialInstanceAt(entity, primitiveIndex, instance)) {
      _logger.warning(
          "Failed to set material instance for entity $entity at primitive index ${primitiveIndex}");
    }
  }

  //
  Future setCastShadows(bool castShadows) async {
    await FilamentApp.instance!.renderableManager
        .setCastShadows(this.entity, castShadows);
    for (final entity in await this.getChildEntities()) {
      await FilamentApp.instance!.renderableManager
          .setCastShadows(entity, castShadows);
    }
  }

  //
  Future setReceiveShadows(bool receiveShadows) async {
    await FilamentApp.instance!.renderableManager
        .setReceiveShadows(this.entity, receiveShadows);
    for (final entity in await this.getChildEntities()) {
      await FilamentApp.instance!.renderableManager
          .setReceiveShadows(entity, receiveShadows);
    }
  }

  //
  Future<bool> isCastShadowsEnabled({ThermionEntity? entity}) async {
    entity ??= this.entity;
    return FilamentApp.instance!.renderableManager.isShadowCaster(entity);
  }

  //
  Future<bool> isReceiveShadowsEnabled({ThermionEntity? entity}) async {
    entity ??= this.entity;
    return FilamentApp.instance!.renderableManager.isShadowReceiver(entity);
  }

  //
  Future transformToUnitCube() async {
    FilamentApp.instance!.transformManager
        .transformToUnitCube(entity, await getBoundingBox());
  }

  //
  Future setVisibilityLayer(
      ThermionEntity entity, VisibilityLayers layer) async {
    await FilamentApp.instance!.renderableManager
        .setVisibilityLayer(entity, layer.value);
  }

  //
  @override
  Future setMorphTargetWeights(
      ThermionEntity entity, List<double> weights) async {
    if (weights.isEmpty) {
      throw Exception("Weights must not be empty");
    }

    final success = FilamentApp.instance!.animationManager
        .setMorphTargetWeights(entity, weights);
    if (!success) {
      throw Exception(
          "Failed to set morph target weights, check logs for details");
    }
  }

  //
  @override
  Future<List<String>> getMorphTargetNames({ThermionEntity? entity}) async {
    entity ??= this.entity;

    var names = <String>[];
    var count = FilamentApp.instance!.animationManager
        .getMorphTargetNameCount(this, entity);

    for (int i = 0; i < count; i++) {
      final name = FilamentApp.instance!.animationManager
          .getMorphTargetName(this, entity, i);
      if (name != null) {
        names.add(name);
      }
    }
    return names;
  }

  //
  Future<List<String>> getBoneNames({int skinIndex = 0}) async {
    var boneCount = await getBoneCount(skinIndex: skinIndex);
    var names = <String>[];
    for (int i = 0; i < boneCount; i++) {
      var boneName = SceneAsset_getBoneName(asset, skinIndex, i);
      if (boneName == nullptr) {
        names.add("");
      } else {
        names.add(boneName.cast<Utf8>().toDartString());
      }
    }
    return names;
  }

  /// Gets the number of bones in a skin.
  ///
  /// [asset] The asset containing the skin
  /// [skinIndex] The skin index
  /// Returns the number of bones, or 0 if not found
  Future<int> getBoneCount({int skinIndex = 0}) async {
    return SceneAsset_getBoneCount(asset, skinIndex);
  }

  List<String>? _gltfAnimationNames;

  //
  @override
  Future<List<String>> getGltfAnimationNames() async {
    if (_gltfAnimationNames == null) {
      var animationCount =
          FilamentApp.instance!.animationManager.getGltfAnimationCount(this);
      if (animationCount <= 0) {
        throw Exception("This is not a glTF asset");
      }
      _gltfAnimationNames = [];
      for (int i = 0; i < animationCount; i++) {
        final name = FilamentApp.instance!.animationManager
            .getGltfAnimationName(this, i);
        if (name != null) {
          _gltfAnimationNames!.add(name);
        }
      }
    }

    return _gltfAnimationNames!;
  }

  //
  @override
  Future<double> getGltfAnimationDuration(int animationIndex) async {
    final duration = FilamentApp.instance!.animationManager
        .getGltfAnimationDuration(this, animationIndex);
    return duration;
  }

  //
  Future<double> getAnimationDurationByName(String name) async {
    var animations = await getGltfAnimationNames();
    var index = animations.indexOf(name);
    if (index == -1) {
      throw Exception("Failed to find animation $name");
    }
    return getGltfAnimationDuration(index);
  }

  //
  Future clearMorphAnimationData(ThermionEntity entity) async {
    if (!FilamentApp.instance!.animationManager.clearMorphAnimation(entity)) {
      throw Exception("Failed to clear morph animation");
    }
  }

  //
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
              """Mesh ${targetMeshName} does not exist under the specified entity."""
              """Available meshes : ${meshNames}""");
        }
      }
    }

    // Entities are not guaranteed to have the same morph targets (or share the
    // same order), either from each other, or from those specified in
    // [animation]. We therefore set morph targets separately for each mesh. For
    // each mesh, allocate enough memory to hold FxM 32-bit floats (where F is
    // the number of Frames, and M is the number of morph targets in the mesh).
    // we call [extract] on [animation] to return frame data only for morph
    // targets that present in both the mesh and the animation
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

      var result = FilamentApp.instance!.animationManager.setMorphAnimation(
          meshEntity,
          frameData.data,
          indices,
          intersection.length,
          animation.numFrames,
          animation.frameLengthInMs);

      frameData.data.free();
      indices.free();

      if (!result) {
        throw Exception("Failed to set morph animation data for ${meshName}");
      }
    }
  }

  /// Currently, scale is not supported.
  ///
  @override
  Future addBoneAnimation(BoneAnimationData animation,
      {int skinIndex = 0,
      double fadeOutInSecs = 0.0,
      double fadeInInSecs = 0.0,
      double maxDelta = 1.0,
      bool loop = false}) async {
    if (animation.space != Space.Bone &&
        animation.space != Space.ParentWorldRotation) {
      throw UnimplementedError("TODO - support ${animation.space}");
    }
    if (skinIndex != 0) {
      throw UnimplementedError("TODO - support skinIndex != 0 ");
    }
    // Resolve to instance(0) if this is a top-level asset — the native
    // bone APIs (getBoneCount, getBone, getRestLocalTransforms) require
    // a GltfSceneAssetInstance, not a GltfSceneAsset.
    FFIAsset instanceAsset = this;
    if (!isInstance) {
      try {
        instanceAsset = (await getInstance(0)) as FFIAsset;
      } catch (_) {
        // Fall through with self
      }
    }
    var boneNames = await instanceAsset.getBoneNames(skinIndex: skinIndex);
    var restLocalTransformsData = await FilamentApp.instance!.animationManager
        .getRestLocalTransforms(instanceAsset, skinIndex);
    var restLocalTransforms = <Matrix4>[];
    for (int i = 0; i < boneNames.length; i++) {
      var values = <double>[];
      for (int j = 0; j < 16; j++) {
        values.add(restLocalTransformsData[(i * 16) + j]);
      }
      restLocalTransforms.add(Matrix4.fromList(values));
    }

    var numFrames = animation.frameData.length;

    var data = allocate<Float>(numFrames * 16);

    var bones = await Future.wait(List<Future<ThermionEntity>>.generate(
        boneNames.length, (i) => instanceAsset.getBone(i)));

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

      var frameDataList = <double>[];
      for (int i = 0; i < numFrames * 16; i++) {
        frameDataList.add(data[i]);
      }

      FilamentApp.instance!.animationManager.addBoneAnimation(this, skinIndex,
          entityBoneIndex, frameDataList, numFrames, animation.frameLengthInMs,
          fadeOutInSecs: fadeOutInSecs,
          fadeInInSecs: fadeInInSecs,
          maxDelta: maxDelta,
          loop: loop);
    }
    free(data);
  }

  ///
  Future<Matrix4> getLocalTransform({ThermionEntity? entity}) async {
    entity ??= this.entity;
    final transform =
        FilamentApp.instance!.transformManager.getLocalTransform(entity);
    return transform;
  }

  ///
  Future<Matrix4> getWorldTransform({ThermionEntity? entity}) async {
    return FilamentApp.instance!.getWorldTransform(entity ?? this.entity);
  }

  ///
  Future setTransform(Matrix4 transform, {ThermionEntity? entity}) async {
    await FilamentApp.instance!.setTransform(entity ?? this.entity, transform);
  }

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

  //
  Future<Matrix4> getInverseBindMatrix(int boneIndex,
      {int skinIndex = 0}) async {
    if (!isInstance) {
      print(await getInstance(0));
      throw Exception(
          "getInverseBindMatrix can only be called on an instance of an asset");
    }
    var matrixData = FilamentApp.instance!.animationManager
        .getInverseBindMatrix(this, skinIndex, boneIndex);
    var matrixOut = Matrix4.fromList(matrixData);
    return matrixOut;
  }

  //
  Future<List<ThermionEntity>> getBones({int skinIndex = 0}) async {
    if (skinIndex != 0) {
      throw UnimplementedError("TOOD");
    }
    final out = makeInt32List(await getBoneCount(skinIndex: skinIndex));
    SceneAsset_getBones(asset, skinIndex, out.address);
    return out;
  }

  //
  @override
  Future setBoneTransform(int boneIndex, Matrix4 transform,
      {ThermionEntity? entity, int skinIndex = 0}) async {
    if (skinIndex != 0) {
      throw UnimplementedError("TODO - support skinIndex != 0");
    }
    final renderableManager = FilamentApp.instance!.renderableManager;

    ThermionEntity? meshEntity = entity;
    if (meshEntity == null) {
      if (renderableManager.isRenderable(this.entity)) {
        meshEntity = this.entity;
      } else {
        for (final child in await getChildEntities()) {
          if (renderableManager.isRenderable(child)) {
            meshEntity = child;
            break;
          }
        }
      }
      if (meshEntity == null) {
        throw Exception(
            "Could not find a renderable (skinned mesh) entity for this asset");
      }
    } else if (!renderableManager.isRenderable(meshEntity)) {
      throw Exception(
          "Entity $meshEntity is not a renderable; setBoneTransform must "
          "target a skinned mesh entity, not the glTF root or a bone entity");
    }

    await renderableManager
        .setBones(meshEntity, [transform], offset: boneIndex);
  }

  //
  @override
  Future resetBones() async {
    FilamentApp.instance!.animationManager.resetToRestPose(this);
  }

  //
  @override
  Future playGltfAnimation(int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      double startOffset = 0.0,
      double speed = 1.0}) async {
    final success = FilamentApp.instance!.animationManager.playGltfAnimation(
        this, index,
        loop: loop,
        reverse: reverse,
        replaceActive: replaceActive,
        crossfade: crossfade,
        startOffset: startOffset,
        speed: speed);
    if (!success) {
      throw Exception("Failed to play glTF animation. Check logs for details");
    }
  }

  //
  @override
  Future stopGltfAnimation(int animationIndex) async {
    final success = FilamentApp.instance!.animationManager
        .stopGltfAnimation(this, animationIndex);
    if (!success) {
      throw Exception("Failed to stop glTF animation. Check logs for details");
    }
  }

  //
  @override
  Future stopGltfAnimationByName(String name) async {
    var animations = await getGltfAnimationNames();
    await stopGltfAnimation(animations.indexOf(name));
  }

  //
  @override
  Future playGltfAnimationByName(String name,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      double speed = 1.0,
      bool wait = false}) async {
    var animations = await getGltfAnimationNames();
    var index = animations.indexOf(name);
    var duration = await getGltfAnimationDuration(index);
    await playGltfAnimation(index,
        loop: loop,
        reverse: reverse,
        replaceActive: replaceActive,
        crossfade: crossfade,
        speed: speed);
    if (wait) {
      await Future.delayed(Duration(milliseconds: (duration * 1000).toInt()));
    }
  }

  //
  @override
  Future setGltfAnimationTime(int index, double timeInSeconds) async {
    FilamentApp.instance!.animationManager
        .setGltfAnimationTime(this, index, timeInSeconds);
  }

  //
  @override
  Future addAnimationComponent() async {
    FilamentApp.instance!.animationManager.addGltfAnimationComponent(this);
  }

  //
  Future removeAnimationComponent() async {
    if (!FilamentApp.instance!.animationManager
        .removeGltfAnimationComponent(this)) {
      _logger.warning("Failed to remove glTF animation component");
    }
    if (!FilamentApp.instance!.animationManager
        .removeBoneAnimationComponent(this)) {
      _logger.warning("Failed to remove bone animation component");
    }
    FilamentApp.instance!.animationManager
        .removeMorphAnimationComponent(entity);

    for (final child in await getChildEntities()) {
      FilamentApp.instance!.animationManager
          .removeMorphAnimationComponent(child);
    }
  }

  //
  Future<int> getPrimitiveCount({ThermionEntity? entity}) async {
    return FilamentApp.instance!.getPrimitiveCount(entity ??= this.entity);
  }

  //
  @override
  Future<bool> containsChild(ThermionEntity entity) async {
    return (await getChildEntities()).contains(entity);
  }

  @override
  VertexBuffer? getVertexBuffer({int primitiveIndex = 0}) {
    final vbPtr = SceneAsset_getVertexBuffer(asset, primitiveIndex);
    if (vbPtr == nullptr) {
      return null;
    }
    return FFIVertexBuffer(vbPtr, FilamentApp.instance!.engine);
  }
}

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class FFIAsset extends ThermionAsset<Pointer<TSceneAsset>> {
  late final _logger = Logger(this.runtimeType.toString());

  final Pointer<TSceneAsset> asset;

  Pointer<TSceneAsset> getNativeHandle() {
    return asset;
  }

  bool get isInstance => instanceOwner != null;

  final FFIAsset? instanceOwner;

  late final ThermionEntity entity;

  // Mutable only on the owning asset. Instance wrappers read the owner's value
  // through [_sourceDataReleased] rather than carrying their own copy, so the
  // state can never diverge.
  bool _released = false;

  // The owning asset's released state; on an instance this reads through to
  // the instance owner.
  bool get _sourceDataReleased => isInstance ? instanceOwner!._sourceDataReleased : _released;

  final FFIFilamentApp _app;

  FFIAsset(this.asset, {this.instanceOwner = null, required FFIFilamentApp app}) : _app = app {
    entity = SceneAsset_getEntity(asset);
  }

  @override
  SceneAssetType get type {
    final t = SceneAsset_getType(asset);
    switch (t) {
      case TSceneAssetType.SCENE_ASSET_TYPE_GLTF:
        return SceneAssetType.gltf;
      case TSceneAssetType.SCENE_ASSET_TYPE_GEOMETRY:
        return SceneAssetType.geometry;
      case TSceneAssetType.SCENE_ASSET_TYPE_LIGHT:
        return SceneAssetType.light;
      case TSceneAssetType.SCENE_ASSET_TYPE_SKYBOX:
        return SceneAssetType.skybox;
      case TSceneAssetType.SCENE_ASSET_TYPE_IBL:
        return SceneAssetType.ibl;
      case TSceneAssetType.SCENE_ASSET_TYPE_IMAGE:
        return SceneAssetType.image;
      case TSceneAssetType.SCENE_ASSET_TYPE_GIZMO:
        return SceneAssetType.gizmo;
      default:
        throw Exception("Unknown SceneAssetType: $t");
    }
  }

  // childEntities are (currently) immutable, so we cache them here.
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
      var name = await _app.getNameForEntity(entity);
      names.add(name);
    }
    return names;
  }

  //
  @override
  Future<ThermionEntity?> getChildEntity(String childName) async {
    final childEntities = await getChildEntities();
    for (final entity in childEntities) {
      var name = _app.getNameForEntity(entity);
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
        """This is itself an instance. Call getInstance on the """
        """original asset that this instance was created from""",
      );
    }
    var instance = SceneAsset_getInstance(asset, index);
    if (instance == nullptr) {
      throw Exception("No instance available at index $index");
    }
    return FFIAsset(instance, instanceOwner: this, app: _app);
  }

  //
  @override
  Future<FFIAsset> createInstance({List<MaterialInstance>? materialInstances = null}) async {
    if (isInstance) {
      return instanceOwner!.createInstance(materialInstances: materialInstances);
    }
    if (_sourceDataReleased) {
      throw Exception(
        """Cannot create instance: the asset's glTF source data has been """
        """released (via releaseSourceData: true at load time or a prior """
        """call to releaseSourceData())""",
      );
    }
    var ptrList = IntPtrList(materialInstances?.length ?? 0);

    if (materialInstances != null && materialInstances.isNotEmpty) {
      ptrList.setRange(
        0,
        materialInstances.length,
        materialInstances.cast<FFIMaterialInstance>().map((mi) => mi.pointer.address).toList(),
      );
    }

    var created = await withPointerCallback<TSceneAsset>((cb) {
      SceneAsset_createInstanceRenderThread(asset, ptrList.address.cast(), materialInstances?.length ?? 0, cb);
    });

    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
      ptrList.free();
    }

    if (created == nullptr) {
      throw Exception("Failed to create instance");
    }
    return FFIAsset(created, instanceOwner: this, app: _app);
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
      return FFIAsset(instance, instanceOwner: this, app: _app);
    });

    return result;
  }

  //
  @override
  Future releaseSourceData() async {
    if (isInstance) {
      throw StateError("releaseSourceData must be called on the owning asset, not an instance");
    }
    if (type != SceneAssetType.gltf) {
      throw StateError("releaseSourceData is only supported on glTF assets");
    }
    if (_sourceDataReleased) {
      throw StateError("The asset's glTF source data has already been released");
    }
    await withVoidCallback((requestId, cb) => SceneAsset_releaseSourceDataRenderThread(asset, requestId, cb));
    _released = true;
  }

  //
  Future dispose() async {
    _childEntities?.free();
  }

  //
  Future<v64.Aabb3> getBoundingBox() async {
    final entities = <ThermionEntity>[];
    if (_app.renderableManager.isRenderable(entity)) {
      entities.add(entity);
    } else {
      entities.addAll(await getChildEntities());
    }

    var boundingBox = v64.Aabb3();

    for (final entity in entities) {
      final aabb3 = _app.renderableManager.getBoundingBox(entity);
      boundingBox.hull(aabb3);
    }
    return boundingBox;
  }

  //
  @override
  Future<MaterialInstance> getMaterialInstanceAt({ThermionEntity? entity, int index = 0}) async {
    if (entity == null) {
      if (_app.renderableManager.isRenderable(this.entity)) {
        entity ??= this.entity;
      } else {
        for (final child in await getChildEntities()) {
          if (_app.renderableManager.isRenderable(child)) {
            entity = child;
            break;
          }
        }
      }
    }

    if (entity == null) {
      throw Exception("Failed to find renderable entity");
    }

    var instance = await _app.renderableManager.getMaterialInstanceAt(entity, 0);
    if (instance == null) {
      throw Exception("Failed to get material instance for asset");
    }
    return instance;
  }

  //
  Future setMaterialInstanceForAll(FFIMaterialInstance instance) async {
    for (int i = 0; i < await getPrimitiveCount(entity: entity); i++) {
      if (_app.renderableManager.isRenderable(entity)) {
        await setMaterialInstanceAt(instance, entity: entity, primitiveIndex: i);
      }
    }
    for (final entity in await getChildEntities()) {
      if (!_app.renderableManager.isRenderable(entity)) {
        continue;
      }
      for (int i = 0; i < await getPrimitiveCount(entity: entity); i++) {
        await setMaterialInstanceAt(instance, entity: entity, primitiveIndex: i);
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
    // Flat shading swaps TANGENTS on the preserved (rebuilt) vertex buffers;
    // without them it would silently do nothing — throw instead.
    if (getVertexBuffer() == null) {
      throw Exception(
        "setFlatShading: asset has no preserved geometry. "
        "Load it with loadGltf(..., rebuildVertices: true).",
      );
    }
    await withVoidCallback((requestId, cb) => SceneAsset_setFlatShadingRenderThread(asset, flatShading, requestId, cb));
  }

  //
  Future<Map<ThermionEntity, List<MaterialInstance>>> getMaterialInstancesAsMap() async {
    final result = <ThermionEntity, List<MaterialInstance>>{};
    var entities = [entity, ...await getChildEntities()];

    for (final entity in entities) {
      if (_app.renderableManager.isRenderable(entity)) {
        result[entity] = [];
        for (int i = 0; i < await getPrimitiveCount(entity: entity); i++) {
          result[entity]!.add(await getMaterialInstanceAt(entity: entity, index: i));
        }
      }
    }
    return result;
  }

  //
  Future setMaterialInstancesFromMap(Map<ThermionEntity, List<MaterialInstance>> materialInstances) async {
    for (final entity in materialInstances.keys) {
      if (_app.renderableManager.isRenderable(entity)) {
        for (int i = 0; i < materialInstances[entity]!.length; i++) {
          final mi = materialInstances[entity]![i];
          await setMaterialInstanceAt(mi as FFIMaterialInstance, entity: entity, primitiveIndex: i);
        }
      }
    }
  }

  //
  @override
  Future setMaterialInstanceAt(MaterialInstance instance, {int? entity = null, int primitiveIndex = 0}) async {
    if (entity != null && !_app.renderableManager.isRenderable(entity)) {
      _logger.warning("Provided entity is not renderable");
      return;
    }

    if (entity == null) {
      if (_app.renderableManager.isRenderable(this.entity)) {
        entity ??= this.entity;
      } else {
        for (final child in await getChildEntities()) {
          if (_app.renderableManager.isRenderable(child)) {
            entity = child;
            break;
          }
        }
      }
    }

    if (entity == null) {
      throw Exception("Failed to find renderable entity");
    }

    if (!await _app.renderableManager.setMaterialInstanceAt(entity, primitiveIndex, instance)) {
      _logger.warning("Failed to set material instance for entity $entity at primitive index ${primitiveIndex}");
    }
  }

  //
  Future setCastShadows(bool castShadows) async {
    await _app.renderableManager.setCastShadows(this.entity, castShadows);
    for (final entity in await this.getChildEntities()) {
      await _app.renderableManager.setCastShadows(entity, castShadows);
    }
  }

  //
  Future setReceiveShadows(bool receiveShadows) async {
    await _app.renderableManager.setReceiveShadows(this.entity, receiveShadows);
    for (final entity in await this.getChildEntities()) {
      await _app.renderableManager.setReceiveShadows(entity, receiveShadows);
    }
  }

  //
  Future<bool> isCastShadowsEnabled({ThermionEntity? entity}) async {
    entity ??= this.entity;
    return _app.renderableManager.isShadowCaster(entity);
  }

  //
  Future<bool> isReceiveShadowsEnabled({ThermionEntity? entity}) async {
    entity ??= this.entity;
    return _app.renderableManager.isShadowReceiver(entity);
  }

  //
  Future transformToUnitCube() async {
    _app.transformManager.transformToUnitCube(entity, await getBoundingBox());
  }

  //
  Future setVisibilityLayer(ThermionEntity entity, VisibilityLayers layer) async {
    await _app.renderableManager.setVisibilityLayer(entity, layer.value);
  }

  @override
  Future<MorphTargetSet> getMorphTargets(ThermionEntity entity) async {
    if (entity != this.entity && !await containsChild(entity)) {
      throw ArgumentError.value(entity, 'entity', 'Entity does not belong to this asset');
    }
    if (!_app.renderableManager.isRenderable(entity)) {
      throw ArgumentError.value(entity, 'entity', 'Entity is not renderable');
    }
    return _createMorphTargetSet(entity);
  }

  @override
  Future<List<MorphTargetSet>> getMorphTargetSets() async {
    final result = <MorphTargetSet>[];
    for (final candidate in [entity, ...await getChildEntities()]) {
      if (_app.renderableManager.isRenderable(candidate) && _app.renderableManager.getMorphTargetCount(candidate) > 0) {
        result.add(_createMorphTargetSet(candidate));
      }
    }
    return result;
  }

  MorphTargetSet _createMorphTargetSet(ThermionEntity entity) {
    final targetCount = _app.renderableManager.getMorphTargetCount(entity);
    var nameCount = 0;
    if (type == SceneAssetType.gltf) {
      nameCount = _app.animationManager.getMorphTargetNameCount(this, entity);
    }

    final targets = <MorphTarget>[];
    for (var i = 0; i < targetCount; i++) {
      String? name;
      if (i < nameCount) {
        name = _app.animationManager.getMorphTargetName(this, entity, i);
      }
      targets.add(MorphTarget(index: i, name: name));
    }
    return _FFIMorphTargetSet(entity, targets, _app.renderableManager);
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

  // Gets the number of bones at skin [skinIndex].
  // Returns the number of bones, or 0 if none found.
  Future<int> getBoneCount({int skinIndex = 0}) async {
    return SceneAsset_getBoneCount(asset, skinIndex);
  }

  // glTF animation names are immutable, so we cache them here to avoid
  // retrieving unnecessarily.
  List<String>? _gltfAnimationNames;

  //
  @override
  Future<List<String>> getGltfAnimationNames() async {
    if (type != SceneAssetType.gltf) {
      _logger.warning("getGltfAnimationNames should only be called on gltf assets");
      return [];
    }
    if (_gltfAnimationNames == null) {
      var animationCount = _app.animationManager.getGltfAnimationCount(this);

      _gltfAnimationNames = [];
      for (int i = 0; i < animationCount; i++) {
        final name = _app.animationManager.getGltfAnimationName(this, i);
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
    if (type != SceneAssetType.gltf) {
      throw Exception("getGltfAnimationDuration can only be called on glTF assets");
    }
    final duration = _app.animationManager.getGltfAnimationDuration(this, animationIndex);
    return duration;
  }

  //
  Future<double> getGltfAnimationDurationByName(String name) async {
    if (type != SceneAssetType.gltf) {
      throw Exception("getGltfAnimationDurationByName can only be called on glTF assets");
    }
    var animations = await getGltfAnimationNames();
    var index = animations.indexOf(name);
    if (index == -1) {
      throw Exception("Failed to find animation $name");
    }
    return getGltfAnimationDuration(index);
  }

  //
  Future clearMorphAnimationData(ThermionEntity entity) async {
    if (!_app.animationManager.clearMorphAnimation(entity)) {
      throw Exception("Failed to clear morph animation");
    }
  }

  //
  @override
  Future setMorphAnimationData(MorphAnimationData animation, {List<String>? targetMeshNames}) async {
    var childEntities = await getChildEntities();

    var childNames = childEntities.map((e) => _app.getNameForEntity(e)).toList();
    if (targetMeshNames != null) {
      for (final targetMeshName in targetMeshNames) {
        if (!childNames.contains(targetMeshName)) {
          throw Exception(
            """Mesh ${targetMeshName} does not exist under the specified entity."""
            """Available meshes : ${childNames}""",
          );
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
    for (int i = 0; i < childNames.length; i++) {
      var childName = childNames[i];
      var meshEntity = childEntities[i];

      if (targetMeshNames?.contains(childName) == false) {
        // _logger.info("Skipping $childName, not contained in target");
        continue;
      }

      final morphTargetSet = await getMorphTargets(meshEntity);
      final targetsByName = <String, MorphTarget>{};
      for (final target in morphTargetSet.targets) {
        final name = target.name;
        if (name != null) {
          if (targetsByName.containsKey(name)) {
            throw StateError('Morph target name "$name" is not unique on entity $meshEntity');
          }
          targetsByName[name] = target;
        }
      }
      final meshMorphTargets = targetsByName.keys.toList();

      var intersection = animation.morphTargets.toSet().intersection(meshMorphTargets.toSet()).toList();

      if (intersection.isEmpty) {
        throw Exception("""No morph targets specified in animation are present on entity $childName. 
            If you weren't intending to animate every mesh, specify [targetMeshNames] when invoking this method.
            Animation morph targets: ${animation.morphTargets}\n
            Mesh morph targets ${meshMorphTargets}
            Child entities: ${childNames}""");
      }

      var indices = Uint32List.fromList(intersection.map((name) => targetsByName[name]!.index).toList());

      // var frameData = animation.data;
      var frameData = animation.subset(intersection);

      assert(frameData.data.length == animation.numFrames * intersection.length);

      var result = _app.animationManager.setMorphAnimation(
        meshEntity,
        frameData.data,
        indices,
        intersection.length,
        animation.numFrames,
        animation.frameLengthInMs,
      );

      frameData.data.free();
      indices.free();

      if (!result) {
        throw Exception("Failed to set morph animation data for ${childName}");
      }
    }
  }

  // Currently, scale is not supported.
  //
  @override
  Future addBoneAnimation(
    BoneAnimationData animation, {
    int skinIndex = 0,
    double fadeOutInSecs = 0.0,
    double fadeInInSecs = 0.0,
    double maxDelta = 1.0,
    bool loop = false,
  }) async {
    if (animation.space != Space.Bone && animation.space != Space.ParentWorldRotation) {
      throw UnimplementedError("TODO - support ${animation.space}");
    }
    if (skinIndex != 0) {
      throw UnimplementedError("TODO - support skinIndex != 0 ");
    }
    // Resolve to instance(0) if this is a top-level asset — the native
    // bone APIs (getBoneCount, getBones, getRestLocalTransforms) require
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
    var restLocalTransformsData = await _app.animationManager.getRestLocalTransforms(instanceAsset, skinIndex);
    var restLocalTransforms = <Matrix4>[];
    for (int i = 0; i < boneNames.length; i++) {
      var values = <double>[];
      for (int j = 0; j < 16; j++) {
        values.add(restLocalTransformsData[(i * 16) + j]);
      }
      restLocalTransforms.add(Matrix4.fromList(values));
    }

    var numFrames = animation.frameData.length;

    var data = makeFloat32List(numFrames * 16);

    try {
      var bones = await instanceAsset.getBones(skinIndex: skinIndex);

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
        // this odd use of ! is intentional, without it, the WASM optimizer gets
        // in trouble
        var parentBoneEntity = (await _app.getParent(boneEntity))!;
        while (true) {
          if (!bones.contains(parentBoneEntity)) {
            break;
          }
          world = restLocalTransforms[bones.indexOf(parentBoneEntity)] * world;
          parentBoneEntity = (await _app.getParent(parentBoneEntity))!;
        }

        world = Matrix4.identity()..setRotation(world.getRotation());
        var worldInverse = Matrix4.identity()..copyInverse(world);

        for (int frameNum = 0; frameNum < numFrames; frameNum++) {
          var rotation = animation.frameData[frameNum][i].rotation;
          var translation = animation.frameData[frameNum][i].translation;
          var frameTransform = Matrix4.compose(translation, rotation, Vector3.all(1.0));
          var newLocalTransform = frameTransform.clone();
          if (animation.space == Space.Bone) {
            newLocalTransform = baseTransform * frameTransform;
          } else if (animation.space == Space.ParentWorldRotation) {
            newLocalTransform = baseTransform * (worldInverse * frameTransform * world);
          }
          for (int j = 0; j < 16; j++) {
            data[(frameNum * 16) + j] = newLocalTransform.storage[j];
          }
        }

        var frameDataList = <double>[];
        for (int i = 0; i < numFrames * 16; i++) {
          frameDataList.add(data[i]);
        }

        await _app.animationManager.addBoneAnimation(
          this,
          skinIndex,
          entityBoneIndex,
          frameDataList,
          numFrames,
          animation.frameLengthInMs,
          fadeOutInSecs: fadeOutInSecs,
          fadeInInSecs: fadeInInSecs,
          maxDelta: maxDelta,
          loop: loop,
        );
      }
    } finally {
      data.free();
    }
  }

  //
  Future<Matrix4> getLocalTransform({ThermionEntity? entity}) async {
    entity ??= this.entity;
    final transform = _app.transformManager.getLocalTransform(entity);
    return transform;
  }

  //
  Future<Matrix4> getWorldTransform({ThermionEntity? entity}) async {
    return _app.getWorldTransform(entity ?? this.entity);
  }

  //
  Future setTransform(Matrix4 transform, {ThermionEntity? entity}) async {
    await _app.setTransform(entity ?? this.entity, transform);
  }

  //
  Future<Matrix4> getInverseBindMatrix(int boneIndex, {int skinIndex = 0}) async {
    if (!isInstance) {
      throw Exception("getInverseBindMatrix can only be called on an instance of an asset");
    }
    var matrixData = await _app.animationManager.getInverseBindMatrix(this, skinIndex, boneIndex);
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
  Future setBoneTransform(int boneIndex, Matrix4 transform, {ThermionEntity? entity, int skinIndex = 0}) async {
    if (skinIndex != 0) {
      throw UnimplementedError("TODO - support skinIndex != 0");
    }
    final renderableManager = _app.renderableManager;

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
        throw Exception("Could not find a renderable (skinned mesh) entity for this asset");
      }
    } else if (!renderableManager.isRenderable(meshEntity)) {
      throw Exception(
        "Entity $meshEntity is not a renderable; setBoneTransform must "
        "target a skinned mesh entity, not the glTF root or a bone entity",
      );
    }

    await renderableManager.setBonesFromMat4(meshEntity, [transform], offset: boneIndex);
  }

  //
  @override
  Future resetBones() async {
    _app.animationManager.resetToRestPose(this);
  }

  //
  @override
  Future playGltfAnimation(
    int index, {
    bool loop = false,
    bool reverse = false,
    bool replaceActive = true,
    double crossfade = 0.0,
    double startOffset = 0.0,
    double speed = 1.0,
  }) async {
    final success = _app.animationManager.playGltfAnimation(
      this,
      index,
      loop: loop,
      reverse: reverse,
      replaceActive: replaceActive,
      crossfade: crossfade,
      startOffset: startOffset,
      speed: speed,
    );
    if (!success) {
      throw Exception("Failed to play glTF animation. Check logs for details");
    }
  }

  //
  @override
  Future stopGltfAnimation(int animationIndex) async {
    final success = _app.animationManager.stopGltfAnimation(this, animationIndex);
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
  Future playGltfAnimationByName(
    String name, {
    bool loop = false,
    bool reverse = false,
    bool replaceActive = true,
    double crossfade = 0.0,
    double speed = 1.0,
    bool wait = false,
  }) async {
    var animations = await getGltfAnimationNames();
    var index = animations.indexOf(name);
    var duration = await getGltfAnimationDuration(index);
    await playGltfAnimation(
      index,
      loop: loop,
      reverse: reverse,
      replaceActive: replaceActive,
      crossfade: crossfade,
      speed: speed,
    );
    if (wait) {
      await Future.delayed(Duration(milliseconds: (duration * 1000).toInt()));
    }
  }

  //
  @override
  Future setGltfAnimationTime(int index, double timeInSeconds) async {
    await _app.animationManager.setGltfAnimationTime(this, index, timeInSeconds);
  }

  //
  @override
  Future addAnimationComponent() async {
    if (!{SceneAssetType.geometry, SceneAssetType.gltf, SceneAssetType.light}.contains(this.type)) {
      throw Exception(
        "Only geometry, gltf and lights support adding animation "
        "components",
      );
    }
    _app.animationManager.addGltfAnimationComponent(this);
  }

  //
  Future removeAnimationComponent() async {
    if (!{SceneAssetType.geometry, SceneAssetType.gltf, SceneAssetType.light}.contains(this.type)) {
      return;
    }

    if (type == SceneAssetType.gltf && !await _app.animationManager.removeGltfAnimationComponent(this)) {
      _logger.warning("Failed to remove glTF animation component");
    }
    if (!await _app.animationManager.removeBoneAnimationComponent(this)) {
      _logger.warning("Failed to remove bone animation component");
    }
    _app.animationManager.removeMorphAnimationComponent(entity);

    for (final child in await getChildEntities()) {
      _app.animationManager.removeMorphAnimationComponent(child);
    }
  }

  //
  Future<int> getPrimitiveCount({ThermionEntity? entity}) async {
    return _app.getPrimitiveCount(entity ??= this.entity);
  }

  /// Returns the starting primitive offset for the given entity, or -1 if
  /// the entity has no preserved geometry (e.g., non-triangle primitives
  /// or no mesh match during rebuild).
  ///
  /// This is used by setStencilHighlight to map from a Filament entity to
  /// the corresponding offset in the preserved buffer arrays. The offset
  /// points to the entity's first primitive; if the entity has multiple
  /// primitives, they occupy consecutive indices [offset, offset + primitiveCount).
  Future<int> getPrimitiveOffsetForEntity(ThermionEntity entity) async {
    return SceneAsset_getPrimitiveOffsetForEntity(asset, entity);
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
    return FFIVertexBuffer(vbPtr, _app.engine);
  }
}

final class _FFIMorphTargetSet implements MorphTargetSet {
  @override
  final ThermionEntity entity;

  @override
  final List<MorphTarget> targets;

  final RenderableManager _renderableManager;

  _FFIMorphTargetSet(this.entity, List<MorphTarget> targets, this._renderableManager)
    : targets = List.unmodifiable(targets);

  @override
  Future<void> setWeight(String name, double weight) => setWeights({name: weight});

  @override
  Future<void> setWeights(Map<String, double> weights) async {
    final updates = <(MorphTarget, double)>[];
    for (final entry in weights.entries) {
      if (!entry.value.isFinite) {
        throw ArgumentError.value(entry.value, entry.key, 'Morph weights must be finite');
      }
      updates.add((_targetNamed(entry.key), entry.value));
    }

    for (final (target, weight) in updates) {
      await _renderableManager.setMorphWeightAt(entity, target.index, weight);
    }
  }

  @override
  Future<void> setWeightAt(int index, double weight) {
    return _renderableManager.setMorphWeightAt(entity, index, weight);
  }

  @override
  Future<void> setAllWeights(List<double> weights) {
    return _renderableManager.setMorphWeights(entity, weights);
  }

  MorphTarget _targetNamed(String name) {
    final matches = targets.where((target) => target.name == name).toList();
    if (matches.isEmpty) {
      throw ArgumentError.value(name, 'name', 'No morph target has this name');
    }
    if (matches.length > 1) {
      throw StateError('Morph target name "$name" is not unique; use setWeightAt instead');
    }
    return matches.single;
  }
}

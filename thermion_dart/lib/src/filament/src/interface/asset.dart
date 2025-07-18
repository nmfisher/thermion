library;

import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:thermion_dart/src/filament/src/interface/layers.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/thermion_dart.dart';

export 'geometry.dart';

///
/// A high-level interface for a renderable object
/// (i.e. not a camera or light).
///
/// Filament represents most "objects" with an integer handle (in C++,
/// filament::Entity).
///
/// In practice, working with filament::Entity at a higher level is difficult
/// because certain objects don't map exactly to entities (e.g. glTF assets, which
/// are represented by a hierarchy of entities) and creating instances
/// directly from entities is not possible.
///
///
abstract class ThermionAsset {
  ///
  ///
  ///
  T getHandle<T>() {
    throw UnimplementedError();
  }

  ///
  /// The top-most entity in the hierarchy. If this is a glTF asset
  ///
  ThermionEntity get entity;

  ///
  ///
  ///
  Future<List<ThermionEntity>> getChildEntities();

  ///
  ///
  ///
  Future<bool> containsChild(ThermionEntity entity) {
    throw UnimplementedError();
  }

  ///
  ///
  ///
  Future<List<String?>> getChildEntityNames();

  ///
  ///
  ///
  Future<ThermionEntity?> getChildEntity(String childName);

  ///
  ///
  ///
  Future<MaterialInstance> getMaterialInstanceAt(
      {ThermionEntity? entity, int index = 0});

  /// Sets the material instance for the primitive at [primitiveIndex] in
  /// [entity].
  ///
  /// If [entity] is null, the top-most parent for this asset will be used.
  ///
  ///
  Future setMaterialInstanceAt(covariant MaterialInstance instance,
      {int? entity = null, int primitiveIndex = 0}) {
    throw UnimplementedError();
  }

  /// Sets the material instance for all primitives in all entities to
  /// [instance].
  ///
  Future setMaterialInstanceForAll(covariant MaterialInstance instance) {
    throw UnimplementedError();
  }

  /// Returns a map of all renderable entities attached to this asset, and
  /// a list of material instances for each primitive for the respective
  /// entity.
  ///
  Future<Map<ThermionEntity, List<MaterialInstance>>>
      getMaterialInstancesAsMap() {
    throw UnimplementedError();
  }

  /// For each entity in the given map, set the material instance
  /// for the respective primitive.
  ///
  /// Mainly intended for use with [getMaterialInstancesAsMap] so you can
  /// easily save/restore an asset's material instances.
  ///
  Future setMaterialInstancesFromMap(
      Map<ThermionEntity, List<MaterialInstance>> materialInstances) async {
    throw UnimplementedError();
  }

  ///
  /// The dimensions of the bounding box for this asset.
  /// This is independent of the boundingBoxAsset (which is used to visualize
  /// the bounding box in the scene); you do not need to call
  /// [createBoundingBoxAsset] before this method.
  Future<Aabb3> getBoundingBox();

  ///
  ///
  ///
  Future<ThermionAsset> getInstance(int index);

  ///
  /// Create a new instance of [entity].
  /// Instances are not automatically added to the scene; you must
  /// call [Scene.add].
  ///
  Future<ThermionAsset> createInstance(
      {List<MaterialInstance>? materialInstances = null});

  ///
  /// Returns the number of instances associated with this asset.
  ///
  Future<int> getInstanceCount();

  ///
  /// Returns all instances of associated with this asset.
  ///
  Future<List<ThermionAsset>> getInstances();

  ///
  ///
  ///
  Future setCastShadows(bool castShadows);

  ///
  ///
  ///
  Future setReceiveShadows(bool castShadows);

  ///
  ///
  ///
  Future<bool> isCastShadowsEnabled({ThermionEntity? entity});

  ///
  ///
  ///
  Future<bool> isReceiveShadowsEnabled({ThermionEntity? entity});

  ///
  ///
  ///
  Future transformToUnitCube();

  ///
  /// All renderable entities are assigned a layer mask.
  ///
  /// By calling [setLayerVisibility], all renderable entities allocated to
  /// the given layer can be efficiently hidden/revealed.
  ///
  /// By default, all renderable entities are assigned to layer 0 (and this
  /// layer is enabled by default). Call [setVisibilityLayer] to change the
  /// layer for the specified entity.
  ///
  /// Note that we currently also assign gizmos to layer 1 (enabled by default)
  /// and the world grid to layer 2 (disabled by default). We suggest you avoid
  /// using these layers.
  ///
  Future setVisibilityLayer(ThermionEntity entity, VisibilityLayers layer);

  ///
  /// Schedules the glTF animation at [index] in [asset] to start playing on the next frame.
  ///
  Future playGltfAnimation(int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      double startOffset = 0.0}) {
    throw UnimplementedError();
  }

  ///
  /// Schedules the glTF animation at [index] in [entity] to start playing on the next frame.
  ///
  Future playGltfAnimationByName(String name,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) {
    throw UnimplementedError();
  }

  ///
  ///
  ///
  Future setGltfAnimationFrame(int index, int animationFrame) {
    throw UnimplementedError();
  }

  ///
  ///
  ///
  Future stopGltfAnimation(int animationIndex) {
    throw UnimplementedError();
  }

  ///
  ///
  ///
  Future stopGltfAnimationByName(String name) {
    throw UnimplementedError();
  }

  ///
  /// Set the weights for all morph targets in [entity] to [weights].
  /// Note that [weights] must contain values for ALL morph targets, but no exception will be thrown if you don't do so (you'll just get incorrect results).
  /// If you only want to set one value, set all others to zero (check [getMorphTargetNames] if you need the get a list of all morph targets).
  /// IMPORTANT - this accepts the actual ThermionEntity with the relevant morph targets (unlike [getMorphTargetNames], which uses the parent entity and the child mesh name).
  /// Use [getChildEntityByName] if you are setting the weights for a child mesh.
  ///
  Future setMorphTargetWeights(ThermionEntity entity, List<double> weights) {
    throw UnimplementedError();
  }

  ///
  /// Gets the names of all morph targets for [entity] (which must be a renderable entity)
  ///
  Future<List<String>> getMorphTargetNames({ThermionEntity? entity}) {
    throw UnimplementedError();
  }

  ///
  /// Gets the names of all bones for the skin at [skinIndex].
  ///
  Future<List<String>> getBoneNames({int skinIndex = 0}) {
    throw UnimplementedError();
  }

  ///
  /// Gets the names of all glTF animations embedded in the specified entity.
  ///
  Future<List<String>> getGltfAnimationNames() {
    throw UnimplementedError();
  }

  ///
  /// Returns the length (in seconds) of the animation at the given index.
  ///
  Future<double> getGltfAnimationDuration(int animationIndex) {
    throw UnimplementedError();
  }

  ///
  /// Construct animation(s) for every entity under [asset]. If [targetMeshNames] is provided, only entities with matching names will be animated.
  /// [MorphTargetAnimation] for an explanation as to how to construct the animation frame data.
  /// This method will check the morph target names specified in [animation] against the morph target names that actually exist exist under [meshName] in [entity],
  /// throwing an exception if any cannot be found.
  /// It is permissible for [animation] to omit any targets that do exist under [meshName]; these simply won't be animated.
  ///
  Future setMorphAnimationData(MorphAnimationData animation,
      {List<String>? targetMeshNames}) {
    throw UnimplementedError();
  }

  ///
  /// Clear all current morph animations for [entity].
  ///
  Future clearMorphAnimationData(ThermionEntity entity) {
    throw UnimplementedError();
  }

  ///
  /// Resets all bones in the given entity to their rest pose.
  /// This should be done before every call to addBoneAnimation.
  ///
  Future resetBones();

  ///
  /// Enqueues and plays the [animation] for the specified bone(s).
  /// By default, frame data is interpreted as being in *parent* bone space;
  /// a 45 degree around Y means the bone will rotate 45 degrees around the
  /// Y axis of the parent bone *in its current orientation*.
  /// (i.e NOT the parent bone's rest position!).
  /// Currently, only [Space.ParentBone] and [Space.Model] are supported; if you want
  /// to transform to another space, you will need to do so manually.
  ///
  /// [fadeInInSecs]/[fadeOutInSecs]/[maxDelta] are used to cross-fade between
  /// the current active glTF animation ("animation1") and the animation you
  /// set via this method ("animation2"). The bone orientations will be
  /// linearly interpolated between animation1 and animation2; at time 0,
  /// the orientation will be 100% animation1, at time [fadeInInSecs], the
  /// animation will be ((1 - maxDelta) * animation1) + (maxDelta * animation2).
  /// This will be applied in reverse after [fadeOutInSecs].
  ///
  ///
  Future addBoneAnimation(BoneAnimationData animation,
      {int skinIndex = 0,
      double fadeInInSecs = 0.0,
      double fadeOutInSecs = 0.0,
      double maxDelta = 1.0});

  ///
  /// Gets the entity representing the bone at [boneIndex]/[skinIndex].
  /// The returned entity is only intended for use with [getWorldTransform].
  ///
  Future<ThermionEntity> getBone(int boneIndex, {int skinIndex = 0});

  ///
  /// Gets the local (relative to parent) transform for [entity].
  ///
  Future<Matrix4> getLocalTransform({ThermionEntity? entity});

  ///
  /// Gets the world transform for [entity].
  ///
  Future<Matrix4> getWorldTransform({ThermionEntity? entity});

  ///
  /// Gets the inverse bind (pose) matrix for the bone.
  /// Note that [parent] must be the ThermionEntity returned by [loadGlb/loadGltf], not any other method ([getChildEntity] etc).
  /// This is because all joint information is internally stored with the parent entity.
  ///
  Future<Matrix4> getInverseBindMatrix(int boneIndex, {int skinIndex = 0});

  ///
  /// Sets the transform (relative to its parent) for [entity].
  ///
  Future setTransform(Matrix4 transform, {ThermionEntity? entity});

  ///
  /// Updates the bone matrices for [entity] (which must be the ThermionEntity
  /// returned by [loadGlb/loadGltf]).
  /// Under the hood, this just calls [updateBoneMatrices] on the Animator
  /// instance of the relevant FilamentInstance (which uses the local
  /// bone transform and the inverse bind matrix to set the bone matrix).
  ///
  Future updateBoneMatrices(ThermionEntity entity);

  ///
  /// Directly set the bone matrix for the bone at the given index.
  /// Don't call this manually unless you know what you're doing.
  ///
  Future setBoneTransform(
      ThermionEntity entity, int boneIndex, Matrix4 transform,
      {int skinIndex = 0});

  ///
  /// An [entity] will only be animatable after an animation component is attached.
  /// Any calls to [playAnimation]/[setBoneAnimation]/[setMorphAnimation] will have no visual effect until [addAnimationComponent] has been called on the instance.
  ///
  Future addAnimationComponent();

  ///
  /// Removes an animation component from [entity].
  ///
  Future removeAnimationComponent();

  /// Returns the number of primitives in [entity] (which is assumed to have
  /// a Renderable component attached).
  ///
  ///
  Future<int> getPrimitiveCount({ThermionEntity? entity}) async {
    throw UnimplementedError();
  }
}

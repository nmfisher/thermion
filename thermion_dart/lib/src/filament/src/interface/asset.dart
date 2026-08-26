library;

import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

export 'geometry.dart';

/// A geometry operation guaranteed to be supported by a scene asset.
///
/// The same values can be supplied to asset loaders as requirements. Loaders
/// may provide additional capabilities when they share the same geometry
/// representation.
enum SceneAssetGeometryCapability {
  /// Smooth and per-face tangent frames can be selected at runtime.
  flatShading,

  /// Triangle-corner barycentric coordinates are available to materials.
  barycentrics,

  /// Vertex attributes can be updated through [VertexBuffer.setBufferAt].
  writableVertices,

  /// Thermion retains reusable vertex and index buffers for operations such as
  /// stencil highlighting.
  preservedGeometry,

  /// Source vertex order and triangle indices are preserved.
  preservedTopology,

  /// Every triangle corner has its own vertex.
  uniqueTriangleCorners,
}

enum SceneAssetType { gltf, geometry, light, skybox, ibl, image, gizmo }

/// Describes one morph target on a renderable entity.
///
/// [name] is null for targets that do not have a name, such as targets on
/// procedurally-created renderables. [index] is always available and matches
/// the order expected by [MorphTargetSet.setAllWeights].
final class MorphTarget {
  final int index;
  final String? name;

  const MorphTarget({required this.index, this.name});

  @override
  String toString() => name == null ? 'MorphTarget($index)' : 'MorphTarget($index, $name)';
}

/// Morph targets and mutation methods bound to a single renderable [entity].
///
/// A weight of `0.0` uses the base shape and `1.0` applies the complete target.
/// Multiple targets can contribute simultaneously. Finite values outside that
/// range are passed through to Filament for intentional extrapolation.
///
/// Active glTF or custom morph animations can write the same weights on every
/// animation update. A manual update to an animated target is therefore
/// temporary and is replaced by the next animation tick. Call
/// [ThermionAsset.clearMorphAnimationData] before setting a persistent manual
/// value for a target driven by a custom morph animation.
abstract interface class MorphTargetSet {
  ThermionEntity get entity;

  /// Targets in the exact order expected by [setAllWeights].
  List<MorphTarget> get targets;

  /// Updates one uniquely named target without changing other targets.
  Future<void> setWeight(String name, double weight);

  /// Updates several uniquely named targets without changing other targets.
  ///
  /// Every name is validated before any update is applied.
  Future<void> setWeights(Map<String, double> weights);

  /// Updates one target by index without changing other targets.
  Future<void> setWeightAt(int index, double weight);

  /// Replaces the complete morph pose in [targets] order.
  ///
  /// The length of [weights] must equal [targets].length.
  Future<void> setAllWeights(List<double> weights);
}

// filament::utils::Entity is the core C++ Filament "handle" type, used to
// represent lights, renderables, cameras, etc. ThermionEntity is the equivalent
// Dart type.
//
// However, it can be cumbersome to work directly with [ThermionEntity]; glTF
// assets, for example, are stored as collections of entities. Generally users
// would want to add/remove these from a scene at once, rather than tracking and
// processing each entity individually.
//
// [ThermionAsset] is a higher-level interface over a one or more renderable
// entities.
//
abstract class ThermionAsset<T> extends NativeHandle<T> {
  Set<SceneAssetGeometryCapability> get geometryCapabilities {
    return const {};
  }

  // The top-most entity in the hierarchy (if this is a glTF asset, this
  // entity will have a transform that sits at the top of the transform
  // hierarchy but is not itself renderable.
  ThermionEntity get entity;

  // The type of the underlying scene asset.
  SceneAssetType get type;

  // Whether or not this asset is an instance.
  bool get isInstance;

  // If this asset is an instance, the asset that owns this instance.
  ThermionAsset? get instanceOwner;

  //
  Future<List<ThermionEntity>> getChildEntities() async {
    throw UnimplementedError();
  }

  //
  Future<bool> containsChild(ThermionEntity entity) {
    throw UnimplementedError();
  }

  //
  Future<List<String?>> getChildEntityNames() async {
    throw UnimplementedError();
  }

  //
  Future<ThermionEntity?> getChildEntity(String childName) async {
    throw UnimplementedError();
  }

  //
  Future<MaterialInstance> getMaterialInstanceAt({ThermionEntity? entity, int index = 0}) async {
    throw UnimplementedError();
  }

  // Sets the material instance for the primitive at [primitiveIndex] in
  // [entity]. If [entity] is null, the top-most parent for this asset will be
  // used.
  Future setMaterialInstanceAt(covariant MaterialInstance instance, {int? entity = null, int primitiveIndex = 0}) {
    throw UnimplementedError();
  }

  // Sets the material instance for all primitives in all entities to
  // [instance].
  Future setMaterialInstanceForAll(covariant MaterialInstance instance) {
    throw UnimplementedError();
  }

  // Toggle between flat (per-face) and smooth (per-vertex) shading.
  // Throws unless [geometryCapabilities] contains
  // [SceneAssetGeometryCapability.flatShading].
  Future setFlatShading(bool flatShading) {
    throw UnimplementedError();
  }

  // Returns a map of all renderable entities attached to this asset, and
  // a list of material instances for each primitive for the respective
  // entity.
  Future<Map<ThermionEntity, List<MaterialInstance>>> getMaterialInstancesAsMap() {
    throw UnimplementedError();
  }

  // For each entity in the given map, set the material instance
  // for the respective primitive.
  //
  // Mainly intended for use with [getMaterialInstancesAsMap] so you can
  // easily save/restore an asset's material instances.
  Future setMaterialInstancesFromMap(Map<ThermionEntity, List<MaterialInstance>> materialInstances) async {
    throw UnimplementedError();
  }

  // The dimensions of the bounding box for this asset.
  Future<Aabb3> getBoundingBox() async {
    throw UnimplementedError();
  }

  // Gets the instance attached to this asset at index [index]
  Future<ThermionAsset> getInstance(int index) async {
    throw UnimplementedError();
  }

  // Create a new instance of [entity]. Note that instances are not
  // automatically added to the scene; you must call [Scene.add].
  Future<ThermionAsset> createInstance({List<MaterialInstance>? materialInstances = null});

  // Returns the number of instances associated with this asset.
  Future<int> getInstanceCount() async {
    throw UnimplementedError();
  }

  // Returns all instances of associated with this asset.
  Future<List<ThermionAsset>> getInstances() async {
    throw UnimplementedError();
  }

  // Releases the CPU-side glTF source copy held by this asset (the original
  // .glb buffer), which is retained after load so that [createInstance] can
  // be called later.
  //
  // Call this AFTER every instance you need has been created. Afterwards,
  // [createInstance] will throw and no further instances can be created.
  // Existing instances are unaffected, since they share GPU resources with
  // the asset and only depend on the source copy at creation time.
  //
  // Must be called on the owning asset (throws if called on an instance).
  // Also throws if this is not a glTF asset, or if the source data has
  // already been released (for example, the asset was loaded with
  // releaseSourceData: true).
  Future releaseSourceData() async {
    throw UnimplementedError();
  }

  // Enable/disable casting shadows.
  Future setCastShadows(bool castShadows) async {
    throw UnimplementedError();
  }

  // Enable/disable receiving shadows.
  Future setReceiveShadows(bool castShadows) async {
    throw UnimplementedError();
  }

  // Whether casting shadows is enabled.
  Future<bool> isCastShadowsEnabled({ThermionEntity? entity}) async {
    throw UnimplementedError();
  }

  //
  Future<bool> isReceiveShadowsEnabled({ThermionEntity? entity}) async {
    throw UnimplementedError();
  }

  //
  Future transformToUnitCube() async {
    throw UnimplementedError();
  }

  // All renderable entities are assigned a layer mask.
  //
  // By calling [setLayerVisibility], all renderable entities allocated to
  // the given layer can be efficiently hidden/revealed.
  //
  // By default, all renderable entities are assigned to layer 0 (and this
  // layer is enabled by default). Call [setVisibilityLayer] to change the
  // layer for the specified entity.
  //
  // Note that we currently also assign gizmos to layer 1 (enabled by default)
  // and the world grid to layer 2 (disabled by default). We suggest you avoid
  // using these layers.
  //
  Future setVisibilityLayer(ThermionEntity entity, VisibilityLayers layer) async {
    throw UnimplementedError();
  }

  // Schedules the glTF animation at [index] in [asset] to start playing on the
  // next frame.
  Future playGltfAnimation(
    int index, {
    bool loop = false,
    bool reverse = false,
    bool replaceActive = true,
    double crossfade = 0.0,
    double startOffset = 0.0,
    double speed = 1.0,
  }) {
    throw UnimplementedError();
  }

  // Schedules the glTF animation at [index] in [entity] to start playing on the
  // next frame.
  Future playGltfAnimationByName(
    String name, {
    bool loop = false,
    bool reverse = false,
    bool replaceActive = true,
    double crossfade = 0.0,
    double speed = 1.0,
  }) {
    throw UnimplementedError();
  }

  //
  Future setGltfAnimationTime(int index, double timeInSeconds) {
    throw UnimplementedError();
  }

  //
  Future stopGltfAnimation(int animationIndex) {
    throw UnimplementedError();
  }

  //
  Future stopGltfAnimationByName(String name) {
    throw UnimplementedError();
  }

  /// Returns the morph targets attached to the renderable [entity].
  ///
  /// The returned object is bound to [entity] and supports named, indexed, and
  /// strict bulk updates. Throws if [entity] does not belong to this asset or
  /// is not renderable.
  Future<MorphTargetSet> getMorphTargets(ThermionEntity entity) {
    throw UnimplementedError();
  }

  /// Discovers every renderable entity in this asset that has morph targets.
  Future<List<MorphTargetSet>> getMorphTargetSets() {
    throw UnimplementedError();
  }

  // Returns all bone entities for the skin at [skinIndex].
  Future<List<ThermionEntity>> getBones({int skinIndex = 0}) {
    throw UnimplementedError();
  }

  // Gets the names of all bones for the skin at [skinIndex].
  Future<List<String>> getBoneNames({int skinIndex = 0}) {
    throw UnimplementedError();
  }

  // Gets the number of bones for the given skinning index.
  Future<int> getBoneCount({int skinIndex = 0}) {
    throw UnimplementedError();
  }

  // Gets the names of all glTF animations embedded in the specified entity.
  Future<List<String>> getGltfAnimationNames() {
    throw UnimplementedError();
  }

  // Returns the length (in seconds) of the animation at the given index.
  Future<double> getGltfAnimationDuration(int animationIndex) {
    throw UnimplementedError();
  }

  /// Adds a custom morph animation to matching renderable entities.
  ///
  /// If [targetMeshNames] is provided, only entities with matching names are
  /// animated. The names in [animation] are matched to each entity's targets;
  /// targets omitted from [animation] are not changed.
  ///
  /// Active animations overwrite manual [MorphTargetSet] updates on their next
  /// tick. If several custom animations drive the same target, the most
  /// recently added animation has priority. Use [clearMorphAnimationData] to
  /// return the entity to persistent manual control.
  Future setMorphAnimationData(MorphAnimationData animation, {List<String>? targetMeshNames}) {
    throw UnimplementedError();
  }

  /// Stops all custom morph animations on [entity].
  ///
  /// This does not stop morph channels belonging to an active glTF animation.
  Future clearMorphAnimationData(ThermionEntity entity) {
    throw UnimplementedError();
  }

  //
  // Resets all bones in the given entity to their rest pose.
  // This should be done before every call to addBoneAnimation.
  //
  Future resetBones() async {
    throw UnimplementedError();
  }

  // Enqueues and plays the [animation] for the specified bone(s). By default,
  // frame data is interpreted as being in *parent* bone space; a 45 degree
  // around Y means the bone will rotate 45 degrees around the Y axis of the
  // parent bone *in its current orientation*. (i.e NOT the parent bone's rest
  // position!). Currently, only [Space.ParentBone] and [Space.Model] are
  // supported; if you want to transform to another space, you will need to do
  // so manually.
  //
  // [fadeInInSecs]/[fadeOutInSecs]/[maxDelta] are used to cross-fade between
  // the current active glTF animation ("animation1") and the animation you set
  // via this method ("animation2"). The bone orientations will be linearly
  // interpolated between animation1 and animation2; at time 0, the orientation
  // will be 100% animation1, at time [fadeInInSecs], the animation will be ((1
  // - maxDelta) * animation1) + (maxDelta * animation2). This will be applied
  // in reverse after [fadeOutInSecs].
  Future addBoneAnimation(
    BoneAnimationData animation, {
    int skinIndex = 0,
    double fadeInInSecs = 0.0,
    double fadeOutInSecs = 0.0,
    double maxDelta = 1.0,
    bool loop = false,
  }) async {
    throw UnimplementedError();
  }

  //
  // Gets the local (relative to parent) transform for [entity].
  //
  Future<Matrix4> getLocalTransform({ThermionEntity? entity}) async {
    throw UnimplementedError();
  }

  //
  // Gets the world transform for [entity].
  //
  Future<Matrix4> getWorldTransform({ThermionEntity? entity}) async {
    throw UnimplementedError();
  }

  // Gets the inverse bind (pose) matrix for the bone. Note that [parent] must
  // be the ThermionEntity returned by [loadGlb/loadGltf], not any other method
  // ([getChildEntity] etc). This is because all joint information is internally
  // stored with the parent entity.
  Future<Matrix4> getInverseBindMatrix(int boneIndex, {int skinIndex = 0}) async {
    throw UnimplementedError();
  }

  // Sets the transform (relative to its parent) for [entity].
  Future setTransform(Matrix4 transform, {ThermionEntity? entity}) async {
    throw UnimplementedError();
  }

  // Directly set the bone matrix for the bone at [boneIndex] on a skinned mesh
  // in this asset.
  //
  // [entity] is the specific skinned mesh entity to target. If null, defaults
  // to the asset's own entity if it is renderable, otherwise the first
  // renderable child. Pass [entity] explicitly when the asset contains more
  // than one skinned mesh.
  //
  // Don't call this manually unless you know what you're doing.
  //
  Future setBoneTransform(int boneIndex, Matrix4 transform, {ThermionEntity? entity, int skinIndex = 0}) async {
    throw UnimplementedError();
  }

  // An [entity] will only be animatable after an animation component is
  // attached. Any calls to
  // [playAnimation]/[addBoneAnimation]/[setMorphAnimation] will have no visual
  // effect until [addAnimationComponent] has been called on the instance.
  Future addAnimationComponent() async {
    throw UnimplementedError();
  }

  // Removes an animation component from [entity].
  Future removeAnimationComponent() async {
    throw UnimplementedError();
  }

  // Returns the number of primitives in [entity] (which is assumed to have
  // a Renderable component attached).
  Future<int> getPrimitiveCount({ThermionEntity? entity}) async {
    throw UnimplementedError();
  }

  // Returns the underlying [VertexBuffer] for this asset, if available.
  //
  // For geometry assets this exposes the backing Filament vertex buffer so you
  // can update data via [VertexBuffer.setBufferAt]. Assets with
  // [SceneAssetGeometryCapability.writableVertices] expose directly writable
  // buffers; barycentric/flat-shading geometry uses Filament BufferObjects.
  //
  // [primitiveIndex] is reserved for future use. Geometry assets currently
  // only support a single primitive, so it is ignored.
  //
  // Returns null if this asset type does not expose a vertex buffer.
  VertexBuffer? getVertexBuffer({int primitiveIndex = 0}) {
    throw UnimplementedError();
  }
}

import 'dart:async';

import 'package:logging/logging.dart';

import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';
import 'package:vector_math/vector_math_64.dart' as v64;

class FFIAsset extends ThermionAsset<Pointer<TSceneAsset>> {
  late final _logger = Logger(this.runtimeType.toString());

  final Pointer<TSceneAsset> _asset;
  _AssetStatus _status = _AssetStatus.alive;
  Int32List? _childEntities;
  // The owner keeps one Dart object for each native instance.
  final _instances = <int, FFIAsset>{};
  Future<void> _pendingOperations = Future<void>.value();
  // Destroying the owner also destroys this asset.
  FFIAsset? _owner;
  final _ownedAssets = Set<FFIAsset>.identity();
  final _ownedMaterialInstances = <int, FFIMaterialInstance>{};
  Future<void>? _destructionFuture;
  FFIAsset? _boundingBoxAsset;

  Pointer<TSceneAsset> get asset {
    _throwIfNotAlive();
    return _asset;
  }

  @override
  bool get isDestroyed => _status != _AssetStatus.alive || (_owner?.isDestroyed ?? false);

  void _throwIfNotAlive() {
    if (isDestroyed) {
      throw StateError('Asset has been destroyed.');
    }
  }

  // Instance operations use their owner's queue so owner destruction waits
  // for pending operations on its instances.
  Future<T> _enqueueOperation<T>(Future<T> Function() operation) {
    if (isInstance) {
      return _owner!._enqueueOperation(operation);
    }
    final previous = _pendingOperations;
    final current = () async {
      await previous;
      return operation();
    }();
    _pendingOperations = current.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return current;
  }

  Pointer<TSceneAsset> getNativeHandle() {
    return asset;
  }

  final bool isInstance;

  @override
  FFIAsset? get owner => _owner;

  /// The source asset for a native instance. Other owned assets return null.
  @override
  @Deprecated('Use owner. Check isInstance for native instances.')
  FFIAsset? get instanceOwner => isInstance ? _owner : null;

  void _ownAsset(FFIAsset child) {
    if (child._owner != null) {
      throw StateError('Asset already has an owner.');
    }
    if (!identical(_app, child._app)) {
      throw StateError('Owned assets must belong to the same FilamentApp.');
    }
    for (FFIAsset? ancestor = this; ancestor != null; ancestor = ancestor._owner) {
      if (identical(ancestor, child)) {
        throw StateError('Asset ownership cannot contain cycles.');
      }
    }
    child._owner = this;
    _ownedAssets.add(child);
  }

  late final ThermionEntity entity;

  // Mutable only on the owning asset. Instance wrappers read the owner's value
  // through [_sourceDataReleased] rather than carrying their own copy, so the
  // state can never diverge.
  bool _released = false;

  // The owning asset's released state; on an instance this reads through to
  // the instance owner.
  bool get _sourceDataReleased => isInstance ? _owner!._sourceDataReleased : _released;

  final FFIFilamentApp _app;

  factory FFIAsset(Pointer<TSceneAsset> asset, {FFIAsset? instanceOwner, required FFIFilamentApp app}) {
    if (instanceOwner != null) {
      return instanceOwner._wrapInstance(asset);
    }
    return FFIAsset._(asset, app: app);
  }

  FFIAsset _wrapInstance(Pointer<TSceneAsset> asset) {
    return _instances.putIfAbsent(asset.address, () => FFIAsset._(asset, owner: this, isInstance: true, app: _app));
  }

  FFIAsset._(Pointer<TSceneAsset> asset, {FFIAsset? owner, this.isInstance = false, required FFIFilamentApp app})
    : _asset = asset,
      _app = app {
    entity = SceneAsset_getEntity(asset);
    owner?._ownAsset(this);
  }

  @override
  Set<SceneAssetGeometryCapability> get geometryCapabilities {
    final bits = SceneAsset_getGeometryCapabilities(asset);
    return {
      if (bits & TSceneAssetGeometryCapability.SCENE_ASSET_GEOMETRY_CAPABILITY_BARYCENTRICS != 0)
        SceneAssetGeometryCapability.barycentrics,
      if (bits & TSceneAssetGeometryCapability.SCENE_ASSET_GEOMETRY_CAPABILITY_WRITABLE_VERTICES != 0)
        SceneAssetGeometryCapability.writableVertices,
      if (bits & TSceneAssetGeometryCapability.SCENE_ASSET_GEOMETRY_CAPABILITY_ACCESSIBLE_GEOMETRY_BUFFERS != 0)
        SceneAssetGeometryCapability.accessibleGeometryBuffers,
      if (bits & TSceneAssetGeometryCapability.SCENE_ASSET_GEOMETRY_CAPABILITY_PRESERVED_TOPOLOGY != 0)
        SceneAssetGeometryCapability.preservedTopology,
      if (bits & TSceneAssetGeometryCapability.SCENE_ASSET_GEOMETRY_CAPABILITY_UNIQUE_TRIANGLE_CORNERS != 0)
        SceneAssetGeometryCapability.uniqueTriangleCorners,
    };
  }

  @override
  bool get supportsFlatShading => SceneAsset_supportsFlatShading(asset);

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
  @override
  Future<List<ThermionEntity>> getChildEntities() async {
    _throwIfNotAlive();
    return _getChildEntities();
  }

  List<ThermionEntity> _getChildEntities() {
    if (_childEntities == null) {
      var count = SceneAsset_getChildEntityCount(_asset);

      late Pointer stackPtr;
      if (FILAMENT_WASM) {
        stackPtr = stackSave();
      }
      var childEntities = makeInt32List(count);
      if (count > 0) {
        SceneAsset_getChildEntities(_asset, childEntities.address);
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
    _throwIfNotAlive();
    if (isInstance) {
      throw Exception(
        """This is itself an instance. Call getInstance on the """
        """original asset that this instance was created from""",
      );
    }
    return _enqueueOperation(() async {
      var instance = SceneAsset_getInstance(_asset, index);
      if (instance == nullptr) {
        throw Exception("No instance available at index $index");
      }
      return _wrapInstance(instance);
    });
  }

  //
  @override
  Future<FFIAsset> createInstance({List<MaterialInstance>? materialInstances = null}) async {
    _throwIfNotAlive();
    if (isInstance) {
      return _owner!.createInstance(materialInstances: materialInstances);
    }
    return _enqueueOperation(() async {
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
        SceneAsset_createInstanceRenderThread(_asset, ptrList.address.cast(), materialInstances?.length ?? 0, cb);
      });

      if (FILAMENT_WASM) {
        //stackRestore(stackPtr);
        ptrList.free();
      }

      if (created == nullptr) {
        throw Exception("Failed to create instance");
      }
      // A recycled native instance gets a new object. References to the old
      // object stay destroyed.
      if (_instances[created.address]?._status == _AssetStatus.destroyed) {
        _instances.remove(created.address);
      }
      return _wrapInstance(created);
    });
  }

  //
  @override
  Future<int> getInstanceCount() async {
    _throwIfNotAlive();
    return _enqueueOperation(() async => SceneAsset_getInstanceCount(_asset));
  }

  //
  @override
  Future<List<ThermionAsset>> getInstances() async {
    _throwIfNotAlive();
    return _enqueueOperation(() async => _getInstances());
  }

  List<FFIAsset> _getInstances() {
    var count = SceneAsset_getInstanceCount(_asset);
    final result = List<FFIAsset>.generate(count, (i) {
      _logger.fine("Getting instance at index $i");
      final instance = SceneAsset_getInstance(_asset, i);
      if (instance == nullptr) {
        throw Exception("Failed to get asset instance at index $i");
      }
      return _wrapInstance(instance);
    });

    return result;
  }

  //
  @override
  Future releaseSourceData() async {
    _throwIfNotAlive();
    if (isInstance) {
      throw StateError("releaseSourceData must be called on the owning asset, not an instance");
    }
    if (type != SceneAssetType.gltf) {
      throw StateError("releaseSourceData is only supported on glTF assets");
    }
    return _enqueueOperation(() async {
      if (_sourceDataReleased) {
        throw StateError("The asset's glTF source data has already been released");
      }
      await withVoidCallback((requestId, cb) => SceneAsset_releaseSourceDataRenderThread(_asset, requestId, cb));
      _released = true;
    });
  }

  /// Called by FilamentApp to destroy this asset.
  Future<void> destroy() {
    _throwIfNotAlive();
    _status = _AssetStatus.destroying;
    return _destructionFuture = _enqueueOperation(_destroyNativeResources);
  }

  // Destroys this asset when its owner requests cleanup. Public destroy()
  // would throw after the owner starts destruction: isDestroyed checks the owner.
  // Reuses any destruction already running so the native object is destroyed once.
  Future<void> _destroyFromOwner() {
    if (_destructionFuture != null) {
      return _destructionFuture!;
    }
    _status = _AssetStatus.destroying;
    // A native instance shares the owner's queue. The owner is already waiting
    // for this cleanup, so queuing it there would deadlock.
    // A separately allocated child has its own queue. Run destruction after
    // its accepted operations, such as createInstance(), have finished.
    return _destructionFuture = isInstance ? _destroyNativeResources() : _enqueueOperation(_destroyNativeResources);
  }

  Future<void> _destroyNativeResources() async {
    if (_status == _AssetStatus.destroyed) {
      return;
    }
    _status = _AssetStatus.destroying;
    final pooledInstance = isInstance && SceneAsset_getType(_asset) == TSceneAssetType.SCENE_ASSET_TYPE_GLTF;
    // Lifecycle operations accepted before destruction use the raw handles
    // internally; public handle access is already invalid at this point.
    _removeAnimationComponent();
    if (!isInstance) {
      // Register native instances that have not needed a Dart wrapper yet.
      _getInstances();
    }
    final childErrors = <(int, Object, StackTrace)>[];
    for (final child in _ownedAssets.toList()) {
      // child.isDestroyed also sees this owner's destroying state.
      // Only the child's own status tells us whether its cleanup is complete.
      if (child._status != _AssetStatus.destroyed) {
        try {
          await child._destroyFromOwner();
        } catch (error, stackTrace) {
          childErrors.add((child.entity, error, stackTrace));
        }
      }
    }
    // Attempt every child. A failed child may still use this native asset or
    // its materials, so leave them alive and report the error to the caller.
    if (childErrors.isNotEmpty) {
      for (final (entity, error, stackTrace) in childErrors.skip(1)) {
        _logger.warning('Failed to destroy owned asset $entity', error, stackTrace);
      }
      final (_, error, stackTrace) = childErrors.first;
      Error.throwWithStackTrace(error, stackTrace);
    }
    await withVoidCallback((requestId, cb) => SceneAsset_destroyRenderThread(_asset, requestId, cb));
    await dispose();
    // Geometry instances can share these materials. Release every dependent
    // asset and the native geometry before destroying the owned materials.
    final materialErrors = <(int, Object, StackTrace)>[];
    for (final entry in _ownedMaterialInstances.entries.toList()) {
      try {
        await entry.value.destroy();
        _ownedMaterialInstances.remove(entry.key);
      } catch (error, stackTrace) {
        materialErrors.add((entry.key, error, stackTrace));
      }
    }
    if (materialErrors.isNotEmpty) {
      for (final (address, error, stackTrace) in materialErrors.skip(1)) {
        _logger.warning('Failed to destroy owned material instance $address', error, stackTrace);
      }
      final (_, error, stackTrace) = materialErrors.first;
      Error.throwWithStackTrace(error, stackTrace);
    }
    _status = _AssetStatus.destroyed;
    _owner?._ownedAssets.remove(this);
    if (!isInstance) {
      _instances.clear();
    } else if (!pooledInstance) {
      // Geometry instances are deleted outright. Only pooled native instances
      // stay in the owner's cache after destruction.
      _owner!._instances.remove(_asset.address);
    }
  }

  //
  Future dispose() async {
    _boundingBoxAsset = null;
    _childEntities?.free();
    _childEntities = null;
  }

  //
  Future<v64.Aabb3> getBoundingBox() async {
    _throwIfNotAlive();
    return _getBoundingBox();
  }

  v64.Aabb3 _getBoundingBox() {
    final entities = <ThermionEntity>[];
    if (_app.renderableManager.isRenderable(entity)) {
      entities.add(entity);
    } else {
      entities.addAll(_getChildEntities());
    }

    var boundingBox = v64.Aabb3();

    for (final entity in entities) {
      final aabb3 = _app.renderableManager.getBoundingBox(entity);
      boundingBox.hull(aabb3);
    }
    return boundingBox;
  }

  @override
  Future<FFIAsset> getBoundingBoxAsset() {
    _throwIfNotAlive();
    return _enqueueOperation(() async {
      final existing = _boundingBoxAsset;
      if (existing != null && existing._status == _AssetStatus.alive) {
        return existing;
      }
      await _destroyBoundingBox();
      return _createBoundingBox();
    });
  }

  @override
  Future<void> destroyBoundingBox() {
    _throwIfNotAlive();
    return _enqueueOperation(_destroyBoundingBox);
  }

  Future<void> _destroyBoundingBox() async {
    final box = _boundingBoxAsset;
    if (box != null && box._status != _AssetStatus.destroyed) {
      await box._destroyFromOwner();
    }
    _boundingBoxAsset = null;
  }

  Future<FFIAsset> _createBoundingBox() async {
    final bounds = _getBoundingBox();
    // The bounds are absolute model-space corners.
    // Parenting the box applies this asset's transform.
    final min = [bounds.min.x, bounds.min.y, bounds.min.z];
    final max = [bounds.max.x, bounds.max.y, bounds.max.z];

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
    final indices = Uint16List.fromList([
      // Bottom face
      0, 1, 1, 2, 2, 3, 3, 0,
      // Top face
      4, 5, 5, 6, 6, 7, 7, 4,
      // Vertical edges
      0, 4, 1, 5, 2, 6, 3, 7,
    ]);

    final material = await _app.createUnlitMaterialInstance() as FFIMaterialInstance;
    FFIAsset? box;
    try {
      await material.setParameterFloat4("baseColorFactor", 1.0, 1.0, 0.0, 1.0); // Yellow wireframe.
      // Create geometry for the bounding box.
      final geometry = Geometry(vertices, indices, primitiveType: PrimitiveType.LINES);
      try {
        box = await _app.createGeometry(geometry, materialInstances: [material]) as FFIAsset;
      } finally {
        geometry.dispose();
      }
      // Destroying the box must release its material even if the target stays alive.
      box._ownedMaterialInstances[material.pointer.address] = material;
      await box.setCastShadows(false);
      await box.setReceiveShadows(false);
      await _app.transformManager.setParent(box.entity, entity);
      _ownAsset(box);
      _boundingBoxAsset = box;
      return box;
    } catch (_) {
      if (box != null) {
        await box._destroyFromOwner();
      } else {
        await material.destroy();
      }
      rethrow;
    }
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
    // Flat shading swaps between the BufferObjects created specifically for
    // unwelded geometry. Editable geometry also has preserved buffers, but it
    // deliberately uses ordinary writable streams and cannot perform this
    // swap.
    if (!supportsFlatShading) {
      throw StateError(
        "setFlatShading requires unwelded geometry. "
        "Load it with requiredGeometryCapabilities containing "
        "uniqueTriangleCorners.",
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
    for (final entity in [this.entity, ...await this.getChildEntities()]) {
      if (!_app.renderableManager.isRenderable(entity)) {
        continue;
      }
      await _app.renderableManager.setCastShadows(entity, castShadows);
    }
  }

  //
  Future setReceiveShadows(bool receiveShadows) async {
    for (final entity in [this.entity, ...await this.getChildEntities()]) {
      if (!_app.renderableManager.isRenderable(entity)) {
        continue;
      }
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
    _throwIfNotAlive();
    _removeAnimationComponent();
  }

  void _removeAnimationComponent() {
    // We must remove the animations before freeing the native asset.
    // We use native calls because the public FFIAnimationManager methods
    // cannot be used once this asset is marked as destroying.
    //
    // _destroyNativeResources() marks the asset as destroying before calling
    // this method. FFIAnimationManager.removeGltfAnimationComponent() and
    // removeBoneAnimationComponent() would throw when they read type or
    // call getNativeHandle().
    //
    // Removing those checks would cause a deadlock for glTF owners.
    // Both methods await getInstances(), which adds work to the owner's queue.
    // _destroyNativeResources() would then wait for work queued after itself.
    //
    // The private _getInstances() and _getChildEntities() read native data
    // directly. The native asset is still valid: _destroyNativeResources()
    // calls SceneAsset_destroyRenderThread() after this method returns.
    final type = SceneAsset_getType(_asset);
    if (!{
      TSceneAssetType.SCENE_ASSET_TYPE_GEOMETRY,
      TSceneAssetType.SCENE_ASSET_TYPE_GLTF,
      TSceneAssetType.SCENE_ASSET_TYPE_LIGHT,
    }.contains(type)) {
      return;
    }

    final manager = _app.animationManager.getNativeHandle();
    final animationAsset = type == TSceneAssetType.SCENE_ASSET_TYPE_GLTF && !isInstance
        ? _getInstances().first._asset
        : _asset;
    if (type == TSceneAssetType.SCENE_ASSET_TYPE_GLTF &&
        !AnimationManager_removeGltfAnimationComponent(manager, animationAsset)) {
      _logger.warning("Failed to remove glTF animation component");
    }
    if (!AnimationManager_removeBoneAnimationComponent(manager, animationAsset)) {
      _logger.warning("Failed to remove bone animation component");
    }
    _app.animationManager.removeMorphAnimationComponent(entity);

    for (final child in _getChildEntities()) {
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
    final storageMode = vertexBufferStorageModeFromNative(SceneAsset_getVertexBufferStorageMode(asset, primitiveIndex));
    return FFIVertexBuffer.assetOwned(vbPtr, _app.engine, storageMode: storageMode);
  }
}

enum _AssetStatus { alive, destroying, destroyed }

final class _FFIMorphTargetSet implements MorphTargetSet {
  @override
  final ThermionEntity entity;

  @override
  final List<MorphTarget> targets;

  final RenderableManager _renderableManager;
  late final Map<String, MorphTarget> _targetsByName;
  late final Set<String> _duplicateNames;

  _FFIMorphTargetSet(this.entity, List<MorphTarget> targets, this._renderableManager)
    : targets = List.unmodifiable(targets) {
    final targetsByName = <String, MorphTarget>{};
    final duplicateNames = <String>{};
    for (final target in targets) {
      final name = target.name;
      if (name == null) {
        continue;
      }
      if (targetsByName.containsKey(name)) {
        duplicateNames.add(name);
      } else {
        targetsByName[name] = target;
      }
    }
    _targetsByName = Map.unmodifiable(targetsByName);
    _duplicateNames = Set.unmodifiable(duplicateNames);
  }

  @override
  Future<void> setWeight(String name, double weight) async {
    _validateWeight(weight, 'weight');
    await _renderableManager.setMorphWeightAt(entity, _targetNamed(name).index, weight);
  }

  @override
  Future<void> setWeights(Map<String, double> weights) async {
    final updates = <(MorphTarget, double)>[];
    for (final entry in weights.entries) {
      _validateWeight(entry.value, 'weights["${entry.key}"]');
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
    if (_duplicateNames.contains(name)) {
      throw StateError('Morph target name "$name" is not unique; use setWeightAt instead');
    }
    final target = _targetsByName[name];
    if (target == null) {
      throw ArgumentError.value(name, 'name', 'No morph target has this name');
    }
    return target;
  }

  void _validateWeight(double weight, String argumentName) {
    if (!weight.isFinite) {
      throw ArgumentError.value(weight, argumentName, 'Morph weights must be finite');
    }
  }
}

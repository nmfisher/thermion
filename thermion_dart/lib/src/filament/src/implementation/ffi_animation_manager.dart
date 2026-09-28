import 'package:logging/logging.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/interface/animation_manager.dart';

class FFIAnimationManager extends AnimationManager<Pointer<TAnimationManager>> {
  final Pointer<TAnimationManager> animationManager;
  final FFIFilamentApp app;

  FFIAnimationManager(this.animationManager, this.app);

  @override
  Pointer<TAnimationManager> getNativeHandle() => animationManager;

  @override
  Future<bool> addGltfAnimationComponent(ThermionAsset asset) async {
    if (asset.type != SceneAssetType.gltf) {
      throw Exception("Only supported for glTF assets");
    }

    if (!asset.isInstance) {
      asset = (await asset.getInstances())[0];
    }

    return AnimationManager_addGltfAnimationComponent(animationManager, asset.getNativeHandle());
  }

  late final _logger = Logger(this.runtimeType.toString());

  @override
  Future<bool> removeGltfAnimationComponent(ThermionAsset asset) async {
    if (asset.type != SceneAssetType.gltf) {
      _logger.warning("removeGltfAnimationComponent called on non-glTF asset");
      return false;
    }
    if (!asset.isInstance) {
      asset = (await asset.getInstances())[0];
    }

    return AnimationManager_removeGltfAnimationComponent(animationManager, asset.getNativeHandle());
  }

  @override
  void addMorphAnimationComponent(ThermionEntity entityId) {
    AnimationManager_addMorphAnimationComponent(animationManager, entityId);
  }

  @override
  void removeMorphAnimationComponent(ThermionEntity entityId) {
    AnimationManager_removeMorphAnimationComponent(animationManager, entityId);
  }

  @override
  Future<bool> addBoneAnimationComponent(ThermionAsset asset) async {
    return AnimationManager_addBoneAnimationComponent(animationManager, asset.getNativeHandle());
  }

  @override
  Future<bool> removeBoneAnimationComponent(ThermionAsset asset) async {
    if (!asset.isInstance && asset.type == SceneAssetType.gltf) {
      asset = (await asset.getInstances())[0];
    }
    return AnimationManager_removeBoneAnimationComponent(animationManager, asset.getNativeHandle());
  }

  @override
  bool playGltfAnimation(
    ThermionAsset asset,
    int index, {
    bool loop = false,
    bool reverse = false,
    bool replaceActive = true,
    double crossfade = 0.0,
    double startOffset = 0.0,
    double speed = 1.0,
  }) {
    if (asset.type != SceneAssetType.gltf) {
      throw Exception("Only supported for glTF assets");
    }
    return AnimationManager_playGltfAnimation(
      animationManager,
      asset.getNativeHandle(),
      index,
      loop,
      reverse,
      replaceActive,
      crossfade,
      startOffset,
      speed,
    );
  }

  @override
  bool stopGltfAnimation(ThermionAsset asset, int index) {
    if (asset.type != SceneAssetType.gltf) {
      throw Exception("Only supported for glTF assets");
    }
    return AnimationManager_stopGltfAnimation(animationManager, asset.getNativeHandle(), index);
  }

  @override
  Future<void> setGltfAnimationTime(ThermionAsset asset, int animationIndex, double timeInSeconds) async {
    if (asset.type != SceneAssetType.gltf) {
      throw Exception("Only supported for glTF assets");
    }
    // Dispatch on the render thread: setGltfAnimationTime applies morph-target
    // channels via the backend CommandStream, which asserts it runs on the
    // render thread. The non-RT variant panicked for morph animations.
    await withVoidCallback(
      (requestId, cb) => AnimationManager_setGltfAnimationTimeRenderThread(
        animationManager,
        asset.getNativeHandle(),
        animationIndex,
        timeInSeconds,
        requestId,
        cb,
      ),
    );
  }

  @override
  double getGltfAnimationDuration(ThermionAsset asset, int animationIndex) {
    return AnimationManager_getGltfAnimationDuration(animationManager, asset.getNativeHandle(), animationIndex);
  }

  @override
  int getGltfAnimationCount(ThermionAsset asset) {
    return AnimationManager_getGltfAnimationCount(animationManager, asset.getNativeHandle());
  }

  @override
  String? getGltfAnimationName(ThermionAsset asset, int index) {
    final nameBuffer = allocate<Char>(256); // Allocate buffer for name
    try {
      AnimationManager_getGltfAnimationName(animationManager, asset.getNativeHandle(), nameBuffer, index);

      final name = nameBuffer.cast<Utf8>().toDartString();
      return name.isEmpty ? null : name;
    } finally {
      free(nameBuffer);
    }
  }

  @override
  bool setMorphAnimation(
    ThermionEntity entityId,
    List<double> morphData,
    List<int> morphIndices,
    int numMorphTargets,
    int numFrames,
    double frameLengthInMs,
  ) {
    if (numMorphTargets <= 0) {
      throw RangeError.range(numMorphTargets, 1, null, 'numMorphTargets');
    }
    if (numFrames <= 0) {
      throw RangeError.range(numFrames, 1, null, 'numFrames');
    }
    if (!frameLengthInMs.isFinite || frameLengthInMs <= 0) {
      throw ArgumentError.value(frameLengthInMs, 'frameLengthInMs', 'Must be finite and greater than zero');
    }
    if (morphIndices.length != numMorphTargets) {
      throw ArgumentError.value(
        morphIndices.length,
        'morphIndices.length',
        'Must equal numMorphTargets ($numMorphTargets)',
      );
    }
    final expectedValues = numFrames * numMorphTargets;
    if (morphData.length != expectedValues) {
      throw ArgumentError.value(
        morphData.length,
        'morphData.length',
        'Must equal numFrames * numMorphTargets ($expectedValues)',
      );
    }

    final data = Float32List.fromList(morphData);
    final indices = Int32List.fromList(morphIndices);

    // Scoped borrow: the native side copies the morph data before returning.
    return withNativeBuffers([data, indices], () {
      return AnimationManager_setMorphAnimation(
        animationManager,
        entityId,
        data.address,
        indices.address.cast(),
        numMorphTargets,
        numFrames,
        frameLengthInMs,
      );
    });
  }

  @override
  bool clearMorphAnimation(ThermionEntity entityId) {
    return AnimationManager_clearMorphAnimation(animationManager, entityId);
  }

  @override
  int getMorphTargetNameCount(ThermionAsset asset, ThermionEntity entityId) {
    return AnimationManager_getMorphTargetNameCount(animationManager, asset.getNativeHandle(), entityId);
  }

  @override
  String? getMorphTargetName(ThermionAsset asset, ThermionEntity entityId, int index) {
    final nameBuffer = allocate<Char>(256); // Allocate buffer for name
    try {
      AnimationManager_getMorphTargetName(animationManager, asset.getNativeHandle(), entityId, nameBuffer, index);

      final name = nameBuffer.cast<Utf8>().toDartString();
      return name.isEmpty ? null : name;
    } finally {
      free(nameBuffer);
    }
  }

  @override
  Future<bool> addBoneAnimation(
    ThermionAsset asset,
    int skinIndex,
    int boneIndex,
    List<double> frameData,
    int numFrames,
    double frameLengthInMs, {
    double fadeOutInSecs = 0.0,
    double fadeInInSecs = 0.0,
    double maxDelta = 0.1,
    bool loop = false,
  }) async {
    if (asset.type != SceneAssetType.gltf && asset.type != SceneAssetType.geometry) {
      throw UnimplementedError("TODO");
    }

    if (!asset.isInstance) {
      asset = (await asset.getInstances())[0];
    }

    final data = Float32List.fromList(frameData);

    // Scoped borrow: the native side copies the frame data before returning.
    return withNativeBuffers([data], () {
      return AnimationManager_addBoneAnimation(
        animationManager,
        asset.getNativeHandle(),
        skinIndex,
        boneIndex,
        data.address,
        numFrames,
        frameLengthInMs,
        fadeOutInSecs,
        fadeInInSecs,
        maxDelta,
        loop,
      );
    });
  }

  @override
  Future<List<double>> getRestLocalTransforms(ThermionAsset asset, int skinIndex) async {
    if (asset.type != SceneAssetType.gltf && asset.type != SceneAssetType.geometry) {
      throw UnimplementedError("TODO");
    }

    if (!asset.isInstance) {
      asset = (await asset.getInstances())[0];
    }

    final boneCount = await asset.getBoneCount(skinIndex: skinIndex);

    if (boneCount <= 0) {
      return [];
    }

    // 16 floats per bone (4x4 matrix). Scoped borrow: the native side fills
    // the buffer synchronously and writes are copied back on scope exit.
    final transforms = Float32List(boneCount * 16);
    withNativeBuffers([transforms], () {
      AnimationManager_getRestLocalTransforms(
        animationManager,
        asset.getNativeHandle(),
        skinIndex,
        transforms.address,
        boneCount,
      );
    });

    return transforms.toList();
  }

  @override
  Future<List<double>> getInverseBindMatrix(ThermionAsset asset, int skinIndex, int boneIndex) async {
    if (asset.type != SceneAssetType.gltf && asset.type != SceneAssetType.geometry) {
      throw UnimplementedError("TODO");
    }

    if (!asset.isInstance) {
      asset = (await asset.getInstances())[0];
    }

    // 4x4 matrix. Scoped borrow: filled synchronously by the native side.
    final matrix = Float32List(16);
    withNativeBuffers([matrix], () {
      AnimationManager_getInverseBindMatrix(
        animationManager,
        asset.getNativeHandle(),
        skinIndex,
        boneIndex,
        matrix.address,
      );
    });

    return matrix.toList();
  }

  @override
  Future<bool> updateBoneMatrices(ThermionAsset asset) async {
    if (asset.type != SceneAssetType.gltf && asset.type != SceneAssetType.geometry) {
      throw UnimplementedError("TODO");
    }
    if (!asset.isInstance) {
      asset = (await asset.getInstances())[0];
    }

    return await withBoolCallback(
      (cb) => AnimationManager_updateBoneMatricesRenderThread(animationManager, asset.getNativeHandle(), cb),
    );
  }

  @override
  Future resetToRestPose(ThermionAsset asset) async {
    if (asset.type != SceneAssetType.gltf && asset.type != SceneAssetType.geometry) {
      throw UnimplementedError("TODO");
    }

    if (!asset.isInstance) {
      asset = (await asset.getInstances())[0];
    }

    await withVoidCallback(
      (requestId, cb) =>
          AnimationManager_resetToRestPoseRenderThread(animationManager, asset.getNativeHandle(), requestId, cb),
    );
  }

  @override
  Future update(int frameTimeInNanos) async {
    await withVoidCallback(
      (requestId, cb) =>
          AnimationManager_updateRenderThread(animationManager, frameTimeInNanos.toBigInt, requestId, cb),
    );
  }
}

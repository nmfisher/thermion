import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import '../../../bindings/bindings.dart' as bindings;
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/interface/animation_manager.dart';

/// FFI implementation of AnimationManager for native platforms.
///
/// This class wraps the native Filament AnimationManager and provides
/// a type-safe Dart API for managing animation components.
class FFIAnimationManager
    extends AnimationManager<bindings.Pointer<bindings.TAnimationManager>> {
  final bindings.Pointer<bindings.TAnimationManager> animationManager;
  final FFIFilamentApp app;

  FFIAnimationManager(this.animationManager, this.app);

  @override
  bindings.Pointer<bindings.TAnimationManager> getNativeHandle() =>
      animationManager;

  // ========================================================================
  // Animation component management
  // ========================================================================

  @override
  bool addGltfAnimationComponent(ThermionAsset asset) {
    return bindings.AnimationManager_addGltfAnimationComponent(
        animationManager, asset.getNativeHandle());
  }

  @override
  bool removeGltfAnimationComponent(ThermionAsset asset) {
    return bindings.AnimationManager_removeGltfAnimationComponent(
        animationManager, asset.getNativeHandle());
  }

  @override
  void addMorphAnimationComponent(ThermionEntity entityId) {
    bindings.AnimationManager_addMorphAnimationComponent(
        animationManager, entityId);
  }

  @override
  void removeMorphAnimationComponent(ThermionEntity entityId) {
    bindings.AnimationManager_removeMorphAnimationComponent(
        animationManager, entityId);
  }

  @override
  bool addBoneAnimationComponent(ThermionAsset asset) {
    return bindings.AnimationManager_addBoneAnimationComponent(
        animationManager, asset.getNativeHandle());
  }

  @override
  bool removeBoneAnimationComponent(ThermionAsset asset) {
    return bindings.AnimationManager_removeBoneAnimationComponent(
        animationManager, asset.getNativeHandle());
  }

  // ========================================================================
  // glTF Animation control
  // ========================================================================

  @override
  bool playGltfAnimation(ThermionAsset asset, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      double startOffset = 0.0,
      double speed = 1.0}) {
    return bindings.AnimationManager_playGltfAnimation(
        animationManager,
        asset.getNativeHandle(),
        index,
        loop,
        reverse,
        replaceActive,
        crossfade,
        startOffset,
        speed);
  }

  @override
  bool stopGltfAnimation(ThermionAsset asset, int index) {
    return bindings.AnimationManager_stopGltfAnimation(
        animationManager, asset.getNativeHandle(), index);
  }

  @override
  bool setGltfAnimationTime(
      ThermionAsset asset, int animationIndex, double timeInSeconds) {
    return bindings.AnimationManager_setGltfAnimationTime(
        animationManager, asset.getNativeHandle(), animationIndex, timeInSeconds);
  }

  @override
  double getGltfAnimationDuration(ThermionAsset asset, int animationIndex) {
    return bindings.AnimationManager_getGltfAnimationDuration(
        animationManager, asset.getNativeHandle(), animationIndex);
  }

  @override
  int getGltfAnimationCount(ThermionAsset asset) {
    return bindings.AnimationManager_getGltfAnimationCount(
        animationManager, asset.getNativeHandle());
  }

  @override
  String? getGltfAnimationName(ThermionAsset asset, int index) {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }

    final nameBuffer = allocate<Char>(256); // Allocate buffer for name
    try {
      bindings.AnimationManager_getGltfAnimationName(
          animationManager, asset.getNativeHandle(), nameBuffer, index);

      final name = nameBuffer.cast<Utf8>().toDartString();
      return name.isEmpty ? null : name;
    } finally {
      free(nameBuffer);
      if (FILAMENT_WASM) {
        stackRestore(stackPtr);
      }
    }
  }

  // ========================================================================
  // Morph target animation
  // ========================================================================

  @override
  bool setMorphTargetWeights(ThermionEntity entityId, List<double> weights) {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }

    final weightsPtr = makeFloat32List(weights.length);
    weightsPtr.setRange(0, weights.length, weights);

    try {
      return bindings.AnimationManager_setMorphTargetWeights(
          animationManager, entityId, weightsPtr.address, weights.length);
    } finally {
      weightsPtr.free();
      if (FILAMENT_WASM) {
        stackRestore(stackPtr);
      }
    }
  }

  @override
  bool setMorphAnimation(
      ThermionEntity entityId,
      List<double> morphData,
      List<int> morphIndices,
      int numMorphTargets,
      int numFrames,
      double frameLengthInMs) {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }

    final morphDataPtr = makeFloat32List(morphData.length);
    final morphIndicesPtr = makeInt32List(morphIndices.length);

    morphDataPtr.setRange(0, morphData.length, morphData);
    morphIndicesPtr.setRange(0, morphIndices.length, morphIndices);

    try {
      return bindings.AnimationManager_setMorphAnimation(
          animationManager,
          entityId,
          morphDataPtr.address,
          morphIndicesPtr.address.cast(),
          numMorphTargets,
          numFrames,
          frameLengthInMs);
    } finally {
      morphDataPtr.free();
      morphIndicesPtr.free();
      if (FILAMENT_WASM) {
        stackRestore(stackPtr);
      }
    }
  }

  @override
  bool clearMorphAnimation(ThermionEntity entityId) {
    return bindings.AnimationManager_clearMorphAnimation(
        animationManager, entityId);
  }

  @override
  int getMorphTargetNameCount(ThermionAsset asset, ThermionEntity entityId) {
    return bindings.AnimationManager_getMorphTargetNameCount(
        animationManager, asset.getNativeHandle(), entityId);
  }

  @override
  String? getMorphTargetName(
      ThermionAsset asset, ThermionEntity entityId, int index) {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }

    final nameBuffer = allocate<Char>(256); // Allocate buffer for name
    try {
      bindings.AnimationManager_getMorphTargetName(
          animationManager, asset.getNativeHandle(), entityId, nameBuffer, index);

      final name = nameBuffer.cast<Utf8>().toDartString();
      return name.isEmpty ? null : name;
    } finally {
      free(nameBuffer);
      if (FILAMENT_WASM) {
        stackRestore(stackPtr);
      }
    }
  }

  // ========================================================================
  // Bone animation
  // ========================================================================

  @override
  bool addBoneAnimation(ThermionAsset asset, int skinIndex, int boneIndex,
      List<double> frameData, int numFrames, double frameLengthInMs,
      {double fadeOutInSecs = 0.0,
      double fadeInInSecs = 0.0,
      double maxDelta = 0.1,
      bool loop = false}) {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }

    final frameDataPtr = makeFloat32List(frameData.length);
    frameDataPtr.setRange(0, frameData.length, frameData);

    try {
      return bindings.AnimationManager_addBoneAnimation(
          animationManager,
          asset.getNativeHandle(),
          skinIndex,
          boneIndex,
          frameDataPtr.address,
          numFrames,
          frameLengthInMs,
          fadeOutInSecs,
          fadeInInSecs,
          maxDelta,
          loop);
    } finally {
      frameDataPtr.free();
      if (FILAMENT_WASM) {
        stackRestore(stackPtr);
      }
    }
  }

  @override
  Future<List<double>> getRestLocalTransforms(ThermionAsset asset, int skinIndex) 
  async {
    final boneCount = await asset.getBoneCount(skinIndex:skinIndex);

    if (boneCount <= 0) {
      return [];
    }

    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }

    // 16 floats per bone (4x4 matrix)
    final transformsPtr = makeFloat32List(boneCount * 16);
    try {
      bindings.AnimationManager_getRestLocalTransforms(animationManager,
          asset.getNativeHandle(), skinIndex, transformsPtr.address, boneCount);

      return transformsPtr.toList();
    } finally {
      transformsPtr.free();
      if (FILAMENT_WASM) {
        stackRestore(stackPtr);
      }
    }
  }

  @override
  List<double> getInverseBindMatrix(
      ThermionAsset asset, int skinIndex, int boneIndex) {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }

    final matrixPtr = makeFloat32List(16); // 4x4 matrix
    try {
      bindings.AnimationManager_getInverseBindMatrix(animationManager,
          asset.getNativeHandle(), skinIndex, boneIndex, matrixPtr.address);

      return matrixPtr.toList();
    } finally {
      matrixPtr.free();
      if (FILAMENT_WASM) {
        stackRestore(stackPtr);
      }
    }
  }

  @override
  bool updateBoneMatrices(ThermionAsset asset) {
    return bindings.AnimationManager_updateBoneMatrices(
        animationManager, asset.getNativeHandle());
  }

  // ========================================================================
  // Animation state and pose management
  // ========================================================================

  @override
  void resetToRestPose(ThermionAsset asset) {
    bindings.AnimationManager_resetToRestPose(
        animationManager, asset.getNativeHandle());
  }

  @override
  void update(int frameTimeInNanos) {
    bindings.AnimationManager_update(
        animationManager, frameTimeInNanos.toBigInt);
  }
}

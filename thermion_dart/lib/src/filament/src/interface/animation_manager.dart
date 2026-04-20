import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// Manager for animation components in Filament.
///
/// AnimationManager is used to manage various types of animations including:
/// - glTF animations (pre-defined animation clips)
/// - Bone/skeletal animations
/// - Morph target animations
///
/// This is the primary interface for:
/// - Playing and controlling glTF animations
/// - Managing bone animation components
/// - Setting morph target weights
/// - Animation timeline and playback control
/// - Rest pose and bone transform operations
abstract class AnimationManager<T> extends NativeHandle<T> {
  // ========================================================================
  // Animation component management
  // ========================================================================

  /// Adds a glTF animation component to the specified asset.
  ///
  /// [asset] The asset to add the animation component to
  /// Returns true if successful, false otherwise
  bool addGltfAnimationComponent(ThermionAsset asset);

  /// Removes the glTF animation component from the specified asset.
  ///
  /// [asset] The asset to remove the animation component from
  /// Returns true if successful, false otherwise
  bool removeGltfAnimationComponent(ThermionAsset asset);

  /// Adds a morph animation component to the specified entity.
  ///
  /// [entityId] The entity to add the morph animation component to
  void addMorphAnimationComponent(ThermionEntity entityId);

  /// Removes the morph animation component from the specified entity.
  ///
  /// [entityId] The entity to remove the morph animation component from
  void removeMorphAnimationComponent(ThermionEntity entityId);

  /// Adds a bone animation component to the specified asset.
  ///
  /// [asset] The asset to add the bone animation component to
  /// Returns true if successful, false otherwise
  bool addBoneAnimationComponent(ThermionAsset asset);

  /// Removes the bone animation component from the specified asset.
  ///
  /// [asset] The asset to remove the bone animation component from
  /// Returns true if successful, false otherwise
  bool removeBoneAnimationComponent(ThermionAsset asset);

  // ========================================================================
  // glTF Animation control
  // ========================================================================

  /// Plays a glTF animation with the specified parameters.
  ///
  /// [asset] The asset containing the animation
  /// [index] The animation index to play
  /// [loop] Whether to loop the animation
  /// [reverse] Whether to play the animation in reverse
  /// [replaceActive] Whether to replace any currently active animation
  /// [crossfade] The crossfade duration in seconds when transitioning
  /// [startOffset] The offset into the animation to start from (0.0 to 1.0)
  /// [speed] The playback speed multiplier (1.0 = normal speed)
  /// Returns true if successful, false otherwise
  bool playGltfAnimation(ThermionAsset asset, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      double startOffset = 0.0,
      double speed = 1.0});

  /// Stops a currently playing glTF animation.
  ///
  /// [asset] The asset containing the animation
  /// [index] The animation index to stop
  /// Returns true if successful, false otherwise
  bool stopGltfAnimation(ThermionAsset asset, int index);

  /// Sets the current frame for a glTF animation.
  ///
  /// [asset] The asset containing the animation
  /// [animationIndex] The animation index
  /// [timeInSeconds] The time position in the animation in seconds
  /// Returns true if successful, false otherwise
  bool setGltfAnimationTime(
      ThermionAsset asset, int animationIndex, double timeInSeconds);

  /// Gets the duration of a glTF animation in seconds.
  ///
  /// [asset] The asset containing the animation
  /// [animationIndex] The animation index
  /// Returns the duration in seconds, or 0.0 if not found
  double getGltfAnimationDuration(ThermionAsset asset, int animationIndex);

  /// Gets the number of glTF animations available in the asset.
  ///
  /// [asset] The asset to query
  /// Returns the number of animations
  int getGltfAnimationCount(ThermionAsset asset);

  /// Gets the name of a glTF animation.
  ///
  /// [asset] The asset containing the animation
  /// [index] The animation index
  /// Returns the animation name, or null if not found
  String? getGltfAnimationName(ThermionAsset asset, int index);

  // ========================================================================
  // Morph target animation
  // ========================================================================

  /// Sets morph target weights for an entity.
  ///
  /// [entityId] The entity to set weights for
  /// [weights] List of morph target weights (0.0 to 1.0)
  /// Returns true if successful, false otherwise
  bool setMorphTargetWeights(ThermionEntity entityId, List<double> weights);

  /// Sets up a morph animation with keyframe data.
  ///
  /// [entityId] The entity to animate
  /// [morphData] List of morph target weight values for each frame
  /// [morphIndices] Indices of morph targets to animate
  /// [numMorphTargets] Number of morph targets being animated
  /// [numFrames] Number of animation frames
  /// [frameLengthInMs] Length of each frame in milliseconds
  /// Returns true if successful, false otherwise
  bool setMorphAnimation(
      ThermionEntity entityId,
      List<double> morphData,
      List<int> morphIndices,
      int numMorphTargets,
      int numFrames,
      double frameLengthInMs);

  /// Clears all morph animation data for an entity.
  ///
  /// [entityId] The entity to clear animation for
  /// Returns true if successful, false otherwise
  bool clearMorphAnimation(ThermionEntity entityId);

  /// Gets the number of morph target names for an entity.
  ///
  /// [asset] The asset containing the entity
  /// [entityId] The entity to query
  /// Returns the number of morph target names
  int getMorphTargetNameCount(ThermionAsset asset, ThermionEntity entityId);

  /// Gets the name of a morph target at the specified index.
  ///
  /// [asset] The asset containing the entity
  /// [entityId] The entity to query
  /// [index] The morph target index
  /// Returns the morph target name, or null if not found
  String? getMorphTargetName(
      ThermionAsset asset, ThermionEntity entityId, int index);

  // ========================================================================
  // Bone animation
  // ========================================================================

  /// Adds bone animation data with keyframes.
  ///
  /// [asset] The asset containing the bones
  /// [skinIndex] The skin index containing the bones
  /// [boneIndex] The bone index to animate
  /// [frameData] Transformation data for each frame
  /// [numFrames] Number of animation frames
  /// [frameLengthInMs] Length of each frame in milliseconds
  /// [fadeOutInSecs] Fade out duration in seconds
  /// [fadeInInSecs] Fade in duration in seconds
  /// [maxDelta] Maximum transformation delta per frame
  /// Returns true if successful, false otherwise
  bool addBoneAnimation(ThermionAsset asset, int skinIndex, int boneIndex,
      List<double> frameData, int numFrames, double frameLengthInMs,
      {double fadeOutInSecs = 0.0,
      double fadeInInSecs = 0.0,
      double maxDelta = 0.1,
      bool loop});

  /// Gets the rest pose local transforms for all bones in a skin.
  ///
  /// [asset] The asset containing the bones
  /// [skinIndex] The skin index
  /// Returns a list of 4x4 transformation matrices (16 floats per bone)
  Future<List<double>> getRestLocalTransforms(
      ThermionAsset asset, int skinIndex);

  /// Gets the inverse bind matrix for a specific bone.
  ///
  /// [asset] The asset containing the bones
  /// [skinIndex] The skin index
  /// [boneIndex] The bone index
  /// Returns the 4x4 inverse bind matrix (16 floats), or empty list if not found
  List<double> getInverseBindMatrix(
      ThermionAsset asset, int skinIndex, int boneIndex);

  /// Updates bone matrices for an asset.
  ///
  /// [asset] The asset to update
  /// Returns true if successful, false otherwise
  bool updateBoneMatrices(ThermionAsset asset);

  // ========================================================================
  // Animation state and pose management
  // ========================================================================

  /// Resets an asset to its rest pose.
  ///
  /// [asset] The asset to reset
  void resetToRestPose(ThermionAsset asset);

  /// Updates the animation system with the current frame time.
  ///
  /// [frameTimeInNanos] Frame time in nanoseconds
  void update(int frameTimeInNanos);
}

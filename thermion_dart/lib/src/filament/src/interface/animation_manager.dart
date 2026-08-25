import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

// This is a thin wrapper over the (C++) AnimationManager, which manages glTF
// animations (i.e. animations embedded in glTF assets), as well as
// bone/skeletal animations and/or morph target animations (which users would
// construct manually).
//
// On every frame, the C++ AnimationManager iterates over all animation
// components and performs any updates necessary to advance animations
// that have not yet completed:
// - for glTF animation components, AnimationManager calls the Animator
//   methods on the underlying FilamentInstance
// - for morph target components, AnimationManager calls
//   RenderableManager::setMorphWeights
// - for bone animation components, AnimationManager calls setTransform directly
//   on the bone entities
//
// The (Dart) AnimationManager class is a thin wrapper over the C++ class.
abstract class AnimationManager<T> extends NativeHandle<T> {
  // Adds a glTF animation component to [asset]. These are added at the asset
  // level (rather than entity) because the underlying animator drives the
  // entire FilamentInstance, rather than individual entities.
  // Returns true if successful, false otherwise
  Future<bool> addGltfAnimationComponent(ThermionAsset asset);

  // Removes the glTF animation component from [asset].
  // Returns true if successful, false otherwise.
  Future<bool> removeGltfAnimationComponent(ThermionAsset asset);

  // Adds a morph animation component to [entity].
  // These are added at the entity level (rather than the asset level) because
  // morph targets
  void addMorphAnimationComponent(ThermionEntity entity);

  // Removes the morph animation component from [entity].
  void removeMorphAnimationComponent(ThermionEntity entity);

  // Adds a bone animation component to the specified asset.
  Future<bool> addBoneAnimationComponent(ThermionAsset asset);

  // Removes the bone animation component from the specified asset.
  Future<bool> removeBoneAnimationComponent(ThermionAsset asset);

  // Plays a glTF animation with the specified parameters.
  //
  // [asset] The asset containing the animation
  // [index] The animation index to play
  // [loop] Whether to loop the animation
  // [reverse] Whether to play the animation in reverse
  // [replaceActive] Whether to replace any currently active animation
  // [crossfade] The crossfade duration in seconds when transitioning
  // [startOffset] The offset into the animation to start from (0.0 to 1.0)
  // [speed] The playback speed multiplier (1.0 = normal speed)
  // Returns true if successful, false otherwise
  bool playGltfAnimation(
    ThermionAsset asset,
    int index, {
    bool loop = false,
    bool reverse = false,
    bool replaceActive = true,
    double crossfade = 0.0,
    double startOffset = 0.0,
    double speed = 1.0,
  });

  // Stops a currently playing glTF animation.
  //
  // [asset] The asset containing the animation
  // [index] The animation index to stop
  // Returns true if successful, false otherwise
  bool stopGltfAnimation(ThermionAsset asset, int index);

  // Sets the current frame for a glTF animation.
  //
  // [asset] The asset containing the animation
  // [animationIndex] The animation index
  // [timeInSeconds] The time position in the animation in seconds
  // Returns true if successful, false otherwise
  Future<void> setGltfAnimationTime(ThermionAsset asset, int animationIndex, double timeInSeconds);

  // Gets the duration of a glTF animation in seconds.
  //
  // [asset] The asset containing the animation
  // [animationIndex] The animation index
  // Returns the duration in seconds, or 0.0 if not found
  double getGltfAnimationDuration(ThermionAsset asset, int animationIndex);

  // Gets the number of glTF animations available in the asset.
  //
  // [asset] The asset to query
  // Returns the number of animations
  int getGltfAnimationCount(ThermionAsset asset);

  // Gets the name of a glTF animation.
  //
  // [asset] The asset containing the animation
  // [index] The animation index
  // Returns the animation name, or null if not found
  String? getGltfAnimationName(ThermionAsset asset, int index);

  // Sets up a morph animation with keyframe data.
  //
  // [entityId] The entity to animate
  // [morphData] List of morph target weight values for each frame
  // [morphIndices] Indices of morph targets to animate
  // [numMorphTargets] Number of morph targets being animated
  // [numFrames] Number of animation frames
  // [frameLengthInMs] Length of each frame in milliseconds
  // Returns true if successful, false otherwise
  bool setMorphAnimation(
    ThermionEntity entityId,
    List<double> morphData,
    List<int> morphIndices,
    int numMorphTargets,
    int numFrames,
    double frameLengthInMs,
  );

  // Clears all morph animation data for an entity.
  //
  // [entityId] The entity to clear animation for
  // Returns true if successful, false otherwise
  bool clearMorphAnimation(ThermionEntity entityId);

  // Gets the number of morph target names for an entity.
  //
  // [asset] The asset containing the entity
  // [entityId] The entity to query
  // Returns the number of morph target names
  int getMorphTargetNameCount(ThermionAsset asset, ThermionEntity entityId);

  // Gets the name of a morph target at the specified index.
  //
  // [asset] The asset containing the entity
  // [entityId] The entity to query
  // [index] The morph target index
  // Returns the morph target name, or null if not found
  String? getMorphTargetName(ThermionAsset asset, ThermionEntity entityId, int index);

  // Adds bone animation data with keyframes.
  //
  // [asset] The asset containing the bones
  // [skinIndex] The skin index containing the bones
  // [boneIndex] The bone index to animate
  // [frameData] Transformation data for each frame
  // [numFrames] Number of animation frames
  // [frameLengthInMs] Length of each frame in milliseconds
  // [fadeOutInSecs] Fade out duration in seconds
  // [fadeInInSecs] Fade in duration in seconds
  // [maxDelta] Maximum transformation delta per frame
  // Returns true if successful, false otherwise
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
    bool loop,
  });

  // Gets the rest pose local transforms for all bones in a skin.
  //
  // [asset] The asset containing the bones
  // [skinIndex] The skin index
  // Returns a list of 4x4 transformation matrices (16 floats per bone)
  Future<List<double>> getRestLocalTransforms(ThermionAsset asset, int skinIndex);

  // Gets the inverse bind matrix for a specific bone.
  //
  // [asset] The asset containing the bones [skinIndex] The skin index
  // [boneIndex] The bone index Returns the 4x4 inverse bind matrix (16
  // floats), or empty list if not found
  Future<List<double>> getInverseBindMatrix(ThermionAsset asset, int skinIndex, int boneIndex);

  // Calls [updateBoneMatrices] on the Animator instance for the
  // FilamentInstance (which uses the local bone transform and the inverse bind
  // matrix to set the bone matrix). [asset] The asset to update. This must be
  // an instance. Returns true if successful, false otherwise
  Future<bool> updateBoneMatrices(ThermionAsset asset);

  // Resets [asset] to its rest pose.
  Future resetToRestPose(ThermionAsset asset);

  // Updates the animation system with the current frame time.
  // [frameTimeInNanos] Frame time in nanoseconds
  Future update(int frameTimeInNanos);
}

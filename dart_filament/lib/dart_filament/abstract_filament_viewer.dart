import 'dart:math';

import 'package:vector_math/vector_math_64.dart';
import 'dart:async';
import 'package:animation_tools_dart/animation_tools_dart.dart';
import 'package:dart_filament/dart_filament/entities/filament_entity.dart';

// "picking" means clicking/tapping on the viewport, and unprojecting the X/Y coordinate to determine whether any renderable entities were present at those coordinates.
typedef FilamentPickResult = ({FilamentEntity entity, double x, double y});

enum LightType {
  SUN, //!< Directional light that also draws a sun's disk in the sky.
  DIRECTIONAL, //!< Directional light, emits light in a given direction.
  POINT, //!< Point light, emits light from a position, in all directions.
  FOCUSED_SPOT, //!< Physically correct spot light.
  SPOT,
}

// copied from filament/backened/DriverEnums.h
enum PrimitiveType {
  // don't change the enums values (made to match GL)
  POINTS, //!< points
  LINES, //!< lines
  UNUSED1,
  LINE_STRIP, //!< line strip
  TRIANGLES, //!< triangles
  TRIANGLE_STRIP, //!< triangle strip
}

enum ToneMapper { ACES, FILMIC, LINEAR }

// see filament Manipulator.h for more details
enum ManipulatorMode { ORBIT, MAP, FREE_FLIGHT }

class TextureDetails {
  final int textureId;

  // both width and height are in physical, not logical pixels
  final int width;
  final int height;

  TextureDetails(
      {required this.textureId, required this.width, required this.height});
}

abstract class AbstractFilamentViewer {
  Future<bool> get initialized;

  ///
  /// The result(s) of calling [pick] (see below).
  /// This may be a broadcast stream, so you should ensure you have subscribed to this stream before calling [pick].
  /// If [pick] is called without an active subscription to this stream, the results will be silently discarded.
  ///
  Stream<FilamentPickResult> get pickResult;

  ///
  /// Whether the controller is currently rendering at [framerate].
  ///
  bool get rendering;

  ///
  /// Set to true to continuously render the scene at the framerate specified by [setFrameRate] (60 fps by default).
  ///
  Future setRendering(bool render);

  ///
  /// Render a single frame.
  ///
  Future render();

  ///
  /// Sets the framerate for continuous rendering when [setRendering] is enabled.
  ///
  Future setFrameRate(int framerate);

  ///
  /// Destroys/disposes the viewer (including the entire scene). You cannot use the viewer after calling this method.
  ///
  Future dispose();

  ///
  /// Set the background image to [path] (which should have a file extension .png, .jpg, or .ktx).
  /// This will be rendered at the maximum depth (i.e. behind all other objects including the skybox).
  /// If [fillHeight] is false, the image will be rendered at its original size. Note this may cause issues with pixel density so be sure to specify the correct resolution
  /// If [fillHeight] is true, the image will be stretched/compressed to fit the height of the viewport.
  ///
  Future setBackgroundImage(String path, {bool fillHeight = false});

  ///
  /// Moves the background image to the relative offset from the origin (bottom-left) specified by [x] and [y].
  /// If [clamp] is true, the image cannot be positioned outside the bounds of the viewport.
  ///
  Future setBackgroundImagePosition(double x, double y, {bool clamp = false});

  ///
  /// Removes the background image.
  ///
  Future clearBackgroundImage();

  ///
  /// Sets the color for the background plane (positioned at the maximum depth, i.e. behind all other objects including the skybox).
  ///
  Future setBackgroundColor(double r, double g, double b, double alpha);

  ///
  /// Load a skybox from [skyboxPath] (which must be a .ktx file)
  ///
  Future loadSkybox(String skyboxPath);

  ///
  /// Removes the skybox from the scene.
  ///
  Future removeSkybox();

  ///
  /// Loads an image-based light from the specified path at the given intensity.
  /// Only one IBL can be active at any given time; if an IBL has already been loaded, it will be replaced.
  ///
  Future loadIbl(String lightingPath, {double intensity = 30000});

  ///
  /// Rotates the IBL & skybox.
  ///
  Future rotateIbl(Matrix3 rotation);

  ///
  /// Removes the image-based light from the scene.
  ///
  Future removeIbl();

  ///
  /// Add a light to the scene.
  /// See LightManager.h for details
  /// Note that [sunAngularRadius] is in degrees,
  /// whereas [spotLightConeInner] and [spotLightConeOuter] are in radians
  ///
  Future<FilamentEntity> addLight(
      LightType type,
      double colour,
      double intensity,
      double posX,
      double posY,
      double posZ,
      double dirX,
      double dirY,
      double dirZ,
      {double falloffRadius = 1.0,
      double spotLightConeInner = pi / 8,
      double spotLightConeOuter = pi / 4,
      double sunAngularRadius = 0.545,
      double sunHaloSize = 10.0,
      double sunHaloFallof = 80.0,
      bool castShadows = true});

  Future removeLight(FilamentEntity light);

  ///
  /// Remove all lights (excluding IBL) from the scene.
  ///
  Future clearLights();

  ///
  /// Load the .glb asset at the given path and insert into the scene.
  ///
  Future<FilamentEntity> loadGlb(String path, {int numInstances = 1});

  ///
  /// Create a new instance of [entity].
  ///
  Future<FilamentEntity> createInstance(FilamentEntity entity);

  ///
  /// Returns the number of instances of the asset associated with [entity].
  ///
  Future<int> getInstanceCount(FilamentEntity entity);

  ///
  /// Returns all instances of [entity].
  ///
  Future<List<FilamentEntity>> getInstances(FilamentEntity entity);

  ///
  /// Load the .gltf asset at the given path and insert into the scene.
  /// [relativeResourcePath] is the folder path where the glTF resources are stored;
  /// this is usually the parent directory of the .gltf file itself.
  ///
  Future<FilamentEntity> loadGltf(String path, String relativeResourcePath,
      {bool force = false});

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  Future panStart(double x, double y);

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  Future panUpdate(double x, double y);

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  Future panEnd();

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  Future rotateStart(double x, double y);

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  Future rotateUpdate(double x, double y);

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  Future rotateEnd();

  ///
  /// Set the weights for all morph targets in [entity] to [weights].
  /// Note that [weights] must contain values for ALL morph targets, but no exception will be thrown if you don't do so (you'll just get incorrect results).
  /// If you only want to set one value, set all others to zero (check [getMorphTargetNames] if you need the get a list of all morph targets).
  /// IMPORTANT - this accepts the actual FilamentEntity with the relevant morph targets (unlike [getMorphTargetNames], which uses the parent entity and the child mesh name).
  /// Use [getChildEntityByName] if you are setting the weights for a child mesh.
  ///
  Future setMorphTargetWeights(FilamentEntity entity, List<double> weights);

  ///
  /// Gets the names of all morph targets for the child renderable [childEntity] under [entity].
  ///
  Future<List<String>> getMorphTargetNames(
      FilamentEntity entity, FilamentEntity childEntity);

  ///
  /// Gets the names of all bones for the armature at [skinIndex] under the specified [entity].
  ///
  Future<List<String>> getBoneNames(FilamentEntity entity, {int skinIndex = 0});

  ///
  /// Gets the names of all glTF animations embedded in the specified entity.
  ///
  Future<List<String>> getAnimationNames(FilamentEntity entity);

  ///
  /// Returns the length (in seconds) of the animation at the given index.
  ///
  Future<double> getAnimationDuration(
      FilamentEntity entity, int animationIndex);

  ///
  /// Animate the morph targets in [entity]. See [MorphTargetAnimation] for an explanation as to how to construct the animation frame data.
  /// This method will check the morph target names specified in [animation] against the morph target names that actually exist exist under [meshName] in [entity],
  /// throwing an exception if any cannot be found.
  /// It is permissible for [animation] to omit any targets that do exist under [meshName]; these simply won't be animated.
  ///
  Future setMorphAnimationData(
      FilamentEntity entity, MorphAnimationData animation,
      {List<String>? targetMeshNames});

  ///
  /// Resets all bones in the given entity to their rest pose.
  /// This should be done before every call to addBoneAnimation.
  ///
  Future resetBones(FilamentEntity entity);

  ///
  /// Enqueues and plays the [animation] for the specified bone(s).
  /// By default, frame data is interpreted as being in *parent* bone space;
  /// a 45 degree around Y means the bone will rotate 45 degrees around the
  /// Y axis of the parent bone *in its current orientation*.
  /// (i.e NOT the parent bone's rest position!).
  /// Currently, only [Space.ParentBone] and [Space.Model] are supported; if you want
  /// to transform to another space, you will need to do so manually.
  ///
  Future addBoneAnimation(FilamentEntity entity, BoneAnimationData animation,
      {int skinIndex = 0, double fadeInInSecs=0.0, double fadeOutInSecs=0.0});

  ///
  /// Gets the entity representing the bone at [boneIndex]/[skinIndex].
  /// The returned entity is only intended for use with [getWorldTransform].
  ///
  Future<FilamentEntity> getBone(FilamentEntity parent, int boneIndex,
      {int skinIndex = 0});

  ///
  /// Gets the local (relative to parent) transform for [entity].
  ///
  Future<Matrix4> getLocalTransform(FilamentEntity entity);

  ///
  /// Gets the world transform for [entity].
  ///
  Future<Matrix4> getWorldTransform(FilamentEntity entity);

  ///
  /// Gets the inverse bind (pose) matrix for the bone.
  /// Note that [parent] must be the FilamentEntity returned by [loadGlb/loadGltf], not any other method ([getChildEntity] etc).
  /// This is because all joint information is internally stored with the parent entity.
  ///
  Future<Matrix4> getInverseBindMatrix(FilamentEntity parent, int boneIndex,
      {int skinIndex = 0});

  ///
  /// Sets the transform (relative to its parent) for [entity].
  ///
  Future setTransform(FilamentEntity entity, Matrix4 transform);

  ///
  /// Updates the bone matrices for [entity] (which must be the FilamentEntity 
  /// returned by [loadGlb/loadGltf]).
  /// Under the hood, this just calls [updateBoneMatrices] on the Animator 
  /// instance of the relevant FilamentInstance (which uses the local 
  /// bone transform and the inverse bind matrix to set the bone matrix).
  ///
  Future updateBoneMatrices(FilamentEntity entity);

  ///
  /// Directly set the bone matrix for the bone at the given index.
  /// Don't call this manually unless you know what you're doing.
  ///
  Future setBoneTransform(
      FilamentEntity entity, int boneIndex, Matrix4 transform, { int skinIndex=0});

  ///
  /// Removes/destroys the specified entity from the scene.
  /// [entity] will no longer be a valid handle after this method is called; ensure you immediately discard all references once this method is complete.
  ///
  Future removeEntity(FilamentEntity entity);

  ///
  /// Removes/destroys all renderable entities from the scene (including cameras).
  /// All [FilamentEntity] handles will no longer be valid after this method is called; ensure you immediately discard all references to all entities once this method is complete.
  ///
  Future clearEntities();

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  Future zoomBegin();

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  Future zoomUpdate(double x, double y, double z);

  ///
  /// Called by `FilamentGestureDetector`. You probably don't want to call this yourself.
  ///
  Future zoomEnd();

  ///
  /// Schedules the glTF animation at [index] in [entity] to start playing on the next frame.
  ///
  Future playAnimation(FilamentEntity entity, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0});

  ///
  /// Schedules the glTF animation at [index] in [entity] to start playing on the next frame.
  ///
  Future playAnimationByName(FilamentEntity entity, String name,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0});

  Future setAnimationFrame(
      FilamentEntity entity, int index, int animationFrame);

  Future stopAnimation(FilamentEntity entity, int animationIndex);
  Future stopAnimationByName(FilamentEntity entity, String name);

  ///
  /// Sets the current scene camera to the glTF camera under [name] in [entity].
  ///
  Future setCamera(FilamentEntity entity, String? name);

  ///
  /// Sets the current scene camera to the main camera (which is always available and added to every scene by default).
  ///
  Future setMainCamera();

  ///
  /// Returns the entity associated with the main camera.
  ///
  Future<FilamentEntity> getMainCamera();

  ///
  /// Sets the current scene camera to the glTF camera under [name] in [entity].
  ///
  Future setCameraFov(double degrees, double width, double height);

  ///
  /// Sets the tone mapping (requires postprocessing).
  ///
  Future setToneMapping(ToneMapper mapper);

  ///
  /// Sets the strength of the bloom.
  ///
  Future setBloom(double bloom);

  ///
  /// Sets the focal length of the camera. Default value is 28.0.
  ///
  Future setCameraFocalLength(double focalLength);

  ///
  /// Sets the distance (in world units) to the near/far planes for the active camera. Default values are 0.05/1000.0. See Camera.h for details.
  ///
  Future setCameraCulling(double near, double far);

  ///
  /// Get the distance (in world units) to the near culling plane for the active camera.
  ///
  Future<double> getCameraCullingNear();

  ///
  /// Get the distance (in world units) to the far culling plane for the active camera.
  ///
  Future<double> getCameraCullingFar();

  ///
  /// Sets the focus distance for the camera.
  ///
  Future setCameraFocusDistance(double focusDistance);

  ///
  /// Get the camera position in world space.
  ///
  Future<Vector3> getCameraPosition();

  ///
  /// Get the camera's model matrix.
  ///
  Future<Matrix4> getCameraModelMatrix();

  ///
  /// Get the camera's view matrix. See Camera.h for more details.
  ///
  Future<Matrix4> getCameraViewMatrix();

  ///
  /// Get the camera's projection matrix. See Camera.h for more details.
  ///
  Future<Matrix4> getCameraProjectionMatrix();

  ///
  /// Get the camera's culling projection matrix. See Camera.h for more details.
  ///
  Future<Matrix4> getCameraCullingProjectionMatrix();

  ///
  /// Get the camera's culling frustum in world space. Returns a (vector_math) [Frustum] instance where plane0-plane6 define the left, right, bottom, top, far and near planes respectively.
  /// See Camera.h and (filament) Frustum.h for more details.
  ///
  Future<Frustum> getCameraFrustum();

  ///
  /// Set the camera position in world space. Note this is not persistent - any viewport navigation will reset the camera transform.
  ///
  Future setCameraPosition(double x, double y, double z);

  ///
  /// Get the camera rotation matrix.
  ///
  Future<Matrix3> getCameraRotation();

  ///
  /// Repositions the camera to the last vertex of the bounding box of [entity], looking at the penultimate vertex.
  ///
  Future moveCameraToAsset(FilamentEntity entity);

  ///
  /// Enables/disables frustum culling. Currently we don't expose a method for manipulating the camera projection/culling matrices so this is your only option to deal with unwanted near/far clipping.
  ///
  Future setViewFrustumCulling(bool enabled);

  ///
  /// Sets the camera exposure.
  ///
  Future setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity);

  ///
  /// Rotate the camera by [rads] around the given axis. Note this is not persistent - any viewport navigation will reset the camera transform.
  ///
  Future setCameraRotation(Quaternion quaternion);

  ///
  /// Sets the camera model matrix.
  ///
  Future setCameraModelMatrix(List<double> matrix);

  ///
  /// Sets the `baseColorFactor` property for the material at index [materialIndex] in [entity] under node [meshName] to [color].
  ///
  Future setMaterialColor(FilamentEntity entity, String meshName,
      int materialIndex, double r, double g, double b, double a);

  ///
  /// Scale [entity] to fit within the unit cube.
  ///
  Future transformToUnitCube(FilamentEntity entity);

  ///
  /// Directly sets the world space position for [entity] to the given coordinates, skipping all collision detection.
  ///
  Future setPosition(FilamentEntity entity, double x, double y, double z);

  ///
  /// Directly sets the scale for [entity], skipping all collision detection.
  ///
  Future setScale(FilamentEntity entity, double scale);

  ///
  /// Directly sets the rotation for [entity] to [rads] around the axis {x,y,z}, skipping all collision detection.
  ///
  Future setRotation(
      FilamentEntity entity, double rads, double x, double y, double z);

  ///
  /// Queues an update to the worldspace position for [entity] to {x,y,z}.
  /// The actual update will occur on the next frame, and will be subject to collision detection.
  ///
  Future queuePositionUpdate(
      FilamentEntity entity, double x, double y, double z,
      {bool relative = false});

  ///
  /// Queues an update to the worldspace rotation for [entity].
  /// The actual update will occur on the next frame, and will be subject to collision detection.
  ///
  Future queueRotationUpdate(
      FilamentEntity entity, double rads, double x, double y, double z,
      {bool relative = false});

  ///
  /// Same as [queueRotationUpdate].
  ///
  Future queueRotationUpdateQuat(FilamentEntity entity, Quaternion quat,
      {bool relative = false});

  ///
  /// Enable/disable postprocessing.
  ///
  Future setPostProcessing(bool enabled);

  ///
  /// Set antialiasing options.
  ///
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa);

  ///
  /// Sets the rotation for [entity] to the specified quaternion.
  ///
  Future setRotationQuat(FilamentEntity entity, Quaternion rotation);

  ///
  /// Reveal the node [meshName] under [entity]. Only applicable if [hide] had previously been called; this is a no-op otherwise.
  ///
  Future reveal(FilamentEntity entity, String? meshName);

  ///
  /// If [meshName] is provided, hide the node [meshName] under [entity], otherwise hide the root node for [entity].
  /// The entity still exists in memory, but is no longer being rendered into the scene. Call [reveal] to re-commence rendering.
  ///
  Future hide(FilamentEntity entity, String? meshName);

  ///
  /// Used to select the entity in the scene at the given viewport coordinates.
  /// Called by `FilamentGestureDetector` on a mouse/finger down event. You probably don't want to call this yourself.
  /// This is asynchronous and will require 2-3 frames to complete - subscribe to the [pickResult] stream to receive the results of this method.
  /// [x] and [y] must be in local logical coordinates (i.e. where 0,0 is at top-left of the FilamentWidget).
  ///
  void pick(int x, int y);

  ///
  /// Retrieves the name assigned to the given FilamentEntity (usually corresponds to the glTF mesh name).
  ///
  String? getNameForEntity(FilamentEntity entity);

  ///
  /// Sets the options for manipulating the camera via the viewport.
  /// ManipulatorMode.FREE_FLIGHT and ManipulatorMode.MAP are currently unsupported and will throw an exception.
  ///
  Future setCameraManipulatorOptions(
      {ManipulatorMode mode = ManipulatorMode.ORBIT,
      double orbitSpeedX = 0.01,
      double orbitSpeedY = 0.01,
      double zoomSpeed = 0.01});

  ///
  /// Returns all child entities under [parent].
  ///
  Future<List<FilamentEntity>> getChildEntities(
      FilamentEntity parent, bool renderableOnly);

  ///
  /// Finds the child entity named [childName] associated with the given parent.
  /// Usually, [parent] will be the return value from [loadGlb]/[loadGltf] and [childName] will be the name of a node/mesh.
  ///
  Future<FilamentEntity> getChildEntity(
      FilamentEntity parent, String childName);

  ///
  /// List the name of all child entities under the given entity.
  ///
  Future<List<String>> getChildEntityNames(FilamentEntity entity,
      {bool renderableOnly = true});

  ///
  /// If [recording] is set to true, each frame the framebuffer/texture will be written to /tmp/output_*.png.
  /// This will impact performance; handle with care.
  ///
  Future setRecording(bool recording);

  ///
  /// Sets the output directory where recorded PNGs will be placed.
  ///
  Future setRecordingOutputDirectory(String outputDirectory);

  ///
  /// An [entity] will only be animatable after an animation component is attached.
  /// Any calls to [playAnimation]/[setBoneAnimation]/[setMorphAnimation] will have no visual effect until [addAnimationComponent] has been called on the instance.
  ///
  Future addAnimationComponent(FilamentEntity entity);

  ///
  /// Removes an animation component from [entity].
  ///
  Future removeAnimationComponent(FilamentEntity entity);

  ///
  /// Makes [entity] collidable.
  /// This allows you to call [testCollisions] with any other entity ("entity B") to see if [entity] has collided with entity B. The callback will be invoked if so.
  /// Alternatively, if [affectsTransform] is true and this entity collides with another entity, any queued position updates to the latter entity will be ignored.
  ///
  Future addCollisionComponent(FilamentEntity entity,
      {void Function(int entityId1, int entityId2)? callback,
      bool affectsTransform = false});

  ///
  /// Removes the collision component from [entity], meaning this will no longer be tested when [testCollisions] or [queuePositionUpdate] is called with another entity.
  ///
  Future removeCollisionComponent(FilamentEntity entity);

  ///
  /// Creates a (renderable) entity with the specified geometry and adds to the scene.
  ///
  Future createGeometry(List<double> vertices, List<int> indices,
      {String? materialPath,
      PrimitiveType primitiveType = PrimitiveType.TRIANGLES});

  ///
  /// Gets the parent transform of [child].
  ///
  Future<FilamentEntity?> getParent(FilamentEntity child);

  ///
  /// Sets the parent transform of [child] to [parent].
  ///
  Future setParent(FilamentEntity child, FilamentEntity parent);

  ///
  /// Test all collidable entities against this entity to see if any have collided.
  /// This method returns void; the relevant callback passed to [addCollisionComponent] will be fired if a collision is detected.
  ///
  Future testCollisions(FilamentEntity entity);

  ///
  /// Sets the draw priority for the given entity. See RenderableManager.h for more details.
  ///
  Future setPriority(FilamentEntity entityId, int priority);

  ///
  /// The Scene holds all loaded entities/lights.
  ///
  Scene get scene;

  ///
  ///
  ///
  AbstractGizmo? get gizmo;
}

///
/// For now, this class just holds the entities that have been loaded (though not necessarily visible in the Filament Scene).
///
abstract class Scene {
  ///
  /// The last entity clicked/tapped in the viewport (internally, the result of calling pick);
  FilamentEntity? selected;

  ///
  /// A Stream updated whenever an entity is added/removed from the scene.
  ///
  Stream<bool> get onUpdated;

  ///
  /// A Stream containing every FilamentEntity added to the scene (i.e. via [loadGlb], [loadGltf] or [addLight]).
  /// This is provided for convenience so you can set listeners in front-end widgets that can respond to entity loads without manually passing around the FilamentEntity returned from those methods.
  ///
  Stream<FilamentEntity> get onLoad;

  ///
  /// A Stream containing every FilamentEntity removed from the scene (i.e. via [removeEntity], [clearEntities], [removeLight] or [clearLights]).

  Stream<FilamentEntity> get onUnload;

  ///
  /// Lists all light entities currently loaded (not necessarily active in the scene). Does not account for instances.
  ///
  Iterable<FilamentEntity> listLights();

  ///
  /// Lists all entities currently loaded (not necessarily active in the scene). Does not account for instances.
  ///
  Iterable<FilamentEntity> listEntities();

  ///
  /// Attach the gizmo to the specified entity.
  ///
  void select(FilamentEntity entity);

  ///
  ///
  ///
  void registerEntity(FilamentEntity entity);
}

abstract class AbstractGizmo {
  bool get isActive;

  void translate(double transX, double transY);

  void reset();

  void attach(FilamentEntity entity);

  void detach();
}

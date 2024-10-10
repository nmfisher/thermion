import 'package:thermion_dart/src/viewer/src/events.dart';
import '../../utils/src/gizmo.dart';
import 'shared_types/shared_types.dart';
export 'shared_types/shared_types.dart';

import 'dart:math';
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';
import 'dart:async';
import 'package:animation_tools_dart/animation_tools_dart.dart';

import 'shared_types/view.dart';

const double kNear = 0.05;
const double kFar = 1000.0;
const double kFocalLength = 28.0;

abstract class ThermionViewer {
  ///
  /// A Future that resolves when the underlying rendering context has been successfully created.
  ///
  Future<bool> get initialized;

  ///
  /// The result(s) of calling [pick] (see below).
  /// This may be a broadcast stream, so you should ensure you have subscribed to this stream before calling [pick].
  /// If [pick] is called without an active subscription to this stream, the results will be silently discarded.
  ///
  Stream<FilamentPickResult> get pickResult;

  ///
  /// A Stream containing entities added/removed to/from to the scene.
  ///
  Stream<SceneUpdateEvent> get sceneUpdated;

  ///
  /// Whether the controller is currently rendering at [framerate].
  ///
  bool get rendering;

  ///
  /// Set to true to continuously render the scene at the framerate specified by [setFrameRate] (60 fps by default).
  ///
  Future setRendering(bool render);

  ///
  /// Render a single frame immediately.
  ///
  Future render({covariant SwapChain? swapChain});

  ///
  /// Requests a single frame to be rendered. This is only intended to be used internally.
  ///
  Future requestFrame();

  ///
  /// Render a single frame and copy the pixel buffer to [out].
  ///
  Future<Uint8List> capture(
      {covariant SwapChain? swapChain,
      covariant View? view,
      covariant RenderTarget? renderTarget});

  ///
  ///
  ///
  Future<SwapChain> createHeadlessSwapChain(int width, int height);

  ///
  ///
  ///
  Future<SwapChain> createSwapChain(int handle);

  ///
  ///
  ///
  Future<RenderTarget> createRenderTarget(
      int width, int height, int textureHandle);

  ///
  ///
  ///
  Future setRenderTarget(covariant RenderTarget renderTarget);

  ///
  ///
  ///
  Future<View> createView();

  ///
  ///
  ///
  Future<View> getViewAt(int index);

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
  /// Creates an indirect light by loading the reflections/irradiance from the KTX file.
  /// Only one indirect light can be active at any given time; if an indirect light has already been loaded, it will be replaced.
  ///
  Future loadIbl(String lightingPath, {double intensity = 30000});

  ///
  /// Creates a indirect light with the given color.
  /// Only one indirect light can be active at any given time; if an indirect light has already been loaded, it will be replaced.
  ///
  Future createIbl(double r, double g, double b, double intensity);

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
  @Deprecated(
      "This will be removed in future versions. Use addDirectLight instead.")
  Future<ThermionEntity> addLight(
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

  ///
  /// Adds a direct light to the scene.
  /// See LightManager.h for details
  /// Note that [sunAngularRadius] is in degrees,
  /// whereas [spotLightConeInner] and [spotLightConeOuter] are in radians
  ///
  Future<ThermionEntity> addDirectLight(DirectLight light);

  ///
  /// Remove a light from the scene.
  ///
  Future removeLight(ThermionEntity light);

  ///
  /// Remove all lights (excluding IBL) from the scene.
  ///
  Future clearLights();

  ///
  /// Load the .glb asset at the given path and insert into the scene.
  /// Specify [numInstances] to create multiple instances (this is more efficient than dynamically instantating at a later time). You can then retrieve the created instances with [getInstances].
  /// If you want to be able to call [createInstance] at a later time, you must pass true for [keepData].
  /// If [keepData] is false, the source glTF data will be released and [createInstance] will throw an exception.
  ///
  Future<ThermionEntity> loadGlb(String path,
      {int numInstances = 1, bool keepData = false});

  ///
  /// Load the .glb asset from the specified buffer and insert into the scene.
  /// Specify [numInstances] to create multiple instances (this is more efficient than dynamically instantating at a later time). You can then retrieve the created instances with [getInstances].
  /// If you want to be able to call [createInstance] at a later time, you must pass true for [keepData].
  /// If [keepData] is false, the source glTF data will be released and [createInstance] will throw an exception.
  /// If [loadResourcesAsync] is true, resources (textures, materials, etc) will 
  /// be loaded asynchronously (so expect some material/texture pop-in);
  ///
  ///
  Future<ThermionEntity> loadGlbFromBuffer(Uint8List data,
      {int numInstances = 1,
      bool keepData = false,
      int priority = 4,
      int layer = 0,
      bool loadResourcesAsync});

  ///
  /// Create a new instance of [entity].
  ///
  Future<ThermionEntity> createInstance(ThermionEntity entity);

  ///
  /// Returns the number of instances of the asset associated with [entity].
  ///
  Future<int> getInstanceCount(ThermionEntity entity);

  ///
  /// Returns all instances of [entity].
  ///
  Future<List<ThermionEntity>> getInstances(ThermionEntity entity);

  ///
  /// Load the .gltf asset at the given path and insert into the scene.
  /// [relativeResourcePath] is the folder path where the glTF resources are stored;
  /// this is usually the parent directory of the .gltf file itself.
  ///
  /// See [loadGlb] for an explanation of [keepData].
  ///
  Future<ThermionEntity> loadGltf(String path, String relativeResourcePath,
      {bool keepData = false});

  ///
  /// Set the weights for all morph targets in [entity] to [weights].
  /// Note that [weights] must contain values for ALL morph targets, but no exception will be thrown if you don't do so (you'll just get incorrect results).
  /// If you only want to set one value, set all others to zero (check [getMorphTargetNames] if you need the get a list of all morph targets).
  /// IMPORTANT - this accepts the actual ThermionEntity with the relevant morph targets (unlike [getMorphTargetNames], which uses the parent entity and the child mesh name).
  /// Use [getChildEntityByName] if you are setting the weights for a child mesh.
  ///
  Future setMorphTargetWeights(ThermionEntity entity, List<double> weights);

  ///
  /// Gets the names of all morph targets for the child renderable [childEntity] under [entity].
  ///
  Future<List<String>> getMorphTargetNames(
      ThermionEntity entity, ThermionEntity childEntity);

  ///
  /// Gets the names of all bones for the armature at [skinIndex] under the specified [entity].
  ///
  Future<List<String>> getBoneNames(ThermionEntity entity, {int skinIndex = 0});

  ///
  /// Gets the names of all glTF animations embedded in the specified entity.
  ///
  Future<List<String>> getAnimationNames(ThermionEntity entity);

  ///
  /// Returns the length (in seconds) of the animation at the given index.
  ///
  Future<double> getAnimationDuration(
      ThermionEntity entity, int animationIndex);

  ///
  /// Animate the morph targets in [entity]. See [MorphTargetAnimation] for an explanation as to how to construct the animation frame data.
  /// This method will check the morph target names specified in [animation] against the morph target names that actually exist exist under [meshName] in [entity],
  /// throwing an exception if any cannot be found.
  /// It is permissible for [animation] to omit any targets that do exist under [meshName]; these simply won't be animated.
  ///
  Future setMorphAnimationData(
      ThermionEntity entity, MorphAnimationData animation,
      {List<String>? targetMeshNames});

  ///
  /// Clear all current morph animations for [entity].
  ///
  Future clearMorphAnimationData(ThermionEntity entity);

  ///
  /// Resets all bones in the given entity to their rest pose.
  /// This should be done before every call to addBoneAnimation.
  ///
  Future resetBones(ThermionEntity entity);

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
  Future addBoneAnimation(ThermionEntity entity, BoneAnimationData animation,
      {int skinIndex = 0,
      double fadeInInSecs = 0.0,
      double fadeOutInSecs = 0.0,
      double maxDelta = 1.0});

  ///
  /// Gets the entity representing the bone at [boneIndex]/[skinIndex].
  /// The returned entity is only intended for use with [getWorldTransform].
  ///
  Future<ThermionEntity> getBone(ThermionEntity parent, int boneIndex,
      {int skinIndex = 0});

  ///
  /// Gets the local (relative to parent) transform for [entity].
  ///
  Future<Matrix4> getLocalTransform(ThermionEntity entity);

  ///
  /// Gets the world transform for [entity].
  ///
  Future<Matrix4> getWorldTransform(ThermionEntity entity);

  ///
  /// Gets the inverse bind (pose) matrix for the bone.
  /// Note that [parent] must be the ThermionEntity returned by [loadGlb/loadGltf], not any other method ([getChildEntity] etc).
  /// This is because all joint information is internally stored with the parent entity.
  ///
  Future<Matrix4> getInverseBindMatrix(ThermionEntity parent, int boneIndex,
      {int skinIndex = 0});

  ///
  /// Sets the transform (relative to its parent) for [entity].
  ///
  Future setTransform(ThermionEntity entity, Matrix4 transform);

  ///
  /// Sets multiple transforms (relative to parent) simultaneously for [entity].
  /// Uses mutex to ensure that transform updates aren't split across frames.
  ///
  Future queueTransformUpdates(
      List<ThermionEntity> entities, List<Matrix4> transforms);

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
  /// Removes/destroys the specified entity from the scene.
  /// [entity] will no longer be a valid handle after this method is called; ensure you immediately discard all references once this method is complete.
  ///
  Future removeEntity(ThermionEntity entity);

  ///
  /// Removes/destroys all renderable entities from the scene (including cameras).
  /// All [ThermionEntity] handles will no longer be valid after this method is called; ensure you immediately discard all references to all entities once this method is complete.
  ///
  Future clearEntities();

  ///
  /// Schedules the glTF animation at [index] in [entity] to start playing on the next frame.
  ///
  Future playAnimation(ThermionEntity entity, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      double startOffset = 0.0});

  ///
  /// Schedules the glTF animation at [index] in [entity] to start playing on the next frame.
  ///
  Future playAnimationByName(ThermionEntity entity, String name,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0});

  Future setAnimationFrame(
      ThermionEntity entity, int index, int animationFrame);

  Future stopAnimation(ThermionEntity entity, int animationIndex);
  Future stopAnimationByName(ThermionEntity entity, String name);

  ///
  /// Sets the current scene camera to the glTF camera under [name] in [entity].
  ///
  Future setCamera(ThermionEntity entity, String? name);

  ///
  /// Sets the current scene camera to the main camera (which is always available and added to every scene by default).
  ///
  Future setMainCamera();

  ///
  /// Returns the entity associated with the main camera. You probably never need this; use getMainCamera instead.
  ///
  Future<ThermionEntity> getMainCameraEntity();

  ///
  /// Returns the entity associated with the main camera. You probably never need this; use getMainCamera instead.
  ///
  Future<Camera> getMainCamera();

  ///
  /// Sets the horizontal field of view (if [horizontal] is true) or vertical field of view for the currently active camera to [degrees].
  /// The aspect ratio of the current viewport is used.
  ///
  Future setCameraFov(double degrees, {bool horizontal = true});

  ///
  /// Gets the field of view (in degrees).
  ///
  Future<double> getCameraFov(bool horizontal);

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
  /// Get the distance (in world units) to the near plane for the active camera.
  ///
  @Deprecated("Use getCameraNear")
  Future<double> getCameraCullingNear();

  ///
  /// Get the distance (in world units) to the near plane for the active camera.
  ///
  Future<double> getCameraNear();

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
  Future moveCameraToAsset(ThermionEntity entity);

  ///
  /// Enables/disables frustum culling.
  ///
  Future setViewFrustumCulling(bool enabled);

  ///
  /// Sets the camera exposure.
  ///
  Future setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity);

  ///
  /// Rotate the camera by [rads] around the given axis.
  ///
  Future setCameraRotation(Quaternion quaternion);

  ///
  /// Sets the camera model matrix.
  ///
  @Deprecated("Will be superseded by setCameraModelMatrix4")
  Future setCameraModelMatrix(List<double> matrix);

  ///
  /// Sets the camera model matrix.
  ///
  Future setCameraModelMatrix4(Matrix4 matrix);

  ///
  /// Sets the `baseColorFactor` property for the material at index [materialIndex] in [entity] under node [meshName] to [color].
  ///
  @Deprecated("Use setMaterialPropertyFloat4 instead")
  Future setMaterialColor(ThermionEntity entity, String meshName,
      int materialIndex, double r, double g, double b, double a);

  ///
  /// Sets the material property [propertyName] under material [materialIndex] for [entity] to [value].
  /// [entity] must have a Renderable attached.
  ///
  Future setMaterialPropertyFloat4(ThermionEntity entity, String propertyName,
      int materialIndex, double f1, double f2, double f3, double f4);

  ///
  /// Sets the material property [propertyName] under material [materialIndex] for [entity] to [value].
  /// [entity] must have a Renderable attached.
  ///
  Future setMaterialPropertyFloat(ThermionEntity entity, String propertyName,
      int materialIndex, double value);

  ///
  /// Sets the material property [propertyName] under material [materialIndex] for [entity] to [value].
  /// [entity] must have a Renderable attached.
  ///
  Future setMaterialPropertyInt(
      ThermionEntity entity, String propertyName, int materialIndex, int value);

  ///
  /// Scale [entity] to fit within the unit cube.
  ///
  Future transformToUnitCube(ThermionEntity entity);

  ///
  /// Directly sets the world space position for [entity] to the given coordinates.
  ///
  Future setPosition(ThermionEntity entity, double x, double y, double z);

  ///
  /// Set the world space position for [lightEntity] to the given coordinates.
  ///
  Future setLightPosition(
      ThermionEntity lightEntity, double x, double y, double z);

  ///
  /// Sets the world space direction for [lightEntity] to the given vector.
  ///
  Future setLightDirection(ThermionEntity lightEntity, Vector3 direction);

  ///
  /// Directly sets the scale for [entity], skipping all collision detection.
  ///
  Future setScale(ThermionEntity entity, double scale);

  ///
  /// Directly sets the rotation for [entity] to [rads] around the axis {x,y,z}, skipping all collision detection.
  ///
  Future setRotation(
      ThermionEntity entity, double rads, double x, double y, double z);

  ///
  /// TODO
  ///
  Future queuePositionUpdateFromViewportCoords(
      ThermionEntity entity, double x, double y);

  ///
  /// TODO
  ///
  Future queueRelativePositionUpdateWorldAxis(ThermionEntity entity,
      double viewportX, double viewportY, double x, double y, double z);

  ///
  /// Enable/disable postprocessing (disabled by default).
  ///
  Future setPostProcessing(bool enabled);

  ///
  /// Enable/disable shadows (disabled by default).
  ///
  Future setShadowsEnabled(bool enabled);

  ///
  /// Set shadow type.
  ///
  Future setShadowType(ShadowType shadowType);

  ///
  /// Set soft shadow options (ShadowType DPCF and PCSS)
  ///
  Future setSoftShadowOptions(double penumbraScale, double penumbraRatioScale);

  ///
  /// Set antialiasing options.
  ///
  Future setAntiAliasing(bool msaa, bool fxaa, bool taa);

  ///
  /// Sets the rotation for [entity] to the specified quaternion.
  ///
  Future setRotationQuat(ThermionEntity entity, Quaternion rotation);

  ///
  /// Reveal the node [meshName] under [entity]. Only applicable if [hide] had previously been called; this is a no-op otherwise.
  ///
  Future reveal(ThermionEntity entity, String? meshName);

  ///
  /// If [meshName] is provided, hide the node [meshName] under [entity], otherwise hide the root node for [entity].
  /// The entity still exists in memory, but is no longer being rendered into the scene. Call [reveal] to re-commence rendering.
  ///
  Future hide(ThermionEntity entity, String? meshName);

  ///
  /// Used to select the entity in the scene at the given viewport coordinates.
  /// Called by `FilamentGestureDetector` on a mouse/finger down event. You probably don't want to call this yourself.
  /// This is asynchronous and will require 2-3 frames to complete - subscribe to the [pickResult] stream to receive the results of this method.
  /// [x] and [y] must be in local logical coordinates (i.e. where 0,0 is at top-left of the ThermionWidget).
  ///
  void pick(int x, int y);

  ///
  /// Retrieves the name assigned to the given ThermionEntity (usually corresponds to the glTF mesh name).
  ///
  String? getNameForEntity(ThermionEntity entity);

  ///
  /// Returns all child entities under [parent].
  ///
  Future<List<ThermionEntity>> getChildEntities(
      ThermionEntity parent, bool renderableOnly);

  ///
  /// Finds the child entity named [childName] associated with the given parent.
  /// Usually, [parent] will be the return value from [loadGlb]/[loadGltf] and [childName] will be the name of a node/mesh.
  ///
  Future<ThermionEntity> getChildEntity(
      ThermionEntity parent, String childName);

  ///
  /// List the name of all child entities under the given entity.
  ///
  Future<List<String>> getChildEntityNames(ThermionEntity entity,
      {bool renderableOnly = true});

  ///
  /// An [entity] will only be animatable after an animation component is attached.
  /// Any calls to [playAnimation]/[setBoneAnimation]/[setMorphAnimation] will have no visual effect until [addAnimationComponent] has been called on the instance.
  ///
  Future addAnimationComponent(ThermionEntity entity);

  ///
  /// Removes an animation component from [entity].
  ///
  Future removeAnimationComponent(ThermionEntity entity);

  ///
  /// Makes [entity] collidable.
  /// This allows you to call [testCollisions] with any other entity ("entity B") to see if [entity] has collided with entity B. The callback will be invoked if so.
  /// Alternatively, if [affectsTransform] is true and this entity collides with another entity, any queued position updates to the latter entity will be ignored.
  ///
  Future addCollisionComponent(ThermionEntity entity,
      {void Function(int entityId1, int entityId2)? callback,
      bool affectsTransform = false});

  ///
  /// Removes the collision component from [entity], meaning this will no longer be tested when [testCollisions] or [queuePositionUpdate] is called with another entity.
  ///
  Future removeCollisionComponent(ThermionEntity entity);

  ///
  /// Creates a (renderable) entity with the specified geometry and adds to the scene.
  /// If [keepData] is true, the source data will not be released.
  ///
  Future createGeometry(Geometry geometry,
      {MaterialInstance? materialInstance, bool keepData = false});

  ///
  /// Gets the parent entity of [entity]. Returns null if the entity has no parent.
  ///
  Future<ThermionEntity?> getParent(ThermionEntity entity);

  ///
  /// Gets the ancestor (ultimate parent) entity of [entity]. Returns null if the entity has no parent.
  ///
  Future<ThermionEntity?> getAncestor(ThermionEntity entity);

  ///
  /// Sets the parent transform of [child] to [parent].
  ///
  Future setParent(ThermionEntity child, ThermionEntity parent,
      {bool preserveScaling});

  ///
  /// Test all collidable entities against this entity to see if any have collided.
  /// This method returns void; the relevant callback passed to [addCollisionComponent] will be fired if a collision is detected.
  ///
  Future testCollisions(ThermionEntity entity);

  ///
  /// Sets the draw priority for the given entity. See RenderableManager.h for more details.
  ///
  Future setPriority(ThermionEntity entityId, int priority);

  ///
  /// The gizmo for translating/rotating objects. Only one gizmo can be active for a given view.
  ///
  Future<Gizmo> createGizmo(covariant View view);

  ///
  /// Register a callback to be invoked when this viewer is disposed.
  ///
  void onDispose(Future Function() callback);

  ///
  /// Gets the 2D bounding box (in viewport coordinates) for the given entity.
  ///
  Future<Aabb2> getViewportBoundingBox(ThermionEntity entity);

  ///
  /// Filament assigns renderables to a numeric layer.
  /// We place all scene assets in layer 0 (enabled by default), gizmos in layer 1 (enabled by default), world grid in layer 2 (disabled by default).
  /// Use this method to toggle visibility of the respective layer.
  ///
  Future setLayerVisibility(int layer, bool visible);

  ///
  /// Assigns [entity] to visibility layer [layer].
  ///
  Future setVisibilityLayer(ThermionEntity entity, int layer);

  ///
  /// Renders an outline around [entity] with the given color.
  ///
  Future setStencilHighlight(ThermionEntity entity,
      {double r = 1.0, double g = 0.0, double b = 0.0});

  ///
  /// Removes the outline around [entity]. Noop if there was no highlight.
  ///
  Future removeStencilHighlight(ThermionEntity entity);

  ///
  /// Decodes the specified image data and creates a texture.
  ///
  Future<ThermionTexture> createTexture(Uint8List data);

  ///
  ///
  ///
  Future applyTexture(covariant ThermionTexture texture, ThermionEntity entity,
      {int materialIndex = 0, String parameterName = "baseColorMap"});

  ///
  ///
  ///
  Future destroyTexture(covariant ThermionTexture texture);

  ///
  ///
  ///
  Future<MaterialInstance> createUbershaderMaterialInstance({
    bool doubleSided = false,
    bool unlit = false,
    bool hasVertexColors = false,
    bool hasBaseColorTexture = false,
    bool hasNormalTexture = false,
    bool hasOcclusionTexture = false,
    bool hasEmissiveTexture = false,
    bool useSpecularGlossiness = false,
    AlphaMode alphaMode = AlphaMode.OPAQUE,
    bool enableDiagnostics = false,
    bool hasMetallicRoughnessTexture = false,
    int metallicRoughnessUV = 0,
    int baseColorUV = 0,
    bool hasClearCoatTexture = false,
    int clearCoatUV = 0,
    bool hasClearCoatRoughnessTexture = false,
    int clearCoatRoughnessUV = 0,
    bool hasClearCoatNormalTexture = false,
    int clearCoatNormalUV = 0,
    bool hasClearCoat = false,
    bool hasTransmission = false,
    bool hasTextureTransforms = false,
    int emissiveUV = 0,
    int aoUV = 0,
    int normalUV = 0,
    bool hasTransmissionTexture = false,
    int transmissionUV = 0,
    bool hasSheenColorTexture = false,
    int sheenColorUV = 0,
    bool hasSheenRoughnessTexture = false,
    int sheenRoughnessUV = 0,
    bool hasVolumeThicknessTexture = false,
    int volumeThicknessUV = 0,
    bool hasSheen = false,
    bool hasIOR = false,
    bool hasVolume = false,
  });

  ///
  ///
  ///
  Future destroyMaterialInstance(covariant MaterialInstance materialInstance);

  ///
  ///
  ///
  Future<MaterialInstance> createUnlitMaterialInstance();

  ///
  ///
  ///
  Future<MaterialInstance?> getMaterialInstanceAt(
      ThermionEntity entity, int index);

  ///
  ///
  ///
  Future<Camera> createCamera();

  ///
  ///
  ///
  Future setActiveCamera(covariant Camera camera);

  ///
  ///
  ///
  Future<Camera> getActiveCamera();

  ///
  ///
  ///
  Future registerRequestFrameHook(Future Function() hook);

  ///
  ///
  ///
  Future unregisterRequestFrameHook(Future Function() hook);

  ///
  ///
  ///
  int getCameraCount();

  ///
  /// Returns the camera specified by the given index. Note that the camera at
  /// index 0 is always the main camera; this cannot be destroyed.
  ///
  Camera getCameraAt(int index);
}

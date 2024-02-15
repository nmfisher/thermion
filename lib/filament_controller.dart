// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

import 'package:flutter_filament/animations/animation_data.dart';
import 'package:flutter_filament/entities/entity_transform_controller.dart';
import 'package:vector_math/vector_math_64.dart';

// a handle that can be safely passed back to the rendering layer to manipulate an Entity
typedef FilamentEntity = int;

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

abstract class FilamentController {
  ///
  /// A Stream containing every FilamentEntity added to the scene (i.e. via [loadGlb], [loadGltf] or [addLight]).
  /// This is provided for convenience so you can set listeners in front-end widgets that can respond to entity loads without manually passing around the FilamentEntity returned from those methods.
  ///
  Stream<FilamentEntity> get onLoad;

  ///
  /// A Stream containing every FilamentEntity removed from the scene (i.e. via [removeEntity], [clearEntities], [removeLight] or [clearLights]).

  Stream<FilamentEntity> get onUnload;

  ///
  /// A [ValueNotifier] to indicate whether a FilamentViewer is currently available.
  /// (FilamentViewer is a C++ type, hence why it is not referenced) here.
  /// Call [createViewer]/[destroyViewer] to create/destroy a FilamentViewer.
  ///
  ValueNotifier<bool> get hasViewer;

  ///
  /// Whether a Flutter Texture widget should be inserted into the widget hierarchy.
  /// This will be false on certain platforms where we use a transparent window underlay.
  /// Used internally by [FilamentWidget]; you probably don't need to access this property directly.
  ///
  bool get requiresTextureWidget;

  ///
  /// The Flutter texture ID and dimensions for current texture in use.
  /// This is only used by [FilamentWidget]; you shouldn't need to access directly yourself.
  ///
  final textureDetails = ValueNotifier<TextureDetails?>(null);

  ///
  /// The result(s) of calling [pick] (see below).
  /// This may be a broadcast stream, so you should ensure you have subscribed to this stream before calling [pick].
  /// If [pick] is called without an active subscription to this stream, the results will be silently discarded.
  ///
  Stream<FilamentEntity?> get pickResult;

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
  /// Destroys the viewer and all backing textures. You can leave the FilamentWidget in the hierarchy after this is called, but you will need to manually call [createViewer] to
  ///
  Future destroy();

  ///
  /// Destroys the viewer only, leaving the texture intact. You probably want to call [destroy] instead of this; [destroyViewer] is exposed mostly for lifecycle changes which are handled by FilamentWidget.
  ///
  Future destroyViewer();

  ///
  /// Destroys the specified backing texture. You probably want to call [destroy] instead of this; this is exposed mostly for lifecycle changes which are handled by FilamentWidget.
  ///
  Future destroyTexture();

  ///
  /// Create a FilamentViewer. Must be called at least one frame after a [FilamentWidget] has been inserted into the rendering hierarchy.
  ///
  /// Before a FilamentViewer is created, the FilamentWidget will only contain an empty Container (by default, with a solid red background).
  /// FilamentWidget will then call [setDimensions] with dimensions/pixel ratio of the viewport
  /// Calling [createViewer] will then dispatch a request to the native platform to create a hardware texture (Metal on iOS, OpenGL on Linux, GLES on Android and Windows) and a FilamentViewer (the main interface for manipulating the 3D scene) .
  /// [FilamentWidget] will be notified that a texture is available and will replace the empty Container with a Texture widget
  ///
  Future createViewer();

  ///
  /// Sets the dimensions of the viewport and pixel ratio (obtained from [MediaQuery]) to be used the next time [resize] or [createViewer] is called.
  /// This is called by FilamentWidget; you shouldn't need to invoke this manually.
  ///
  Future setDimensions(ui.Rect rect, double pixelRatio);

  ///
  /// Resize the viewport & backing texture to the current dimensions (as last set by [setDimensions]).
  /// This is called by FilamentWidget; you shouldn't need to invoke this manually.
  ///
  Future resize();

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
  Future setBackgroundColor(Color color);

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
  /// Adds a dynamic light to the scene.
  /// copied from filament LightManager.h
  ///  enum class Type : uint8_t {
  ///       SUN,            //!< Directional light that also draws a sun's disk in the sky.
  ///       DIRECTIONAL,    //!< Directional light, emits light in a given direction.
  ///       POINT,          //!< Point light, emits light from a position, in all directions.
  ///       FOCUSED_SPOT,   //!< Physically correct spot light.
  ///       SPOT,           //!< Spot light with coupling of outer cone and illumination disabled.
  ///   };
  Future<FilamentEntity> addLight(
      int type,
      double colour,
      double intensity,
      double posX,
      double posY,
      double posZ,
      double dirX,
      double dirY,
      double dirZ,
      bool castShadows);

  Future removeLight(FilamentEntity light);

  ///
  /// Remove all lights (excluding IBL) from the scene.
  ///
  Future clearLights();

  ///
  /// Load the .glb asset at the given path and insert into the scene.
  ///
  Future<FilamentEntity> loadGlb(String path, {bool unlit = false});

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
  /// Set the weights for all morph targets under node [meshName] in [entity] to [weights].
  /// Note that [weights] must contain values for ALL morph targets, but no exception will be thrown if you don't do so (you'll just get incorrect results).
  /// If you only want to set one value, set all others to zero (check [getMorphTargetNames] if you need the get a list of all morph targets.)
  ///
  Future setMorphTargetWeights(
      FilamentEntity entity, String meshName, List<double> weights);

  Future<List<String>> getMorphTargetNames(
      FilamentEntity entity, String meshName);

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
      FilamentEntity entity, MorphAnimationData animation);

  ///
  /// Resets all bones in the given entity to their rest pose.
  /// This should be done before every call to addBoneAnimation.
  ///
  Future resetBones(FilamentEntity entity);

  ///
  /// Starts animating a bone (joint) according to the specified [animation].
  ///
  Future addBoneAnimation(FilamentEntity entity, BoneAnimationData animation);

  ///
  /// Sets the local joint transform for the bone at the given index in [entity] for the mesh under [meshName].
  ///
  Future setBoneTransform(
      FilamentEntity entity, String meshName, String boneName, Matrix4 data);

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

  Future setAnimationFrame(
      FilamentEntity entity, int index, int animationFrame);
  Future stopAnimation(FilamentEntity entity, int animationIndex);

  ///
  /// Sets the current scene camera to the glTF camera under [name] in [entity].
  ///
  Future setCamera(FilamentEntity entity, String? name);

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
  Future setCameraRotation(double rads, double x, double y, double z);

  ///
  /// Sets the camera model matrix.
  ///
  Future setCameraModelMatrix(List<double> matrix);

  ///
  /// Sets the `baseColorFactor` property for the material at index [materialIndex] in [entity] under node [meshName] to [color].
  ///
  Future setMaterialColor(
      FilamentEntity entity, String meshName, int materialIndex, Color color);

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
  /// Sets the rotation for [entity] to the specified quaternion.
  ///
  Future setRotationQuat(FilamentEntity entity, Quaternion rotation);

  ///
  /// Reveal the node [meshName] under [entity]. Only applicable if [hide] had previously been called; this is a no-op otherwise.
  ///
  Future reveal(FilamentEntity entity, String meshName);

  ///
  /// Hide the node [meshName] under [entity]. The node is still loaded, but is no longer being rendered into the scene. Call [reveal] to re-commence rendering.
  ///
  Future hide(FilamentEntity entity, String meshName);

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
  /// Finds the child entity named [childName] associated with the given parent.
  /// Usually, [parent] will be the return value from [loadGlb]/[loadGltf] and [childName] will be the name of a node/mesh.
  ///
  Future<FilamentEntity> getChildEntity(
      FilamentEntity parent, String childName);

  ///
  /// Lists all child meshes under the given entity.
  ///
  Future<List<String>> getMeshNames(FilamentEntity entity, {bool async = true});

  ///
  /// If [recording] is set to true, each frame the framebuffer/texture will be written to /tmp/output_*.png.
  /// This will impact performance; handle with care.
  ///
  Future setRecording(bool recording);

  ///
  /// Sets the output directory where recorded PNGs will be placed.
  ///
  Future setRecordingOutputDirectory(String outputDirectory);

  // Stream get keyboardFocusRequested;
  // void requestKeyboardFocus();

  Future<EntityTransformController> control(FilamentEntity entity,
      {double? translationSpeed, String? forwardAnimation});

  ///
  /// Make [collidableEntity] collidable.
  /// At the moment, this is only relevant when controlling a different entity's transform.
  /// If there is a collision between the controlled entity and [collidableEntity], the transform will not be updated.
  ///
  Future addCollisionComponent(FilamentEntity collidableEntity,
      {void Function(int entityId)? callback,
      bool affectsCollingTransform = false});

  ///
  /// Creates a (renderable) entity with the specified geometry and adds to the scene.
  ///
  Future createGeometry(
      List<double> vertices, List<int> indices, String? materialPath);

  ///
  /// Sets the parent transform of [child] to the transform of [parent].
  ///
  Future setParent(FilamentEntity child, FilamentEntity parent);
}

import 'package:thermion_dart/src/viewer/src/shared_types/layers.dart';

import '../../utils/src/gizmo.dart';
import 'shared_types/shared_types.dart';
export 'shared_types/shared_types.dart';

import 'dart:math';
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';
import 'dart:async';
import 'package:animation_tools_dart/animation_tools_dart.dart';

///
/// A high-level interface for interacting with a 3D scene.
/// This broadly maps to a single scene/view
///
abstract class ThermionViewer {
  
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
  Future render();

  ///
  /// Requests a single frame to be rendered. This is only intended to be used internally.
  ///
  Future requestFrame();

  ///
  /// Render a single frame and return the captured image as a pixel buffer.
  ///
  Future<List<Uint8List>> capture(
      covariant List<
              ({View view, SwapChain? swapChain, RenderTarget? renderTarget})>
          targets);

  ///
  ///
  ///
  Future<View> createView();

  ///
  ///
  ///
  Future<View> getViewAt(int index);

  ///
  ///
  ///
  double get msPerFrame;

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
  Future destroyLights();

  ///
  /// Load the .glb asset at the given path, adding all entities to the scene.
  /// Specify [numInstances] to create multiple instances (this is more efficient than dynamically instantating at a later time). You can then retrieve the created instances with [getInstances].
  /// If you want to be able to call [createInstance] at a later time, you must pass true for [keepData].
  /// If [keepData] is false, the source glTF data will be released and [createInstance] will throw an exception.
  ///
  Future<ThermionAsset> loadGlb(String path,
      {int numInstances = 1, bool keepData = false});

  ///
  /// Load the .glb asset from the specified buffer, adding all entities to the scene.
  /// Specify [numInstances] to create multiple instances (this is more efficient than dynamically instantating at a later time). You can then retrieve the created instances with [getInstances].
  /// If you want to be able to call [createInstance] at a later time, you must pass true for [keepData].
  /// If [keepData] is false, the source glTF data will be released and [createInstance] will throw an exception.
  /// If [loadResourcesAsync] is true, resources (textures, materials, etc) will
  /// be loaded asynchronously (so expect some material/texture pop-in);
  ///
  ///
  Future<ThermionAsset> loadGlbFromBuffer(Uint8List data,
      {int numInstances = 1,
      bool keepData = false,
      int priority = 4,
      int layer = 0,
      bool loadResourcesAsync});

  ///
  /// Load the .gltf asset at the given path, adding all entities to the scene.
  /// [relativeResourcePath] is the folder path where the glTF resources are stored;
  /// this is usually the parent directory of the .gltf file itself.
  ///
  /// See [loadGlb] for an explanation of [keepData].
  ///
  Future<ThermionAsset> loadGltf(String path, String relativeResourcePath,
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
      covariant ThermionAsset asset, ThermionEntity childEntity);

  ///
  /// Gets the names of all bones for the armature at [skinIndex] under the specified [entity].
  ///
  Future<List<String>> getBoneNames(covariant ThermionAsset asset,
      {int skinIndex = 0});

  ///
  /// Gets the names of all glTF animations embedded in the specified entity.
  ///
  Future<List<String>> getAnimationNames(covariant ThermionAsset asset);

  ///
  /// Returns the length (in seconds) of the animation at the given index.
  ///
  Future<double> getAnimationDuration(
      covariant ThermionAsset asset, int animationIndex);

  ///
  /// Construct animation(s) for every entity under [asset]. If [targetMeshNames] is provided, only entities with matching names will be animated.
  /// [MorphTargetAnimation] for an explanation as to how to construct the animation frame data.
  /// This method will check the morph target names specified in [animation] against the morph target names that actually exist exist under [meshName] in [entity],
  /// throwing an exception if any cannot be found.
  /// It is permissible for [animation] to omit any targets that do exist under [meshName]; these simply won't be animated.
  ///
  Future setMorphAnimationData(
      covariant ThermionAsset asset, MorphAnimationData animation,
      {List<String>? targetMeshNames});

  ///
  /// Clear all current morph animations for [entity].
  ///
  Future clearMorphAnimationData(ThermionEntity entity);

  ///
  /// Resets all bones in the given entity to their rest pose.
  /// This should be done before every call to addBoneAnimation.
  ///
  Future resetBones(ThermionAsset asset);

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
  Future addBoneAnimation(ThermionAsset asset, BoneAnimationData animation,
      {int skinIndex = 0,
      double fadeInInSecs = 0.0,
      double fadeOutInSecs = 0.0,
      double maxDelta = 1.0});

  ///
  /// Gets the entity representing the bone at [boneIndex]/[skinIndex].
  /// The returned entity is only intended for use with [getWorldTransform].
  ///
  Future<ThermionEntity> getBone(covariant ThermionAsset asset, int boneIndex,
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
  Future<Matrix4> getInverseBindMatrix(
      covariant ThermionAsset asset, int boneIndex,
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
  /// Destroys [asset] and all underlying resources
  /// (including instances, but excluding any manually created material instances).
  ///
  Future destroyAsset(ThermionAsset asset);

  ///
  /// Removes/destroys all renderable entities from the scene (including cameras).
  /// All [ThermionEntity] handles will no longer be valid after this method is called; ensure you immediately discard all references to all entities once this method is complete.
  ///
  Future destroyAssets();

  ///
  /// Schedules the glTF animation at [index] in [asset] to start playing on the next frame.
  ///
  Future playAnimation(ThermionAsset asset, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0,
      double startOffset = 0.0});

  ///
  /// Schedules the glTF animation at [index] in [entity] to start playing on the next frame.
  ///
  Future playAnimationByName(covariant ThermionAsset asset, String name,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0});

  ///
  ///
  ///
  Future setGltfAnimationFrame(
      covariant ThermionAsset asset, int index, int animationFrame);

  ///
  ///
  ///
  Future stopAnimation(covariant ThermionAsset asset, int animationIndex);

  ///
  ///
  ///
  Future stopAnimationByName(covariant ThermionAsset asset, String name);

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
  /// Returns the Camera instance for the main camera.
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
  /// Enable/disable bloom.
  ///
  Future setBloom(bool enabled, double strength);

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
  /// Scale [entity] to fit within the unit cube.
  ///
  Future transformToUnitCube(ThermionEntity entity);

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
  /// Enable/disable postprocessing effects (anti-aliasing, tone mapping, bloom). Disabled by default.
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
  /// Adds a single [entity] to the scene.
  ///
  Future addEntityToScene(ThermionEntity entity);

  ///
  /// Removes a single [entity] from the scene.
  ///
  Future removeAssetFromScene(ThermionEntity entity);

  ///
  /// Hit test the viewport at the given coordinates. If the coordinates intersect
  /// with a renderable entity, [resultHandler] will be called.
  /// This is asynchronous and will require 2-3 frames to complete (so ensure you are calling render())
  /// [x] and [y] must be in local logical coordinates (i.e. where 0,0 is at top-left of the ThermionWidget).
  ///
  Future pick(int x, int y, void Function(PickResult) resultHandler);

  ///
  /// Retrieves the name assigned to the given ThermionEntity (usually corresponds to the glTF mesh name).
  ///
  String? getNameForEntity(ThermionEntity entity);

  ///
  /// Returns all child entities under [asset].
  ///
  Future<List<ThermionEntity>> getChildEntities(covariant ThermionAsset asset);

  ///
  /// Finds the child entity named [childName] associated with the given parent.
  /// Usually, [parent] will be the return value from [loadGlb]/[loadGltf] and [childName] will be the name of a node/mesh.
  ///
  Future<ThermionEntity?> getChildEntity(
      covariant ThermionAsset asset, String childName);

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
  Future<ThermionAsset> createGeometry(Geometry geometry,
      {covariant List<MaterialInstance>? materialInstances,
      bool keepData = false});

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
  Future setParent(ThermionEntity child, ThermionEntity? parent,
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
  Future<GizmoAsset> createGizmo(covariant View view, GizmoType type);

  ///
  /// Register a callback to be invoked when this viewer is disposed.
  ///
  void onDispose(Future Function() callback);

  ///
  /// Gets the 3D axis aligned bounding box for the given entity.
  ///
  Future<Aabb3> getRenderableBoundingBox(ThermionEntity entity);

  ///
  /// Gets the 2D bounding box (in viewport coordinates) for the given entity.
  ///
  Future<Aabb2> getViewportBoundingBox(ThermionEntity entity);

  ///
  /// Toggles the visibility of the respective layer.
  ///
  Future setLayerVisibility(VisibilityLayers layer, bool visible);

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
  ///
  ///
  Future showGridOverlay({covariant Material? material});

  ///
  ///
  ///
  Future removeGridOverlay();

  ///
  ///
  ///
  Future<Texture> createTexture(int width, int height,
      {int depth = 1,
      int levels = 1,
      TextureSamplerType textureSamplerType = TextureSamplerType.SAMPLER_2D,
      TextureFormat textureFormat = TextureFormat.RGBA32F});

  ///
  ///
  ///
  Future<TextureSampler> createTextureSampler(
      {TextureMinFilter minFilter = TextureMinFilter.LINEAR,
      TextureMagFilter magFilter = TextureMagFilter.LINEAR,
      TextureWrapMode wrapS = TextureWrapMode.CLAMP_TO_EDGE,
      TextureWrapMode wrapT = TextureWrapMode.CLAMP_TO_EDGE,
      TextureWrapMode wrapR = TextureWrapMode.CLAMP_TO_EDGE,
      double anisotropy = 0.0,
      TextureCompareMode compareMode = TextureCompareMode.NONE,
      TextureCompareFunc compareFunc = TextureCompareFunc.LESS_EQUAL});

  ///
  /// Decodes the specified image data.
  ///
  Future<LinearImage> decodeImage(Uint8List data);

  ///
  /// Creates an (empty) imge with the given dimensions.
  ///
  Future<LinearImage> createImage(int width, int height, int channels);

  ///
  ///
  ///
  Future<Material> createMaterial(Uint8List data);

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
    int metallicRoughnessUV = -1,
    int baseColorUV = -1,
    bool hasClearCoatTexture = false,
    int clearCoatUV = -1,
    bool hasClearCoatRoughnessTexture = false,
    int clearCoatRoughnessUV = -1,
    bool hasClearCoatNormalTexture = false,
    int clearCoatNormalUV = -1,
    bool hasClearCoat = false,
    bool hasTransmission = false,
    bool hasTextureTransforms = false,
    int emissiveUV = -1,
    int aoUV = -1,
    int normalUV = -1,
    bool hasTransmissionTexture = false,
    int transmissionUV = -1,
    bool hasSheenColorTexture = false,
    int sheenColorUV = -1,
    bool hasSheenRoughnessTexture = false,
    int sheenRoughnessUV = -1,
    bool hasVolumeThicknessTexture = false,
    int volumeThicknessUV = -1,
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
  Future<MaterialInstance> createUnlitFixedSizeMaterialInstance();

  ///
  ///
  ///
  Future<MaterialInstance> getMaterialInstanceAt(
      ThermionEntity entity, int index);

  ///
  ///
  ///
  Future<Camera> createCamera();

  ///
  ///
  ///
  Future destroyCamera(covariant Camera camera);

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
  /// Throws an exception if the index is out-of-bounds.
  ///
  Camera getCameraAt(int index);

  ///
  ///
  ///
  Future setCastShadows(ThermionEntity entity, bool castShadows);

  ///
  ///
  ///
  Future<bool> isCastShadowsEnabled(ThermionEntity entity);

  ///
  ///
  ///
  Future setReceiveShadows(ThermionEntity entity, bool receiveShadows);

  ///
  ///
  ///
  Future<bool> isReceiveShadowsEnabled(ThermionEntity entity);

  ///
  ///
  ///
  Future setClearOptions(
      Vector4 clearColor, int clearStencil, bool clear, bool discard);
}

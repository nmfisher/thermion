import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:polyvox_filament/animations/animation_data.dart';

typedef FilamentEntity = int;

enum ToneMapper { ACES, FILMIC, LINEAR }

class TextureDetails {
  final int textureId;
  final int width;
  final int height;

  TextureDetails(
      {required this.textureId, required this.width, required this.height});
}

abstract class FilamentController {
  
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
  /// A stream to indicate whether a FilamentViewer is available.
  /// [FilamentWidget] will (asynchronously) create a [FilamentViewer] after being inserted into the widget hierarchy;
  /// listen to this stream beforehand to perform any work necessary once the viewer is available.
  /// [FilamentWidget] may also destroy/recreate the viewer on certain lifecycle events (e.g. backgrounding a mobile app);
  /// listen for any corresponding [false]/[true] events to perform related work.
  /// Note this is not a broadcast stream; only one listener can be registered and events will be buffered.
  ///
  Stream<bool> get hasViewer;

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
  /// Called by FilamentGestureDetector to set the pixel ratio (obtained from [MediaQuery]) before creating the texture/viewport.
  /// You may call this yourself if you want to increase/decrease the pixel density of the viewport, but calling this method won't do anything on its own.
  /// You will need to manually recreate the texture/viewer afterwards.
  ///
  void setPixelRatio(double ratio);

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
  /// Called by [FilamentWidget]; you generally will not need to call this yourself.
  /// To recap, you can create a viewport is created in the Flutter rendering hierarchy by:
  /// 1) Create a FilamentController
  /// 2) Insert a FilamentWidget into the rendering tree, passing your FilamentController
  /// 3) Initially, the FilamentWidget will only contain an empty Container (by default, with a solid red background).
  ///    This widget will render a single frame to get its actual size, then will itself call [createViewer]. You do not need to call [createViewer] yourself.
  ///    This will dispatch a request to the native platform to create a hardware texture (Metal on iOS, OpenGL on Linux, GLES on Android and Windows) and a FilamentViewer (the main interface for manipulating the 3D scene) .
  /// 4) The FilamentController will notify FilamentWidget that a texture is available
  /// 5) The FilamentWidget will replace the empty Container with a Texture widget
  /// If you need to wait until a FilamentViewer has been created, listen to the [viewer] stream.
  ///
  Future createViewer(int width, int height);

  ///
  /// Resize the viewport & backing texture.
  /// This is called by FilamentWidget; you shouldn't need to invoke this manually.
  ///
  Future resize(int width, int height, {double scaleFactor = 1.0});

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

  Future<FilamentEntity> loadGlb(String path, {bool unlit = false});

  Future<FilamentEntity> loadGltf(String path, String relativeResourcePath);

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
  /// Set the weights for all morph targets under node [meshName] in [asset] to [weights].
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
  /// Animates morph target weights/bone transforms (where each frame requires a duration of [frameLengthInMs].
  /// [morphWeights] is a list of doubles in frame-major format.
  /// Each frame is [numWeights] in length, and each entry is the weight to be applied to the morph target located at that index in the mesh primitive at that frame.
  /// for now we only allow animating a single bone (though multiple skinned targets are supported)
  ///
  Future setBoneAnimation(FilamentEntity entity, BoneAnimationData animation);

  ///
  /// Removes/destroys the specified entity from the scene.
  /// [asset] will no longer be a valid handle after this method is called; ensure you immediately discard all references once this method is complete.
  ///
  Future removeAsset(FilamentEntity entity);

  ///
  /// Removes/destroys all renderable entities from the scene (including cameras).
  /// All [FilamentEntity] handles will no longer be valid after this method is called; ensure you immediately discard all references to all entities once this method is complete.
  ///
  Future clearAssets();

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
  /// Schedules the glTF animation at [index] in [asset] to start playing on the next frame.
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
  /// Sets the current scene camera to the glTF camera under [name] in [asset].
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
  Future setCameraFocalLength(double focalLength);
  Future setCameraFocusDistance(double focusDistance);
  Future setCameraPosition(double x, double y, double z);

  ///
  /// Repositions the camera to the last vertex of the bounding box of [asset], looking at the penultimate vertex.
  ///
  Future moveCameraToAsset(FilamentEntity entity);

  ///
  /// Enables/disables frustum culling. Currently we don't expose a method for manipulating the camera projection/culling matrices so this is your only option to deal with unwanted near/far clipping.
  ///
  Future setViewFrustumCulling(bool enabled);
  Future setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity);
  Future setCameraRotation(double rads, double x, double y, double z);
  Future setCameraModelMatrix(List<double> matrix);

  Future setMaterialColor(
      FilamentEntity entity, String meshName, int materialIndex, Color color);

  ///
  /// Scales [asset] up/down so it fits within a unit cube.
  ///
  Future transformToUnitCube(FilamentEntity entity);

  ///
  /// Sets the world space position for [asset] to the given coordinates.
  ///
  Future setPosition(FilamentEntity entity, double x, double y, double z);

  ///
  /// Enable/disable postprocessing.
  ///
  Future setPostProcessing(bool enabled);

  ///
  /// Sets the scale for the given entity.
  ///
  Future setScale(FilamentEntity entity, double scale);
  Future setRotation(
      FilamentEntity entity, double rads, double x, double y, double z);

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
}

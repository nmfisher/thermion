import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:polyvox_filament/animations/bone_animation_data.dart';
import 'package:polyvox_filament/animations/morph_animation_data.dart';

typedef FilamentEntity = int;
const FilamentEntity FILAMENT_ASSET_ERROR = 0;

enum ToneMapper { ACES, FILMIC, LINEAR }

abstract class FilamentController {
  // the current target size of the viewport, in logical pixels
  ui.Size size = ui.Size.zero;

  Stream<int?> get textureId;
  Future get isReadyForScene;

  ///
  /// The result(s) of calling [pick] (see below).
  /// This may be a broadcast stream, so you should ensure you have subscribed to this stream before calling [pick].
  /// If [pick] is called without an active subscription to this stream, the results will be silently discarded.
  ///
  Stream<FilamentEntity?> get pickResult;

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
  /// Destroys the viewer and all backing textures. You can leave the FilamentWidget in the hierarchy after this is called, but
  Future destroy();

  ///
  /// Destroys the viewer only, leaving the texture intact. You probably want to call [destroy] instead of this; [destroyViewer] is exposed mostly for lifecycle changes which are handled by FilamentWidget.
  ///
  Future destroyViewer();

  ///
  /// Destroys the backing texture. You probably want to call [destroy] instead of this; this is exposed mostly for lifecycle changes which are handled by FilamentWidget.
  ///
  Future destroyTexture();

  ///
  /// You can insert a Filament viewport into the Flutter rendering hierarchy as follows:
  /// 1) Create a FilamentController
  /// 2) Insert a FilamentWidget into the rendering tree, passing this instance of FilamentController
  /// 3) Initially, the FilamentWidget will only contain an empty Container (by default, with a solid red background).
  ///    This widget will render a single frame to get its actual size, then will itself call [createViewer]. You do not need to call [createViewer] yourself.
  ///    This will dispatch a request to the native platform to create a hardware texture (Metal on iOS, OpenGL on Linux, GLES on Android and Windows) and a FilamentViewer (the main interface for manipulating the 3D scene) .
  /// 4) The FilamentController will notify FilamentWidget that a texture is available
  /// 5) The FilamentWidget will replace the empty Container with a Texture widget
  /// If you need to wait until a FilamentViewer has been created, [await] the [isReadyForScene] Future.
  ///
  Future createViewer(int width, int height);
  Future resize(int width, int height, {double scaleFactor = 1.0});

  Future clearBackgroundImage();
  Future setBackgroundImage(String path, {bool fillHeight = false});

  Future setBackgroundColor(Color color);
  Future setBackgroundImagePosition(double x, double y, {bool clamp = false});
  Future loadSkybox(String skyboxPath);
  Future loadIbl(String lightingPath, {double intensity = 30000});
  Future removeSkybox();
  Future removeIbl();

  // copied from LightManager.h
  //  enum class Type : uint8_t {
  //       SUN,            //!< Directional light that also draws a sun's disk in the sky.
  //       DIRECTIONAL,    //!< Directional light, emits light in a given direction.
  //       POINT,          //!< Point light, emits light from a position, in all directions.
  //       FOCUSED_SPOT,   //!< Physically correct spot light.
  //       SPOT,           //!< Spot light with coupling of outer cone and illumination disabled.
  //   };
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
      FilamentEntity asset, String meshName, List<double> weights);

  Future<List<String>> getMorphTargetNames(
      FilamentEntity asset, String meshName);

  Future<List<String>> getAnimationNames(FilamentEntity asset);

  ///
  /// Returns the length (in seconds) of the animation at the given index.
  ///
  Future<double> getAnimationDuration(FilamentEntity asset, int animationIndex);

  ///
  /// Create/start a dynamic morph target animation for [asset].
  /// Animates morph target weights/bone transforms (where each frame requires a duration of [frameLengthInMs].
  /// [morphWeights] is a list of doubles in frame-major format.
  /// Each frame is [numWeights] in length, and each entry is the weight to be applied to the morph target located at that index in the mesh primitive at that frame.
  ///
  Future setMorphAnimationData(
      FilamentEntity asset, MorphAnimationData animation);

  ///
  /// Animates morph target weights/bone transforms (where each frame requires a duration of [frameLengthInMs].
  /// [morphWeights] is a list of doubles in frame-major format.
  /// Each frame is [numWeights] in length, and each entry is the weight to be applied to the morph target located at that index in the mesh primitive at that frame.
  /// for now we only allow animating a single bone (though multiple skinned targets are supported)
  ///
  Future setBoneAnimation(FilamentEntity asset, BoneAnimationData animation);

  ///
  /// Removes/destroys the specified entity from the scene.
  /// [asset] will no longer be a valid handle after this method is called; ensure you immediately discard all references once this method is complete.
  ///
  Future removeAsset(FilamentEntity asset);

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
  Future playAnimation(FilamentEntity asset, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0});
  Future setAnimationFrame(FilamentEntity asset, int index, int animationFrame);
  Future stopAnimation(FilamentEntity asset, int animationIndex);

  ///
  /// Sets the current scene camera to the glTF camera under [name] in [asset].
  ///
  Future setCamera(FilamentEntity asset, String? name);

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
  Future moveCameraToAsset(FilamentEntity asset);

  ///
  /// Enables/disables frustum culling. Currently we don't expose a method for manipulating the camera projection/culling matrices so this is your only option to deal with unwanted near/far clipping.
  ///
  Future setViewFrustumCulling(bool enabled);
  Future setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity);
  Future setCameraRotation(double rads, double x, double y, double z);
  Future setCameraModelMatrix(List<double> matrix);

  Future setMaterialColor(
      FilamentEntity asset, String meshName, int materialIndex, Color color);

  ///
  /// Scales [asset] up/down so it fits within a unit cube.
  ///
  Future transformToUnitCube(FilamentEntity asset);

  ///
  /// Sets the world space position for [asset] to the given coordinates.
  ///
  Future setPosition(FilamentEntity asset, double x, double y, double z);

  ///
  /// Enable/disable postprocessing.
  ///
  Future setPostProcessing(bool enabled);
  Future setScale(FilamentEntity asset, double scale);
  Future setRotation(
      FilamentEntity asset, double rads, double x, double y, double z);
  Future hide(FilamentEntity asset, String meshName);
  Future reveal(FilamentEntity asset, String meshName);

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

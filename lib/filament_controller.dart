import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:polyvox_filament/animations/bone_animation_data.dart';
import 'package:polyvox_filament/animations/morph_animation_data.dart';
import 'package:polyvox_filament/generated_bindings.dart';

typedef FilamentEntity = int;
const FilamentEntity FILAMENT_ASSET_ERROR = 0;

enum ToneMapper { ACES, FILMIC, LINEAR }

abstract class FilamentController {
  Stream<int?> get textureId;
  Future get isReadyForScene;
  Future setRendering(bool render);
  Future render();
  Future setFrameRate(int framerate);
  void setPixelRatio(double ratio);
  Future destroyViewer();
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
  Future resize(int width, int height, {double contentScaleFactor = 1.0});

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

  Future clearLights();

  Future<FilamentEntity> loadGlb(String path, {bool unlit = false});

  Future<FilamentEntity> loadGltf(String path, String relativeResourcePath);

  Future panStart(double x, double y);
  Future panUpdate(double x, double y);
  Future panEnd();

  Future rotateStart(double x, double y);

  Future rotateUpdate(double x, double y);

  Future rotateEnd();

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
  /// Animates morph target weights/bone transforms (where each frame requires a duration of [frameLengthInMs].
  /// [morphWeights] is a list of doubles in frame-major format.
  /// Each frame is [numWeights] in length, and each entry is the weight to be applied to the morph target located at that index in the mesh primitive at that frame.
  ///
  void setMorphAnimationData(
      FilamentEntity asset, MorphAnimationData animation);

  ///
  /// Animates morph target weights/bone transforms (where each frame requires a duration of [frameLengthInMs].
  /// [morphWeights] is a list of doubles in frame-major format.
  /// Each frame is [numWeights] in length, and each entry is the weight to be applied to the morph target located at that index in the mesh primitive at that frame.
  /// for now we only allow animating a single bone (though multiple skinned targets are supported)
  ///
  void setBoneAnimation(FilamentEntity asset, BoneAnimationData animation);
  void removeAsset(FilamentEntity asset);
  void clearAssets();
  void zoomBegin();
  void zoomUpdate(double z);
  void zoomEnd();
  void playAnimation(FilamentEntity asset, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0});
  void setAnimationFrame(FilamentEntity asset, int index, int animationFrame);
  void stopAnimation(FilamentEntity asset, int animationIndex);
  void setCamera(FilamentEntity asset, String? name);
  void setToneMapping(ToneMapper mapper);
  void setBloom(double bloom);
  void setCameraFocalLength(double focalLength);
  void setCameraFocusDistance(double focusDistance);
  void setCameraPosition(double x, double y, double z);
  void moveCameraToAsset(FilamentEntity asset);
  void setViewFrustumCulling(bool enabled);
  void setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity);
  void setCameraRotation(double rads, double x, double y, double z);
  void setCameraModelMatrix(List<double> matrix);

  void setMaterialColor(
      FilamentEntity asset, String meshName, int materialIndex, Color color);
  void transformToUnitCube(FilamentEntity asset);
  void setPosition(FilamentEntity asset, double x, double y, double z);
  void setScale(FilamentEntity asset, double scale);
  void setRotation(
      FilamentEntity asset, double rads, double x, double y, double z);
  void hide(FilamentEntity asset, String meshName);
  void reveal(FilamentEntity asset, String meshName);
}

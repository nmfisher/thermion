import 'dart:async';
import 'dart:ffi';

import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';

import 'package:flutter/services.dart';
import 'package:polyvox_filament/animations/bone_animation_data.dart';
import 'package:polyvox_filament/animations/morph_animation_data.dart';

typedef AssetManager = int;
typedef FilamentEntity = int;
const FilamentEntity FILAMENT_ASSET_ERROR = 0;

class FilamentController {
  late MethodChannel _channel = MethodChannel("app.polyvox.filament/event");

  double _pixelRatio = 1.0;
  ui.Size size = ui.Size.zero;

  int? _textureId;
  final _textureIdController = StreamController<int?>.broadcast();
  Stream<int?> get textureId => _textureIdController.stream;

  // final _viewerAvailableController = StreamController<bool>.broadcast();
  // Stream<bool> get viewerAvailable => _viewerAvailableController.stream;

  late AssetManager _assetManager;

  ///
  /// This controller uses platform channels to bridge Dart with the C/C++ code for the Filament API.
  /// Setting up the context/texture (since this is platform-specific) and the render ticker are platform-specific; all other methods are passed through by the platform channel to the methods specified in PolyvoxFilamentApi.h.
  ///
  FilamentController() {
    _channel.setMethodCallHandler((call) async {
      throw Exception("Unknown method channel invocation ${call.method}");
    });

    _textureIdController.onListen = () {
      _textureIdController.add(_textureId);
    };
  }

  final _initialSize = Completer<List<int>>();
  void setInitialSize(int width, int height) {
    _initialSize.complete([width, height]);
  }

  ///
  /// The process for initializing the Filament layer is as follows:
  /// 1) Create a FilamentController
  /// 2) Insert a FilamentWidget into the rendering tree
  /// 3) Initially, this widget will only contain an empty Container. After the first frame is rendered, the widget itself will automatically call [setInitialSize] with the width/height from its constraints
  /// 4) Call [initialize], which will create a texture/viewer and notify the FilamentWidget that the texture is available
  /// 5) The FilamentWidget will replace the empty Container with the Texture widget.
  ///
  Future initialize() async {
    var initialSize = await _initialSize.future;
    var initialWidth = initialSize[0];
    var initialHeight = initialSize[1];
    await createViewer(initialWidth, initialHeight);
  }

  Future setRendering(bool render) async {
    _channel.invokeMethod("setRendering", render);
  }

  void render() {
    _channel.invokeMethod("render");
  }

  Future setFrameRate(int framerate) async {
    _channel.invokeMethod("setFrameInterval", 1.0 / framerate);
  }

  void setPixelRatio(double ratio) {
    _pixelRatio = ratio;
  }

  Future destroyViewer() async {
    await _channel.invokeMethod("destroyViewer");
  }

  Future destroyTexture() async {
    await _channel.invokeMethod("destroyTexture");
    _textureId = null;
    _assetManager = 0;
    _textureIdController.add(null);
  }

  Future createViewer(int width, int height) async {
    size = ui.Size(width * _pixelRatio, height * _pixelRatio);
    _textureId =
        await _channel.invokeMethod("createTexture", [size.width, size.height]);

    await _channel
        .invokeMethod("createFilamentViewer", [size.width, size.height]);

    // if (Platform.isLinux) {
    //   // don't pass a surface to the SwapChain as we are effectively creating a headless SwapChain that will render into a RenderTarget associated with a texture
    //   _nativeLibrary.create_swap_chain(
    //        nullptr, size.width.toInt(), size.height.toInt());

    //   var glTextureId = await _channel.invokeMethod("getGlTextureId");

    //   await _channel.invokeMethod("create_render_target(
    //        glTextureId, size.width.toInt(), size.height.toInt());
    // } else {

    // }

    await _channel.invokeMethod("updateViewportAndCameraProjection",
        [size.width.toInt(), size.height.toInt(), 1.0]);

    _assetManager = await _channel.invokeMethod("getAssetManager");
    _textureIdController.add(_textureId);
  }

  Future resize(int width, int height,
      {double contentScaleFactor = 1.0}) async {
    _textureId = await _channel.invokeMethod("resize",
        [width * _pixelRatio, height * _pixelRatio, contentScaleFactor]);
    _textureIdController.add(_textureId);
  }

  void clearBackgroundImage() async {
    await _channel.invokeMethod("clearBackgroundImage");
  }

  void setBackgroundImage(String path) async {
    await _channel.invokeMethod("setBackgroundImage", path);
  }

  void setBackgroundColor(Color color) async {
    await _channel.invokeMethod("setBackgroundColor", [
      color.red.toDouble() / 255.0,
      color.green.toDouble() / 255.0,
      color.blue.toDouble() / 255.0,
      color.alpha.toDouble() / 255.0
    ]);
  }

  void setBackgroundImagePosition(double x, double y,
      {bool clamp = false}) async {
    await _channel
        .invokeMethod("setBackgroundImagePosition", [x, y, clamp ? 1 : 0]);
  }

  void loadSkybox(String skyboxPath) async {
    await _channel.invokeMethod("loadSkybox", skyboxPath);
  }

  void loadIbl(String lightingPath, {double intensity = 30000}) async {
    await _channel.invokeMethod("loadIbl", [lightingPath, intensity]);
  }

  void removeSkybox() async {
    await _channel.invokeMethod("removeSkybox");
  }

  void removeIbl() async {
    await _channel.invokeMethod("removeIbl");
  }

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
      bool castShadows) async {
    var entity = await _channel.invokeMethod("addLight", [
      type,
      colour,
      intensity,
      posX,
      posY,
      posZ,
      dirX,
      dirY,
      dirZ,
      castShadows ? 1 : 0
    ]);
    return entity as FilamentEntity;
  }

  void removeLight(FilamentEntity light) async {
    await _channel.invokeMethod("removeLight", light);
  }

  void clearLights() async {
    await _channel.invokeMethod("clearLights");
  }

  Future<FilamentEntity> loadGlb(String path, {bool unlit = false}) async {
    var asset = await _channel
        .invokeMethod("loadGlb", [_assetManager, path, unlit ? 1 : 0]);
    if (asset == FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading the asset at $path");
    }
    return asset;
  }

  Future<FilamentEntity> loadGltf(
      String path, String relativeResourcePath) async {
    var entity = await _channel
        .invokeMethod("loadGltf", [_assetManager, path, relativeResourcePath]);
    return entity as FilamentEntity;
  }

  void panStart(double x, double y) async {
    await _channel
        .invokeMethod("grabBegin", [x * _pixelRatio, y * _pixelRatio, 1]);
  }

  void panUpdate(double x, double y) async {
    await _channel
        .invokeMethod("grabUpdate", [x * _pixelRatio, y * _pixelRatio]);
  }

  void panEnd() async {
    await _channel.invokeMethod("grabEnd");
  }

  void rotateStart(double x, double y) async {
    await _channel
        .invokeMethod("grabBegin", [x * _pixelRatio, y * _pixelRatio, 0]);
  }

  void rotateUpdate(double x, double y) async {
    await _channel
        .invokeMethod("grabUpdate", [x * _pixelRatio, y * _pixelRatio]);
  }

  void rotateEnd() async {
    await _channel.invokeMethod("grabEnd");
  }

  void setMorphTargetWeights(
      FilamentEntity asset, String meshName, List<double> weights) async {
    await _channel.invokeMethod("setMorphTargetWeights",
        [_assetManager, asset, meshName, weights, weights.length]);
  }

  Future<List<String>> getMorphTargetNames(
      FilamentEntity asset, String meshName) async {
    var names = await _channel
        .invokeMethod("getMorphTargetNames", [_assetManager, asset, meshName]);
    return names.cast<String>();
  }

  Future<List<String>> getAnimationNames(FilamentEntity asset) async {
    var names = await _channel
        .invokeMethod("getAnimationNames", [_assetManager, asset]);
    return names.cast<String>();
  }

  Future<double> getAnimationDuration(
      FilamentEntity asset, int animationIndex) async {
    var duration = await _channel.invokeMethod(
        "getAnimationDuration", [_assetManager, asset, animationIndex]);
    return duration as double;
  }

  ///
  /// Animates morph target weights/bone transforms (where each frame requires a duration of [frameLengthInMs].
  /// [morphWeights] is a list of doubles in frame-major format.
  /// Each frame is [numWeights] in length, and each entry is the weight to be applied to the morph target located at that index in the mesh primitive at that frame.
  ///
  void setMorphAnimationData(
      FilamentEntity asset, MorphAnimationData animation) async {
    await _channel.invokeMethod("setMorphAnimation", [
      _assetManager,
      asset,
      animation.meshName,
      animation.data,
      animation.animatedMorphIndices,
      animation.numMorphTargets,
      animation.numFrames,
      animation.frameLengthInMs
    ]);
  }

  ///
  /// Animates morph target weights/bone transforms (where each frame requires a duration of [frameLengthInMs].
  /// [morphWeights] is a list of doubles in frame-major format.
  /// Each frame is [numWeights] in length, and each entry is the weight to be applied to the morph target located at that index in the mesh primitive at that frame.
  /// for now we only allow animating a single bone (though multiple skinned targets are supported)
  ///
  void setBoneAnimation(
      FilamentEntity asset, BoneAnimationData animation) async {
    var data = calloc<Float>(animation.frameData.length);
    int offset = 0;
    var numFrames = animation.frameData.length ~/ 7;
    var boneNames = calloc<Pointer<Char>>(1);
    boneNames.elementAt(0).value =
        animation.boneName.toNativeUtf8().cast<Char>();

    var meshNames = calloc<Pointer<Char>>(animation.meshNames.length);
    for (int i = 0; i < animation.meshNames.length; i++) {
      meshNames.elementAt(i).value =
          animation.meshNames[i].toNativeUtf8().cast<Char>();
    }

    for (int i = 0; i < animation.frameData.length; i++) {
      data.elementAt(offset).value = animation.frameData[i];
      offset += 1;
    }

    await _channel.invokeMethod("setBoneAnimation", [
      _assetManager,
      asset,
      data,
      numFrames,
      1,
      boneNames,
      meshNames,
      animation.meshNames.length,
      animation.frameLengthInMs
    ]);
    calloc.free(data);
  }

  void removeAsset(FilamentEntity asset) async {
    await _channel.invokeMethod("removeAsset", asset);
  }

  void clearAssets() async {
    await _channel.invokeMethod("clearAssets");
  }

  void zoomBegin() async {
    await _channel.invokeMethod("scrollBegin");
  }

  void zoomUpdate(double z) async {
    await _channel.invokeMethod("scrollUpdate", [0.0, 0.0, z]);
  }

  void zoomEnd() async {
    await _channel.invokeMethod("scrollEnd");
  }

  void playAnimation(FilamentEntity asset, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) async {
    await _channel.invokeMethod("playAnimation", [
      _assetManager,
      asset,
      index,
      loop ? 1 : 0,
      reverse ? 1 : 0,
      replaceActive,
      crossfade
    ]);
  }

  void setAnimationFrame(
      FilamentEntity asset, int index, int animationFrame) async {
    await _channel.invokeMethod(
        "setAnimationFrame", [_assetManager, asset, index, animationFrame]);
  }

  void stopAnimation(FilamentEntity asset, int animationIndex) async {
    await _channel
        .invokeMethod("stopAnimation", [_assetManager, asset, animationIndex]);
  }

  void setCamera(FilamentEntity asset, String? name) async {
    if (await _channel.invokeMethod("setCamera", [asset, name]) != true) {
      throw Exception("Failed to set camera");
    }
  }

  void setCameraFocalLength(double focalLength) async {
    await _channel.invokeMethod("setCameraFocalLength", focalLength);
  }

  void setCameraFocusDistance(double focusDistance) async {
    await _channel.invokeMethod("setCameraFocusDistance", focusDistance);
  }

  void setCameraPosition(double x, double y, double z) async {
    await _channel.invokeMethod("setCameraPosition", [x, y, z]);
  }

  void setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity) async {
    await _channel.invokeMethod(
        "setCameraExposure", [aperture, shutterSpeed, sensitivity]);
  }

  void setCameraRotation(double rads, double x, double y, double z) async {
    await _channel.invokeMethod("setCameraRotation", [rads, x, y, z]);
  }

  void setCameraModelMatrix(List<double> matrix) async {
    assert(matrix.length == 16);
    var ptr = calloc<Float>(16);
    for (int i = 0; i < 16; i++) {
      ptr.elementAt(i).value = matrix[i];
    }
    await _channel.invokeMethod("setCameraModelMatrix", [ptr]);
  }

  void setTexture(FilamentEntity asset, String assetPath,
      {int renderableIndex = 0}) async {
    await _channel.invokeMethod("setTexture", [_assetManager, asset]);
  }

  Future setMaterialColor(FilamentEntity asset, String meshName,
      int materialIndex, Color color) async {
    var result = await _channel.invokeMethod("setMaterialColor", [
      _assetManager,
      asset,
      meshName,
      materialIndex,
      [
        color.red.toDouble() / 255.0,
        color.green.toDouble() / 255.0,
        color.blue.toDouble() / 255.0,
        color.alpha.toDouble() / 255.0
      ]
    ]);
    if (!result) {
      throw Exception("Failed to set material color");
    }
  }

  void transformToUnitCube(FilamentEntity asset) async {
    await _channel.invokeMethod("transformToUnitCube", [_assetManager, asset]);
  }

  void setPosition(FilamentEntity asset, double x, double y, double z) async {
    await _channel.invokeMethod("setPosition", [_assetManager, asset, x, y, z]);
  }

  void setScale(FilamentEntity asset, double scale) async {
    await _channel.invokeMethod("setScale", [_assetManager, asset, scale]);
  }

  void setRotation(
      FilamentEntity asset, double rads, double x, double y, double z) async {
    await _channel
        .invokeMethod("setRotation", [_assetManager, asset, rads, x, y, z]);
  }

  Future hide(FilamentEntity asset, String meshName) async {
    if (await _channel
            .invokeMethod("hideMesh", [_assetManager, asset, meshName]) !=
        1) {
      throw Exception("Failed to hide mesh $meshName");
    }
  }

  Future reveal(FilamentEntity asset, String meshName) async {
    if (await _channel
            .invokeMethod("revealMesh", [_assetManager, asset, meshName]) !=
        1) {
      throw Exception("Failed to reveal mesh $meshName");
    }
  }
}

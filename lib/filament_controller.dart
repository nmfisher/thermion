import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'animations/animation_builder.dart';
import 'animations/animations.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// this is confusing - "FilamentAsset" actually defines a pointer to a SceneAsset, whereas FilamentLight is an Entity ID.
// should make this consistent
typedef FilamentAsset = int;
typedef FilamentLight = int;
const FilamentAsset FILAMENT_ASSET_ERROR = 0;

abstract class FilamentController {
  Size get size;
  late Stream<int> textureId;
  Future get initialized;
  Stream get onInitializationRequested;
  Future initialize();
  Future createTextureViewer(int width, int height);
  Future setFrameRate(int framerate);
  Future setRendering(bool render);
  Future render();
  void setPixelRatio(double ratio);
  Future resize(int width, int height, {double contentScaleFactor = 1});
  Future setBackgroundImage(String path);
  Future setBackgroundImagePosition(double x, double y, {bool clamp = false});
  Future loadSkybox(String skyboxPath);
  Future removeSkybox();
  Future loadIbl(String path);
  Future removeIbl();

  // copied from LightManager.h
  //  enum class Type : uint8_t {
  //       SUN,            //!< Directional light that also draws a sun's disk in the sky.
  //       DIRECTIONAL,    //!< Directional light, emits light in a given direction.
  //       POINT,          //!< Point light, emits light from a position, in all directions.
  //       FOCUSED_SPOT,   //!< Physically correct spot light.
  //       SPOT,           //!< Spot light with coupling of outer cone and illumination disabled.
  //   };
  Future<FilamentLight> addLight(
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
  Future removeLight(FilamentLight light);
  Future clearLights();
  Future<FilamentAsset> loadGlb(String path);
  Future<FilamentAsset> loadGltf(String path, String relativeResourcePath);
  Future zoomBegin();
  Future zoomUpdate(double z);
  Future zoomEnd();
  Future panStart(double x, double y);
  Future panUpdate(double x, double y);
  Future panEnd();
  Future rotateStart(double x, double y);
  Future rotateUpdate(double x, double y);
  Future rotateEnd();
  Future setMorphTargetWeights(FilamentAsset asset, List<double> weights);
  Future<List<String>> getMorphTargetNames(
      FilamentAsset asset, String meshName);
  Future<List<String>> getAnimationNames(FilamentAsset asset);
  Future removeAsset(FilamentAsset asset);
  Future clearAssets();
  Future setAnimationFrame(
      FilamentAsset asset, int animationIndex, int animationFrame);
  Future playAnimation(FilamentAsset asset, int index,
      {bool loop = false, bool reverse = false});
  Future playAnimations(FilamentAsset asset, List<int> indices,
      {bool loop = false, bool reverse = false});
  Future stopAnimation(FilamentAsset asset, int index);
  Future setCamera(FilamentAsset asset, String name);
  Future setTexture(FilamentAsset asset, String assetPath,
      {int renderableIndex = 0});
  Future transformToUnitCube(FilamentAsset asset);
  Future setPosition(FilamentAsset asset, double x, double y, double z);
  Future setRotation(
      FilamentAsset asset, double rads, double x, double y, double z);
  // Future setBoneTransform(FilamentAsset asset, String boneName, String meshName,
  //     BoneTransform transform);
  Future setScale(FilamentAsset asset, double scale);
  Future setCameraFocalLength(double focalLength);
  Future setCameraFocusDistance(double focusDistance);
  Future setCameraPosition(double x, double y, double z);
  Future setCameraRotation(double rads, double x, double y, double z);
  Future setCameraModelMatrix(List<double> matrix);

  ///
  /// Animates morph target weights/bone transforms (where each frame requires a duration of [frameLengthInMs].
  /// [morphWeights] is a list of doubles in frame-major format.
  /// Each frame is [numWeights] in length, and each entry is the weight to be applied to the morph target located at that index in the mesh primitive at that frame.
  ///
  Future setAnimation(FilamentAsset asset, Animation animation);
}

class PolyvoxFilamentController extends FilamentController {
  late MethodChannel _channel = MethodChannel("app.polyvox.filament/event");

  double _pixelRatio = 1.0;
  Size size = Size(0, 0);

  final _textureIdController = StreamController<int>();
  Stream<int> get textureId => _textureIdController.stream;

  final _onInitRequestedController = StreamController.broadcast();
  Stream get onInitializationRequested => _onInitRequestedController.stream;

  final _initialized = Completer();
  Future get initialized => _initialized.future;

  PolyvoxFilamentController() {
    _channel.setMethodCallHandler((call) async {
      print("Received Filament method channel call : ${call.method}");
      throw Exception("Unknown method channel invocation ${call.method}");
    });
  }

  Future initialize() async {
    _onInitRequestedController.add(true);
    return _initialized.future;
  }

  Future setRendering(bool render) async {
    await _channel.invokeMethod("setRendering", render);
  }

  Future render() async {
    await _channel.invokeMethod("render");
  }

  Future setFrameRate(int framerate) async {
    await _channel.invokeMethod("setFrameInterval", 1 / framerate);
  }

  void setPixelRatio(double ratio) {
    print("Set pixel ratio to $ratio");
    _pixelRatio = ratio;
  }

  Future createTextureViewer(int width, int height) async {
    size = Size(width * _pixelRatio, height * _pixelRatio);
    print("Creating texture of size $size");
    var textureId =
        await _channel.invokeMethod("initialize", [size.width, size.height]);
    _textureIdController.add(textureId);
    _initialized.complete(true);
  }

  Future resize(int width, int height,
      {double contentScaleFactor = 1.0}) async {
    size = Size(width * _pixelRatio, height * _pixelRatio);

    var textureId = await _channel.invokeMethod("resize",
        [width * _pixelRatio, height * _pixelRatio, contentScaleFactor]);
    print("Resized to $size with texutre Id $textureId");
    _textureIdController.add(textureId);
  }

  @override
  Future setBackgroundImage(String path) async {
    await _channel.invokeMethod("setBackgroundImage", path);
  }

  @override
  Future setBackgroundImagePosition(double x, double y,
      {bool clamp = false}) async {
    await _channel.invokeMethod("setBackgroundImagePosition", [x, y, clamp]);
  }

  @override
  Future loadSkybox(String skyboxPath) async {
    await _channel.invokeMethod("loadSkybox", skyboxPath);
  }

  @override
  Future loadIbl(String lightingPath) async {
    await _channel.invokeMethod("loadIbl", lightingPath);
  }

  @override
  Future removeSkybox() async {
    await _channel.invokeMethod("removeSkybox");
  }

  @override
  Future removeIbl() async {
    await _channel.invokeMethod("removeIbl");
  }

  @override
  Future<FilamentLight> addLight(
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
    var entityId = await _channel.invokeMethod("addLight", [
      type,
      colour,
      intensity,
      posX,
      posY,
      posZ,
      dirX,
      dirY,
      dirZ,
      castShadows
    ]);
    return entityId as FilamentLight;
  }

  @override
  Future removeLight(FilamentLight light) {
    return _channel.invokeMethod("removeLight", light);
  }

  @override
  Future clearLights() {
    return _channel.invokeMethod("clearLights");
  }

  Future<FilamentAsset> loadGlb(String path) async {
    print("Loading GLB at $path ");
    var asset = await _channel.invokeMethod("loadGlb", path);
    if (asset == FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading the asset at $path");
    }
    return asset as FilamentAsset;
  }

  Future<FilamentAsset> loadGltf(
      String path, String relativeResourcePath) async {
    print(
        "Loading GLTF at $path with relative resource path $relativeResourcePath");
    var asset =
        await _channel.invokeMethod("loadGltf", [path, relativeResourcePath]);
    return asset as FilamentAsset;
  }

  Future panStart(double x, double y) async {
    await _channel.invokeMethod("panStart", [x * _pixelRatio, y * _pixelRatio]);
  }

  Future panUpdate(double x, double y) async {
    await _channel
        .invokeMethod("panUpdate", [x * _pixelRatio, y * _pixelRatio]);
  }

  Future panEnd() async {
    await _channel.invokeMethod("panEnd");
  }

  Future rotateStart(double x, double y) async {
    await _channel
        .invokeMethod("rotateStart", [x * _pixelRatio, y * _pixelRatio]);
  }

  Future rotateUpdate(double x, double y) async {
    await _channel
        .invokeMethod("rotateUpdate", [x * _pixelRatio, y * _pixelRatio]);
  }

  Future rotateEnd() async {
    await _channel.invokeMethod("rotateEnd");
  }

  Future setMorphTargetWeights(
      FilamentAsset asset, List<double> weights) async {
    await _channel.invokeMethod(
        "setMorphTargetWeights", [asset, Float32List.fromList(weights)]);
  }

  Future<List<String>> getMorphTargetNames(
      FilamentAsset asset, String meshName) async {
    var result =
        (await _channel.invokeMethod("getMorphTargetNames", [asset, meshName]))
            .cast<String>();
    return result;
  }

  Future<List<String>> getAnimationNames(FilamentAsset asset) async {
    var result = (await _channel.invokeMethod("getAnimationNames", asset))
        .cast<String>();
    return result;
  }

  Future setAnimation(FilamentAsset asset, Animation animation) async {
    await _channel.invokeMethod("setAnimation", [
      asset,
      animation.morphData!,
      animation.numMorphWeights,
      animation.boneAnimations?.map((a) => a.toList()).toList() ?? [],
      animation.numFrames,
      animation.frameLengthInMs
    ]);
  }

  Future removeAsset(FilamentAsset asset) async {
    print("Removing asset : $asset");
    await _channel.invokeMethod("removeAsset", asset);
  }

  Future clearAssets() async {
    await _channel.invokeMethod("clearAssets");
  }

  Future zoomBegin() async {
    await _channel.invokeMethod("zoomBegin");
  }

  Future zoomUpdate(double z) async {
    await _channel.invokeMethod("zoomUpdate", [0.0, 0.0, z]);
  }

  Future zoomEnd() async {
    await _channel.invokeMethod("zoomEnd");
  }

  Future playAnimation(FilamentAsset asset, int index,
      {bool loop = false, bool reverse = false}) async {
    await _channel.invokeMethod("playAnimation", [asset, index, loop, reverse]);
  }

  Future setAnimationFrame(
      FilamentAsset asset, int index, int animationFrame) async {
    await _channel
        .invokeMethod("setAnimationFrame", [asset, index, animationFrame]);
  }

  Future playAnimations(FilamentAsset asset, List<int> indices,
      {bool loop = false, bool reverse = false}) async {
    return Future.wait(indices.map((index) {
      return _channel
          .invokeMethod("playAnimation", [asset, index, loop, reverse]);
    }));
  }

  Future stopAnimation(FilamentAsset asset, int animationIndex) async {
    await _channel.invokeMethod("stopAnimation", [asset, animationIndex]);
  }

  Future setCamera(FilamentAsset asset, String name) async {
    await _channel.invokeMethod("setCamera", [asset, name]);
  }

  Future setCameraFocalLength(double focalLength) async {
    await _channel.invokeMethod("setCameraFocalLength", focalLength);
  }

  Future setCameraFocusDistance(double focusDistance) async {
    await _channel.invokeMethod("setCameraFocusDistance", focusDistance);
  }

  Future setCameraPosition(double x, double y, double z) async {
    await _channel.invokeMethod("setCameraPosition", [x, y, z]);
  }

  Future setCameraRotation(double rads, double x, double y, double z) async {
    await _channel.invokeMethod("setCameraRotation", [rads, x, y, z]);
  }

  Future setCameraModelMatrix(List<double> matrix) async {
    await _channel.invokeMethod(
        "setCameraModelMatrix", Float32List.fromList(matrix));
  }

  Future setTexture(FilamentAsset asset, String assetPath,
      {int renderableIndex = 0}) async {
    await _channel
        .invokeMethod("setTexture", [asset, assetPath, renderableIndex]);
  }

  Future transformToUnitCube(FilamentAsset asset) async {
    await _channel.invokeMethod("transformToUnitCube", asset);
  }

  Future setPosition(FilamentAsset asset, double x, double y, double z) async {
    await _channel.invokeMethod("setPosition", [asset, x, y, z]);
  }

  // Future setBoneTransform(FilamentAsset asset, String boneName, String meshName,
  //     BoneTransform transform) async {
  //   await _channel.invokeMethod("setBoneTransform", [
  //     asset,
  //     boneName,
  //     meshName,
  //     transform.translations[0].x,
  //     transform.translations[0].y,
  //     transform.translations[0].z,
  //     transform.quaternions[0].x,
  //     transform.quaternions[0].y,
  //     transform.quaternions[0].z,
  //     transform.quaternions[0].w
  //   ]);
  // }

  Future setScale(FilamentAsset asset, double scale) async {
    await _channel.invokeMethod("setScale", [asset, scale]);
  }

  Future setRotation(
      FilamentAsset asset, double rads, double x, double y, double z) async {
    await _channel.invokeMethod("setRotation", [asset, rads, x, y, z]);
  }
}

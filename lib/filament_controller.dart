import 'dart:async';

import 'package:flutter/services.dart';

// this is confusing - "FilamentAsset" actually defines a pointer to a SceneAsset, whereas FilamentLight is an Entity ID.
// should make this consistent
typedef FilamentAsset = int;
typedef FilamentLight = int;

abstract class FilamentController {
  late int textureId;
  Future get initialized;
  Stream get onInitializationRequested;
  Future initialize();
  Future createTextureViewer(int width, int height, { double devicePixelRatio = 1});
  Future setFrameRate(int framerate);
  Future setRendering(bool render);
  Future render();

  Future resize(int width, int height, { double devicePixelRatio = 1, double contentScaleFactor=1});
  Future setBackgroundImage(String path);
  Future setBackgroundImagePosition(double x, double y, {bool clamp=false});
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
  Future<FilamentLight> addLight(int type, double colour, double intensity, double posX, double posY, double posZ,double dirX, double dirY, double dirZ, bool castShadows);
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
  Future applyWeights(FilamentAsset asset, List<double> weights);
  Future<List<String>> getTargetNames(FilamentAsset asset, String meshName);
  Future<List<String>> getAnimationNames(FilamentAsset asset);
  Future removeAsset(FilamentAsset asset);
  Future clearAssets();
  Future playAnimation(FilamentAsset asset, int index, {bool loop = false});
  Future playAnimations(FilamentAsset asset, List<int> indices,
      {bool loop = false});
  Future stopAnimation(FilamentAsset asset, int index);
  Future setCamera(FilamentAsset asset, String name);
  Future setTexture(FilamentAsset asset, String assetPath,
      {int renderableIndex = 0});
  Future transformToUnitCube(FilamentAsset asset);
  Future setPosition(FilamentAsset asset, double x, double y, double z);
  Future setRotation(
      FilamentAsset asset, double rads, double x, double y, double z);
  Future setScale(
      FilamentAsset asset, double scale);
  Future setCameraFocalLength(
      double focalLength);
  Future setCameraFocusDistance(
      double focusDistance);
  Future setCameraPosition(
      double x, double y, double z);
  Future setCameraRotation(
      double rads, double x, double y, double z);
  ///
  /// Set the weights of all morph targets in the mesh to the specified weights at successive frames (where each frame requires a duration of [frameLengthInMs].
  /// Accepts a list of doubles representing a sequence of "frames", stacked end-to-end.
  /// Each frame is [numWeights] in length, where each entry is the weight to be applied to the morph target located at that index in the mesh primitive at that frame.
  /// In other words, weights is a contiguous sequence of floats of size W*F, where W is the number of weights and F is the number of frames
  ///
  Future animate(FilamentAsset asset, List<double> data, int numWeights,
      int numFrames, double frameLengthInMs);

}

class PolyvoxFilamentController extends FilamentController {
  
  late MethodChannel _channel = MethodChannel("app.polyvox.filament/event");
  late double _devicePixelRatio;


  final _onInitRequestedController = StreamController();
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
    await _channel.invokeMethod("setRendering",  render);
  }

  Future render() async {
    await _channel.invokeMethod("render");
  }

  Future setFrameRate(int framerate) async {
    await _channel.invokeMethod("setFrameInterval",  1/ framerate);
  }

  Future createTextureViewer(int width, int height, { double devicePixelRatio=1 }) async {
    _devicePixelRatio = devicePixelRatio;
    textureId = await _channel.invokeMethod("initialize", [width*devicePixelRatio, height*devicePixelRatio]);
    _initialized.complete(true);
  }

  Future resize(int width, int height, { double devicePixelRatio=1, double contentScaleFactor=1.0}) async {
    _devicePixelRatio = devicePixelRatio;
    await _channel.invokeMethod("resize", [width*devicePixelRatio, height*devicePixelRatio, contentScaleFactor]);
  }

  @override
  Future setBackgroundImage(String path) async {
    await _channel.invokeMethod("setBackgroundImage", path);
  }

  @override
  Future setBackgroundImagePosition(double x, double y, { bool clamp = false}) async {
    await _channel.invokeMethod("setBackgroundImagePosition", [x,y, clamp]);
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
  Future<FilamentLight> addLight(int type, double colour, double intensity, double posX, double posY, double posZ,double dirX, double dirY, double dirZ, bool castShadows) async {
    var entityId = await _channel.invokeMethod("addLight", [type, colour, intensity, posX, posY, posZ, dirX, dirY, dirZ, castShadows]);
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
    print("Got asset : $asset ");
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
    await setRendering(true);
    await _channel.invokeMethod("panStart", [x * _devicePixelRatio, y * _devicePixelRatio]);
  }

  Future panUpdate(double x, double y) async {
    await _channel.invokeMethod("panUpdate", [x * _devicePixelRatio, y * _devicePixelRatio]);
  }

  Future panEnd() async {
    await _channel.invokeMethod("panEnd");
    await setRendering(false);
  }

  Future rotateStart(double x, double y) async {
    await setRendering(true);
    await _channel.invokeMethod("rotateStart", [x * _devicePixelRatio, y * _devicePixelRatio]);
  }

  Future rotateUpdate(double x, double y) async {
    await _channel.invokeMethod("rotateUpdate", [x * _devicePixelRatio, y * _devicePixelRatio]);
  }

  Future rotateEnd() async {
    await setRendering(false);
    await _channel.invokeMethod("rotateEnd");
  }

  Future applyWeights(FilamentAsset asset, List<double> weights) async {
    await _channel.invokeMethod("applyWeights", [asset, weights]);
  }

  Future<List<String>> getTargetNames(
      FilamentAsset asset, String meshName) async {
    var result =
        (await _channel.invokeMethod("getTargetNames", [asset, meshName]))
            .cast<String>();
    return result;
  }

  Future<List<String>> getAnimationNames(FilamentAsset asset) async {
    var result = (await _channel.invokeMethod("getAnimationNames", asset))
        .cast<String>();
    return result;
  }

  Future animate(FilamentAsset asset, List<double> weights, int numWeights,
      int numFrames, double frameLengthInMs) async {
    await _channel.invokeMethod("animateWeights",
        [asset, weights, numWeights, numFrames, frameLengthInMs]);
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
    await _channel.invokeMethod("zoomUpdate", [0.0,0.0,z]);
  }

  Future zoomEnd() async {
    await _channel.invokeMethod("zoomEnd");
  }

  Future playAnimation(FilamentAsset asset, int index,
      {bool loop = false}) async {
    await _channel.invokeMethod("playAnimation", [asset, index, loop]);
  }

  Future playAnimations(FilamentAsset asset, List<int> indices,
      {bool loop = false}) async {
    return Future.wait(indices.map((index) {
      return _channel.invokeMethod("playAnimation", [asset, index, loop]);
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

  Future setCameraPosition(
      double x, double y, double z) async {
    await _channel.invokeMethod("setCameraPosition", [x,y,z]);
  }
  
  Future setCameraRotation(
      double rads, double x, double y, double z) async {
    await _channel.invokeMethod("setCameraRotation", [rads, x,y,z]);
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

  Future setScale(
      FilamentAsset asset, double scale) async {
        await _channel.invokeMethod("setScale", [asset, scale]);
  }

  Future setRotation(
      FilamentAsset asset, double rads, double x, double y, double z) async {
    await _channel.invokeMethod("setRotation", [asset, rads, x, y, z]);
  }
}

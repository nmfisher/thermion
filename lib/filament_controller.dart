import 'dart:async';

import 'package:flutter/services.dart';

typedef FilamentAsset = int;

abstract class FilamentController {
  void onFilamentViewCreated(int id);
  Future setBackgroundImage(String path);
  Future loadSkybox(String skyboxPath);
  Future removeSkybox();
  Future loadIbl(String path);
  Future removeIbl();
  Future<FilamentAsset> loadGlb(String path);
  Future<FilamentAsset> loadGltf(String path, String relativeResourcePath);
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
  Future playAnimations(FilamentAsset asset, List<int> indices, {bool loop = false});
  Future stopAnimation(FilamentAsset asset);
  Future setCamera(FilamentAsset asset, String name);
  Future setTexture(FilamentAsset asset, String assetPath, { int renderableIndex=0});

  ///
  /// Set the weights of all morph targets in the mesh to the specified weights at successive frames (where each frame requires a duration of [frameLengthInMs].
  /// Accepts a list of doubles representing a sequence of "frames", stacked end-to-end.
  /// Each frame is [numWeights] in length, where each entry is the weight to be applied to the morph target located at that index in the mesh primitive at that frame.
  /// In other words, weights is a contiguous sequence of floats of size W*F, where W is the number of weights and F is the number of frames
  ///
  Future animate(FilamentAsset asset, 
      List<double> data, int numWeights, int numFrames, double frameLengthInMs);
  Future zoom(double z);
}

class PolyvoxFilamentController extends FilamentController {
  late int _id;
  late MethodChannel _channel;

  final Function(int id)? onFilamentViewCreatedHandler;

  PolyvoxFilamentController({this.onFilamentViewCreatedHandler});

  @override
  void onFilamentViewCreated(int id) async {
    _id = id;
    _channel = MethodChannel("app.polyvox.filament/filament_view_$id");
    _channel.setMethodCallHandler((call) async {
      print("Received Filament method channel call : ${call.method}");
      if (call.method == "ready") {
        onFilamentViewCreatedHandler?.call(_id);
        return Future.value(true);
      } else {
        throw Exception("Unknown method channel invocation ${call.method}");
      }
    });
  }

  @override
  Future setBackgroundImage(String path) async {
    await _channel.invokeMethod("setBackgroundImage", path);
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

  Future<FilamentAsset> loadGlb(String path) async {
    print("Loading GLB at $path ");
    var asset = await _channel.invokeMethod("loadGlb", path);
    print("Got asset : $asset ");
    return asset as FilamentAsset;
  }

  Future<FilamentAsset> loadGltf(String path, String relativeResourcePath) async {
    print(
        "Loading GLTF at $path with relative resource path $relativeResourcePath");
    var asset = await _channel.invokeMethod("loadGltf", [path, relativeResourcePath]);
    return asset as FilamentAsset;
  }

  Future panStart(double x, double y) async {
    await _channel.invokeMethod("panStart", [x.toInt(), y.toInt()]);
  }

  Future panUpdate(double x, double y) async {
    await _channel.invokeMethod("panUpdate", [x.toInt(), y.toInt()]);
  }

  Future panEnd() async {
    await _channel.invokeMethod("panEnd");
  }

  Future rotateStart(double x, double y) async {
    await _channel.invokeMethod("rotateStart", [x.toInt(), y.toInt()]);
  }

  Future rotateUpdate(double x, double y) async {
    await _channel.invokeMethod("rotateUpdate", [x.toInt(), y.toInt()]);
  }

  Future rotateEnd() async {
    await _channel.invokeMethod("rotateEnd");
  }

  Future applyWeights(FilamentAsset asset, List<double> weights) async {
    await _channel.invokeMethod("applyWeights", [asset, weights]);
  }

  Future<List<String>> getTargetNames(FilamentAsset asset, String meshName) async {
    var result = (await _channel.invokeMethod("getTargetNames", [asset, meshName]))
        .cast<String>();
    return result;
  }

  Future<List<String>> getAnimationNames(FilamentAsset asset) async {
    var result =
        (await _channel.invokeMethod("getAnimationNames", asset)).cast<String>();
    return result;
  }

  Future animate(FilamentAsset asset, List<double> weights, int numWeights, int numFrames,
      double frameLengthInMs) async {
    await _channel.invokeMethod(
        "animateWeights", [asset, weights, numWeights, numFrames, frameLengthInMs]);
  }

  Future removeAsset(FilamentAsset asset) async {
    await _channel.invokeMethod("removeAsset", asset);
  }

  Future clearAssets() async {
    await _channel.invokeMethod("clearAssets");
  }

  Future zoom(double z) async {
    await _channel.invokeMethod("zoom", z);
  }

  Future playAnimation(FilamentAsset asset, int index, {bool loop = false}) async {
    await _channel.invokeMethod("playAnimation", [asset, index, loop]);
  }

  Future playAnimations(FilamentAsset asset, List<int> indices, {bool loop = false}) async {
    return Future.wait(indices.map((index) { 
      return _channel.invokeMethod("playAnimation", [asset, index, loop]);
    }));
  }

  Future stopAnimation(FilamentAsset asset) async {
    await _channel.invokeMethod("stopAnimation");
  }

  Future setCamera(FilamentAsset asset, String name) async {
    await _channel.invokeMethod("setCamera", [asset, name]);
  }

  Future setTexture(FilamentAsset asset, String assetPath, { int renderableIndex=0}) async {
    await _channel.invokeMethod("setTexture", [asset, assetPath, renderableIndex]);
  }
}

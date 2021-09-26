import 'dart:async';

import 'package:flutter/services.dart';

abstract class FilamentController {
  void onFilamentViewCreated(int id);

  Future loadSkybox(String skyboxPath, String lightingPath);
  Future loadGlb(String path);
  Future loadGltf(String path, String relativeResourcePath);
  Future panStart(double x, double y);
  Future panUpdate(double x, double y);
  Future panEnd();
  Future rotateStart(double x, double y);
  Future rotateUpdate(double x, double y);
  Future rotateEnd();
  Future applyWeights(List<double> weights);
  Future<List<String>> getTargetNames(String meshName);
  Future releaseSourceAssets();
  Future playAnimation(int index);

  // Weights is expected to be a contiguous sequence of floats of size W*F, where W is the number of weights and F is the number of frames
  Future animate(List<double> weights, int numWeights, double frameRate);
  Future createMorpher(String meshName, List<int> primitives);
  Future zoom(double z);
}

class MimeticFilamentController extends FilamentController {
  late int _id;
  late MethodChannel _channel;
  final String materialPath;

  MimeticFilamentController(
      {this.materialPath = "packages/mimetic_filament/assets/compiled.mat"});

  @override
  void onFilamentViewCreated(int id) async {
    _id = id;
    _channel = MethodChannel("mimetic.app/filament_view_$id");
    _channel.setMethodCallHandler((call) async {
      await Future.delayed(Duration(
          seconds:
              1)); // todo - need a better way to know when the GL context is actaully ready
      await _initialize();
      return Future.value(true);
    });
  }

  @override
  Future _initialize() async {
    final foo = await rootBundle.load(materialPath);
    print("Initializing with material path of size ${foo.lengthInBytes}");
    await _channel.invokeMethod("initialize", materialPath);
  }

  @override
  Future loadSkybox(String skyboxPath, String lightingPath) async {
    await _channel.invokeMethod("loadSkybox", [skyboxPath, lightingPath]);
  }

  Future loadGlb(String path) {
    throw Exception();
  }

  Future loadGltf(String path, String relativeResourcePath) async {
    print(
        "Loading GLTF at $path with relative resource path $relativeResourcePath");
    await _channel.invokeMethod("loadGltf", [path, relativeResourcePath]);
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

  Future applyWeights(List<double> weights) async {
    await _channel.invokeMethod("applyWeights", weights);
  }

  Future<List<String>> getTargetNames(String meshName) async {
    var result = (await _channel.invokeMethod("getTargetNames", meshName))
        .cast<String>();
    return result;
  }

  Future animate(List<double> weights, int numWeights, double frameRate) async {
    await _channel
        .invokeMethod("animateWeights", [weights, numWeights, frameRate]);
  }

  Future releaseSourceAssets() async {
    await _channel.invokeMethod("releaseSourceAssets");
  }

  Future zoom(double z) async {
    await _channel.invokeMethod("zoom", z);
  }

  Future createMorpher(String meshName, List<int> primitives) async {
    await _channel.invokeMethod("createMorpher", [meshName, primitives]);
  }

  Future playAnimation(int index) async {
    await _channel.invokeMethod("playAnimation", index);
  }
}

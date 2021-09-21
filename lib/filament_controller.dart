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
  Future applyWeights(List<double> weights, int primitiveIndex);
  Future<List<String>> getTargetNames(String meshName);

  void animate(
      List<List<double>> weights, int primitiveIndex, double frameRate);
  Future createMorpher(String meshName, String entityName,
      {String? materialName});
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
    print("Initializing");
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

  Future applyWeights(List<double> weights, int primitiveIndex) async {
    await _channel.invokeMethod("applyWeights", [weights, primitiveIndex]);
  }

  Future<List<String>> getTargetNames(String meshName) async {
    var result = (await _channel.invokeMethod("getTargetNames", meshName))
        .cast<String>();
    return result;
  }

  void animate(
      List<List<double>> weights, int primitiveIndex, double frameRate) async {
    final msPerFrame = 1000 ~/ frameRate;
    int i = 0;

    Timer.periodic(Duration(milliseconds: msPerFrame), (t) async {
      _channel.invokeMethod("applyWeights", [weights[i], primitiveIndex]);
      i++;
      if (i >= weights.length) {
        t.cancel();
      }
    });
  }

  Future zoom(double z) async {
    await _channel.invokeMethod("zoom", z);
  }

  Future createMorpher(String meshName, String entityName,
      {String? materialName}) async {
    await _channel
        .invokeMethod("createMorpher", [meshName, entityName, materialName]);
  }
}

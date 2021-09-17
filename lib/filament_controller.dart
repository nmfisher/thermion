import 'package:flutter/services.dart';

abstract class FilamentController {
  void onFilamentViewCreated(int id);
  Future initialize({String? materialPath});
  Future loadSkybox(String skyboxPath, String lightingPath);
  Future loadGlb(String path);
  Future loadGltf(
      String path, String relativeResourcePath, String materialInstanceName);
  Future panStart(double x, double y);
  Future panUpdate(double x, double y);
  Future panEnd();
  Future applyWeights(List<double> weights, int primitiveIndex);
  Future createMorpher(String meshName, String entityName,
      {String? materialName});
  Future zoom(double z);
}

class MimeticFilamentController extends FilamentController {
  late int _id;
  late MethodChannel _channel;

  @override
  void onFilamentViewCreated(int id) async {
    _id = id;
    _channel = MethodChannel("mimetic.app/filament_view_$id");
  }

  @override
  Future initialize({String? materialPath}) async {
    await _channel.invokeMethod("initialize", materialPath);
  }

  @override
  Future loadSkybox(String skyboxPath, String lightingPath) async {
    await _channel.invokeMethod("loadSkybox", [skyboxPath, lightingPath]);
  }

  Future loadGlb(String path) {
    throw Exception();
  }

  Future loadGltf(String path, String relativeResourcePath,
      String materialInstanceName) async {
    await _channel.invokeMethod(
        "loadGltf", [path, relativeResourcePath, materialInstanceName]);
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

  Future applyWeights(List<double> weights, int primitiveIndex) async {
    await _channel.invokeMethod("applyWeights", [weights, primitiveIndex]);
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

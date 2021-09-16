import 'package:flutter/services.dart';

abstract class FilamentController {
  void onFilamentViewCreated(int id);
  Future initialize();
  Future loadSkybox(String skyboxPath, String lightingPath);
  Future loadGlb(String path);
  Future loadGltf(String path, String relativeResourcePath);
  Future panStart(double x, double y);
  Future panUpdate(double x, double y);
  Future panEnd();
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
  Future initialize() async {
    await _channel.invokeMethod("initialize");
  }

  @override
  Future loadSkybox(String skyboxPath, String lightingPath) async {
    await _channel.invokeMethod("loadSkybox", [skyboxPath, lightingPath]);
  }

  Future loadGlb(String path) {
    throw Exception();
  }

  Future loadGltf(String path, String relativeResourcePath) async {
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
}

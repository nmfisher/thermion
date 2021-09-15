import 'package:flutter/services.dart';

abstract class FilamentController {
  void onFilamentViewCreated(int id);
  Future initialize();
  Future loadSkybox(String skyboxPath, String lightingPath);
  Future loadGlb(String path);
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
  Future loadSkybox(String path) {
    throw Exception();
  }

  Future loadGlb(String path) {
    throw Exception();
  }
}

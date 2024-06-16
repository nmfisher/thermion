import 'package:dart_filament/dart_filament/abstract_filament_viewer.dart';
import 'package:flutter_filament_platform_interface/flutter_filament_platform_interface.dart';
import 'package:flutter_filament_platform_interface/flutter_filament_texture.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:dart_filament/dart_filament/compatibility/web/interop/dart_filament_js_extension_type.dart';
import 'package:dart_filament/dart_filament/compatibility/web/interop/js_interop_filament_viewer.dart';

class FlutterFilamentWebPlugin extends FlutterFilamentPlatform {
  static void registerWith(Registrar registrar) {
    FlutterFilamentPlatform.instance = FlutterFilamentWebPlugin();
  }

  @override
  Future<FlutterFilamentTexture?> createTexture(
      int width, int height, int offsetLeft, int offsetRight) async {}

  @override
  Future destroyTexture(FlutterFilamentTexture texture) async {}

  @override
  void dispose() {
    // TODO: implement dispose
  }

  @override
  Future initialize({String? uberArchivePath}) async {
    print("Creating viewer in web plugin");
    viewer = JsInteropFilamentViewer("filamentViewer");
    print("Waiting for initialized");
    await viewer.initialized;
    print("int complete");
  }

  @override
  Future<FlutterFilamentTexture?> resizeTexture(FlutterFilamentTexture texture,
      int width, int height, int offsetLeft, int offsetRight) async {}

  @override
  // TODO: implement viewer
  late final AbstractFilamentViewer viewer;
}

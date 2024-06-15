import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:thermion_dart/thermion_dart/compatibility/web/interop/thermion_dart_js_extension_type.dart';
import 'package:thermion_dart/thermion_dart/compatibility/web/interop/js_interop_filament_viewer.dart';

class ThermionFlutterWebPlugin extends ThermionFlutterPlatform {
  static void registerWith(Registrar registrar) {
    ThermionFlutterPlatform.instance = ThermionFlutterWebPlugin();
  }

  @override
  Future<ThermionFlutterTexture?> createTexture(
      int width, int height, int offsetLeft, int offsetRight) async {}

  @override
  Future destroyTexture(ThermionFlutterTexture texture) async {}

  @override
  void dispose() {
    // TODO: implement dispose
  }

  @override
  Future initialize({String? uberArchivePath}) async {
    print("Creating viewer in web plugin");
    viewer = JsInteropThermionViewerFFI("filamentViewer");
    print("Waiting for initialized");
    await viewer.initialized;
    print("int complete");
  }

  @override
  Future<ThermionFlutterTexture?> resizeTexture(ThermionFlutterTexture texture,
      int width, int height, int offsetLeft, int offsetRight) async {}

  @override
  // TODO: implement viewer
  late final ThermionViewer viewer;
}

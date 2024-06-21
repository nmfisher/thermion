import 'package:thermion_dart/thermion_dart/compatibility/web/interop/thermion_viewer_wasm.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart';

class ThermionFlutterWebPlugin extends ThermionFlutterPlatform {
  static void registerWith(Registrar registrar) {
    ThermionFlutterPlatform.instance = ThermionFlutterWebPlugin();
  }

  @override
  Future<ThermionFlutterTexture?> createTexture(
      int width, int height, int offsetLeft, int offsetRight) async {
    return ThermionFlutterTexture(null, null, 0, 0, null);
  }

  @override
  Future destroyTexture(ThermionFlutterTexture texture) async {
    // noop
  }

  @override
  Future<ThermionFlutterTexture?> resizeTexture(ThermionFlutterTexture texture,
      int width, int height, int offsetLeft, int offsetRight) async {
    return ThermionFlutterTexture(null, null, 0, 0, null);
  }

  Future<ThermionViewer> createViewer({String? uberArchivePath}) async {
    final canvas = document.getElementById("canvas") as HTMLCanvasElement;
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    var width = window.innerWidth;
    var height = window.innerHeight;

    var viewer = ThermionViewerWasm();
    await viewer.initialize(width, height, uberArchivePath: uberArchivePath);
    return viewer;
  }
}

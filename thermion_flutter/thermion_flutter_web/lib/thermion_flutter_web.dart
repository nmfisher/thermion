import 'package:thermion_dart/thermion_dart/compatibility/web/interop/thermion_viewer_wasm.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class ThermionFlutterWebPlugin extends ThermionFlutterPlatform {
  ThermionViewerWasm? _viewer;

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
    final canvas = document.getElementById("canvas") as HTMLCanvasElement;
    canvas.width = width;
    canvas.height = height;

    _viewer!.updateViewportAndCameraProjection(width, height, 1.0);

    print("Resized canvas to ${canvas.width}x${canvas.height}");
    return ThermionFlutterTexture(null, null, 0, 0, null);
  }

  Future<ThermionViewer> createViewer({String? uberArchivePath}) async {
    final canvas = document.getElementById("canvas") as HTMLCanvasElement;
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    var width = window.innerWidth;
    var height = window.innerHeight;

    _viewer = ThermionViewerWasm(assetPathPrefix: "/assets/");
    await _viewer!.initialize(width, height, uberArchivePath: uberArchivePath);
    return _viewer!;
  }
}

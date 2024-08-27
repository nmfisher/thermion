import 'package:thermion_dart/thermion_dart/compatibility/web/interop/thermion_viewer_wasm.dart';
import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart';

class ThermionFlutterWebPlugin extends ThermionFlutterPlatform {
  ThermionViewerWasm? _viewer;

  static void registerWith(Registrar registrar) {
    ThermionFlutterPlatform.instance = ThermionFlutterWebPlugin();
  }

  @override
  Future<ThermionFlutterTexture?> createTexture(double width, double height,
      double offsetLeft, double offsetRight, double pixelRatio) async {
    await _viewer!.destroySwapChain();
    await _viewer!.createSwapChain(width.ceil(), height.ceil());

    final canvas = document.getElementById("canvas") as HTMLCanvasElement;
    canvas.width = (width * pixelRatio).ceil();
    canvas.height = (height * pixelRatio).ceil();

    _viewer!
        .updateViewportAndCameraProjection(width.ceil(), height.ceil(), 1.0);

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
    return ThermionFlutterTexture(null, null, 0, 0, null);
  }

  Future<ThermionViewer> createViewer({String? uberArchivePath}) async {
    _viewer = ThermionViewerWasm(assetPathPrefix: "/assets/");
    final canvas = document.createElement("canvas") as HTMLCanvasElement;
    canvas.id = "canvas";
    document.body!.appendChild(canvas);
    canvas.style.display = 'none';
    final pixelRatio = window.devicePixelRatio;
    
    await _viewer!
        .initialize(1, 1, pixelRatio, uberArchivePath: uberArchivePath);
    return _viewer!;
  }
}

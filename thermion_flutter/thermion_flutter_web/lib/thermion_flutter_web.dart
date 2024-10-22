import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/viewer/src/web_wasm/src/thermion_viewer_wasm.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_window.dart';
import 'package:thermion_flutter_web/thermion_flutter_web_options.dart';

import 'package:web/web.dart';

class ThermionFlutterWebPlugin extends ThermionFlutterPlatform {
  ///
  ///
  ///
  static void registerWith(Registrar registrar) {
    ThermionFlutterPlatform.instance = ThermionFlutterWebPlugin();
  }

  ///
  ///
  ///
  @override
  Future<ThermionFlutterTexture?> createTexture(
      View view, int width, int height) {
    throw UnimplementedError("Not supported on web");
  }

  static ThermionViewerWasm? _viewer;
  static SwapChain? _swapChain;

  ///
  ///
  ///
  @override
  Future<ThermionViewer> createViewer(
      {ThermionFlutterWebOptions? options}) async {
    _viewer = await ThermionViewerWasm.create(assetPathPrefix: "/assets/");

    final canvas = options?.createCanvas == true
        ? document.createElement("canvas") as HTMLCanvasElement?
        : document.getElementById("canvas") as HTMLCanvasElement?;

    if (canvas == null) {
      throw Exception("Could not locate or create canvas");
    }
    canvas.id = "canvas";
    document.body!.appendChild(canvas);
    canvas.style.display = 'none';

    return _viewer!;
  }

  @override
  Future<ThermionFlutterWindow> createWindow(
      int width, int height, int offsetLeft, int offsetTop) async {
    if (_swapChain != null) {
      throw Exception("Unexpected: swapchain already exists");
    }

    _swapChain = await _viewer!.createHeadlessSwapChain(width, height);

    final canvas = document.getElementById("canvas") as HTMLCanvasElement;
    canvas.width = width;
    canvas.height = height;

    (canvas as HTMLElement).style.position = "fixed";
    (canvas as HTMLElement).style.zIndex = "-1";
    (canvas as HTMLElement).style.left = offsetLeft.toString();
    (canvas as HTMLElement).style.top = offsetTop.ceil().toString();

    return CanvasWindow(canvas);
  }
}

class CanvasWindow extends ThermionFlutterWindow {
  final HTMLCanvasElement canvas;

  CanvasWindow(this.canvas);

  @override
  Future destroy() async {
    canvas.remove();
  }

  @override
  int get handle => throw UnimplementedError();

  @override
  int get height => canvas.height;

  @override
  int get width => canvas.width;

  @override
  Future markFrameAvailable() async {
    // currently noop, in future we should probably call requestAnimationFrame
  }

  @override
  Future resize(int width, int height, int left, int top) async {
    canvas.width = width;
    canvas.height = height;
    (canvas as HTMLElement).style.position = "fixed";
    (canvas as HTMLElement).style.zIndex = "-1";
    (canvas as HTMLElement).style.left = left.toString();
    (canvas as HTMLElement).style.top = top.toString();
  }
}

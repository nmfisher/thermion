import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:logging/logging.dart';
import 'package:flutter/services.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:web/web.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

class ThermionFlutterPluginImpl extends ThermionFlutterPlugin {
  late final _logger = Logger(this.runtimeType.toString());

  static Future<Uint8List> loadAsset(String path) async {
    if (path.startsWith("file://")) {
      throw UnsupportedError("file:// URIs not supported on web");
    }
    if (path.startsWith("asset://")) {
      path = path.replaceAll("asset://", "");
    }
    var asset = await rootBundle.load(path);
    return asset.buffer.asUint8List(asset.offsetInBytes);
  }

  // Future<ThermionViewer> createViewer({bool destroySwapchain = true}) async {
  //   final viewer = ThermionViewerFFI();
  //   await viewer.initialized;
  //   await viewer.setViewport(canvas!.width, canvas.height);

  //   await FilamentApp.instance!.register(swapChain, viewer.view);

  //   return viewer;
  // }

  ///
  void resizeCanvas(double width, double height) async {
    _logger.info("Resizing canvas to ${width}x${height}");
    resizeWebCanvas((window.devicePixelRatio * width).ceil(),
        (window.devicePixelRatio * height).ceil());
  }

  @override
  Future<SwapChain> initialize({bool destroySwapchain = true}) async {
    HTMLCanvasElement? canvas;
    // first, try and initialize bindings to see if the user has included thermion_dart.js manually in index.html
    try {
      NativeLibrary.initBindings("thermion_dart");
    } catch (err) {
      _logger.info(
          "Failed to find thermion_dart in window context, appending manually");
      // if not, manually add the script to the DOM
      var scriptElement = document.createElement("script") as HTMLScriptElement;
      scriptElement.src = options.webOptions.jsPath;
      document.head!.appendChild(scriptElement);
      final completer = Completer<JSObject?>();
      scriptElement.addEventListener(
          "load",
          () {
            final constructor =
                globalContext.getProperty("thermion_dart".toJS) as JSFunction?;
            if (constructor == null) {
              _logger.severe("Failed to find JS library constructor");
              completer.complete(null);
            } else {
              final lib = constructor.callAsFunction() as JSPromise;
              lib.toDart.then((resolved) {
                completer.complete(resolved as JSObject);
              });
            }
          }.toJS);
      final lib = await completer.future;
      globalContext.setProperty("thermion_dart".toJS, lib);
      NativeLibrary.initBindings("thermion_dart");
    }

    canvas = options.webOptions.createCanvas == true
        ? document.createElement("canvas") as HTMLCanvasElement?
        : document.getElementById("thermion_canvas") as HTMLCanvasElement?;

    if (canvas == null) {
      throw Exception("Could not locate or create canvas");
    }
    canvas.id = "thermion_canvas";
    // canvas.style.display = "none";
    document.body!.appendChild(canvas);

    if (options.webOptions.createCanvas) {
      (canvas as HTMLElement).style.position = "fixed";
      (canvas as HTMLElement).style.zIndex = "-1";
    }

    final config = FFIFilamentConfig(
        backend: Backend.OPENGL,
        loadResource: loadAsset,
        platform: nullptr,
        sharedContext: nullptr,
        uberArchivePath: options.uberarchivePath);
    await FFIFilamentApp.create(config: config);

    var swapChain = await FilamentApp.instance!
        .createHeadlessSwapChain(canvas.width, canvas.height);

    return swapChain;
  }
}

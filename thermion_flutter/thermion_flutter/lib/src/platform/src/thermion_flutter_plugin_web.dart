import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:logging/logging.dart';
import 'package:flutter/services.dart';
import 'package:thermion_flutter/thermion_flutter.dart';
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor.dart';
import 'package:thermion_flutter/src/platform/src/web_platform_texture_descriptor.dart';
import 'package:web/web.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/bindings/src/thermion_dart_js_interop.g.dart';
import 'package:thermion_dart/src/bindings/src/js_interop.dart'
    show stackSave, stackRestore, resizeWebCanvas;

class ThermionFlutterPluginImpl extends ThermionFlutterPlugin {
  static Pointer? _stackPtr;
  static final _descriptors = <PlatformTextureDescriptor>[];
  static final _destroyed = <PlatformTextureDescriptor>[];
  static final _logger = Logger('ThermionFlutterPluginImpl');

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

  static void _tick(JSNumber timestamp) {
    if (_stackPtr != null) {
      stackRestore(_stackPtr!);
    }

    _stackPtr = stackSave();

    FilamentApp.instance?.render();

    for (final descriptor in _descriptors) {
        descriptor.markTextureFrameAvailable();
    }
    for (final descriptor in _destroyed) {
      _descriptors.remove(descriptor);
      _logger.info(
          "Removed descriptor (hardware ID ${descriptor.hardwareId}, flutter ID ${descriptor.flutterTextureId})");
    }
    _destroyed.clear();

    window.requestAnimationFrame(_tick.toJS);
  }

  ///
  void resizeCanvas(double width, double height) async {
    _logger.info("Resizing canvas to ${width}x${height}");
    resizeWebCanvas((window.devicePixelRatio * width).ceil(),
        (window.devicePixelRatio * height).ceil());
  }

  static SwapChain? swapChain;

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

    canvas = document.getElementById("thermion_canvas") as HTMLCanvasElement?;

    if (options.webOptions.createCanvas) {
      // Remove and re-create the canvas if createCanvas is true and the canvas
      // already exists. This fixes the hot-reload problem (where the canvas
      // has already been created by the previous iteration and transferred to
      // the pthread. This is still an issue if createCanvas is false.
      // if(canvas.context)
      canvas?.remove();
      canvas = document.createElement("canvas") as HTMLCanvasElement?;
    }

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
        sharedContext: null,
        uberArchivePath: options.uberarchivePath);
    await FFIFilamentApp.create(config: config);

    // Use createSwapChain with nullptr to render to the canvas's default
    // framebuffer (framebuffer 0). createHeadlessSwapChain creates an offscreen
    // buffer that never gets displayed.
    swapChain = await FilamentApp.instance!.createHeadlessSwapChain(1, 1);

    print("Created 1x1 headless swapchain");

    window.requestAnimationFrame(_tick.toJS);

    return swapChain!;
  }

  @override
  Future<PlatformTextureDescriptor> resizeTexture(
    PlatformTextureDescriptor texture,
    View view,
    int width,
    int height,
  ) async {
    await texture.destroy();
    _descriptors.remove(texture);
    final newTexture = await createTextureAndBindToView(view, width, height);
    return newTexture!;
  }

  @override
  Future<PlatformTextureDescriptor?> createTextureAndBindToView(
    View view,
    int width,
    int height,
  ) async {
    // On web, we don't use hardware textures but we return a descriptor
    // with dimensions so the callback can update viewport/camera
    _logger.info(
        "createTextureAndBindToView returning web descriptor with ${width}x$height");
    var descriptor = WebPlatformTextureDescriptor(width: width, height: height);

    var overlay = await view.getHighlightOverlay();
    if (overlay != null) {
      await overlay!.setSwapChain(swapChain!);
    }
    resizeWebCanvas(width, height);
    return descriptor;
  }
}

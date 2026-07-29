import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:logging/logging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide View;
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor_registry.dart';
// hiding these isn't actually necessary, but the analyzer trips up on it
// when publishing to pub.dev, so we just hide manually.
import 'package:thermion_flutter/thermion_flutter.dart'
    hide Pointer, NativeType, nullptr, RenderManager_setPaused, NativeLibrary;
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor.dart';
import 'package:thermion_flutter/src/platform/src/web_platform_texture_descriptor.dart';
import 'package:web/web.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/bindings/src/thermion_dart_js_interop.g.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/bindings/src/thermion_dart_js_interop.g.dart'
    as js;

class ThermionFlutterPluginImpl extends ThermionFlutterPlugin
    with WidgetsBindingObserver {
  static js.Pointer<js.Void>? _stackPtr;

  static final _logger = Logger('ThermionFlutterPluginImpl');
  static int? _frameRequestId;
  static int _pacedFps = 0;
  static double? _nextRenderDeadlineMs;
  static bool _explicitlyPaused = false;
  static bool _lifecycleSuspended = false;

  static bool get _renderPaused => _explicitlyPaused || _lifecycleSuspended;

  static final _textureDescriptorRegistry = PlatformTextureDescriptorRegistry(
    allocator: (width, height) =>
        WebPlatformTextureDescriptor(width: width, height: height),
  );

  static void _applyRenderPause() {
    final app = FilamentApp.instance as FFIFilamentApp?;
    if (app != null) {
      RenderManager_setPaused(
        app.renderManager.getNativeHandle(),
        _renderPaused,
      );
    }
  }

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
      js.NativeLibrary.instance.stackRestore(_stackPtr!);
    }

    _stackPtr = js.NativeLibrary.instance.stackSave();

    final app = FilamentApp.instance;
    final targetFps = app is FFIFilamentApp ? app.targetFramerate : 0;
    final rendered = _shouldRender(timestamp.toDartDouble, targetFps);
    if (rendered) {
      app?.render();

      // RenderManager still executes its backend task queue while paused, but
      // it does not produce a new frame, so do not notify Flutter of one.
      if (!_renderPaused) {
        _textureDescriptorRegistry.markFrameAvailable();
      }
    }
    _frameRequestId = window.requestAnimationFrame(_tick.toJS);
  }

  static bool _shouldRender(double timestampMs, int targetFps) {
    final normalizedFps = targetFps > 0 ? targetFps : 0;
    if (normalizedFps == 0) {
      _pacedFps = 0;
      _nextRenderDeadlineMs = null;
      return true;
    }

    if (_pacedFps != normalizedFps || _nextRenderDeadlineMs == null) {
      _pacedFps = normalizedFps;
      _nextRenderDeadlineMs = timestampMs;
    }

    const toleranceMs = 1.0;
    final deadline = _nextRenderDeadlineMs!;
    if (deadline - timestampMs > toleranceMs) {
      return false;
    }

    final intervalMs = 1000.0 / normalizedFps;
    if (deadline <= timestampMs) {
      final missedIntervals =
          ((timestampMs - deadline) / intervalMs).floor() + 1;
      _nextRenderDeadlineMs = deadline + missedIntervals * intervalMs;
    } else {
      _nextRenderDeadlineMs = deadline + intervalMs;
    }
    return true;
  }

  static void _ensureFrameLoopRunning() {
    _frameRequestId ??= window.requestAnimationFrame(_tick.toJS);
  }

  static void _resetWebState() {
    if (_frameRequestId != null) {
      window.cancelAnimationFrame(_frameRequestId!);
      _frameRequestId = null;
    }
    _pacedFps = 0;
    _nextRenderDeadlineMs = null;
    _explicitlyPaused = false;
    _lifecycleSuspended = false;

    _stackPtr = null;
    swapChain = null;
    _textureDescriptorRegistry.clear();
  }

  static SwapChain? swapChain;

  @override
  Future<SwapChain> initialize({bool destroySwapchain = true}) async {
    WidgetsBinding.instance.removeObserver(this);

    if (FilamentApp.instance != null && swapChain != null) {
      // Hot reload re-enters initialize without disposing the existing web
      // engine. Reuse the live app instead of spawning another em-pthread.
      _ensureFrameLoopRunning();
      WidgetsBinding.instance.addObserver(this);
      _syncLifecycleState();
      _applyRenderPause();
      return swapChain!;
    }

    HTMLCanvasElement? canvas;
    // first, try and initialize bindings to see if the user has included thermion_dart.js manually in index.html
    try {
      NativeLibrary.initBindings("thermion_dart");
    } catch (err) {
      _logger.info(
        "Failed to find thermion_dart in window context, appending manually",
      );
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
        }.toJS,
      );
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
      uberArchivePath: options.uberarchivePath,
    );
    await FFIFilamentApp.create(config: config);
    // resetting the web state when the app is destroyed
    (FilamentApp.instance as FFIFilamentApp).onDestroy(() async {
      WidgetsBinding.instance.removeObserver(this);
      _resetWebState();
    });

    // Use createSwapChain with nullptr to render to the canvas's default
    // framebuffer (framebuffer 0). createHeadlessSwapChain creates an offscreen
    // buffer that never gets displayed.
    swapChain = await FilamentApp.instance!.createHeadlessSwapChain(1, 1);

    _logger.info("Created 1x1 headless swapchain");

    _ensureFrameLoopRunning();
    WidgetsBinding.instance.addObserver(this);
    _syncLifecycleState();
    _applyRenderPause();

    return swapChain!;
  }

  @override
  Future<PlatformTextureDescriptor> resizeTexture(
    PlatformTextureDescriptor texture,
    View view,
    int width,
    int height,
  ) {
    return _textureDescriptorRegistry.serialized(() async {
      await _textureDescriptorRegistry.destroy(texture);
      final newTexture = await _createTextureAndBindToView(view, width, height);
      return newTexture;
    });
  }

  @override
  Future<void> destroyTextureForView(View view) {
    return _textureDescriptorRegistry.serialized(() async {
      await _textureDescriptorRegistry.destroyBindingsForView(view);
    });
  }

  @override
  Future<PlatformTextureDescriptor?> createTextureAndBindToView(
    View view,
    int width,
    int height,
  ) {
    return _textureDescriptorRegistry.serialized(
      () => _createTextureAndBindToView(view, width, height),
    );
  }

  Future<PlatformTextureDescriptor> _createTextureAndBindToView(
    View view,
    int width,
    int height,
  ) async {
    // See https://stackoverflow.com/questions/53233096/how-to-set-html5-canvas-size-to-match-display-size-in-device-pixels
    // and https://joshondesign.com/2023/04/15/canvas_scale_smooth
    // The HTML canvas element size and viewport should be in physical pixels
    // (i.e. the size in logical pixels given by Flutter, multiplied by devicePixelRatio)
    // The HTML canvas element *CSS* properties width and height should be in *logical* pixels

    // On web, we don't use hardware textures but we return a descriptor
    // with dimensions so the callback can update viewport/camera
    final descriptor = await _textureDescriptorRegistry.create(width, height);
    try {
      await _textureDescriptorRegistry.bindToView(descriptor, view);
      final dpr = window.devicePixelRatio;
      _logger.info(
        "Creating descriptor for HTML canvas ${descriptor.width}x${descriptor.height} at dpr $dpr",
      );

      var overlay = view.getHighlightOverlay();
      await overlay?.setSwapChain(swapChain!);

      Thermion_setCanvasElementSize(
        js.StringUtils("#thermion_canvas").toNativeUtf8(),
        descriptor.width,
        descriptor.height,
      );

      // [width] and [height] have already been scaled by [devicePixelRatio]
      // so we need to undo this when setting the CSS dimensions

      final canvas =
          document.getElementById("thermion_canvas") as HTMLCanvasElement;

      canvas.style.width = "${width / dpr}px";
      canvas.style.height = "${height / dpr}px";

      return descriptor;
    } catch (error, stackTrace) {
      await _textureDescriptorRegistry.destroy(descriptor);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  @override
  void pauseFrameScheduler() {
    _explicitlyPaused = true;
    _applyRenderPause();
  }

  @override
  void resumeFrameScheduler() {
    _explicitlyPaused = false;
    _applyRenderPause();
  }

  void _syncLifecycleState() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null) {
      didChangeAppLifecycleState(state);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!_lifecycleSuspended) {
          _lifecycleSuspended = true;
          _applyRenderPause();
          _logger.info('App hidden, web rendering suspended');
        }
        break;
      case AppLifecycleState.resumed:
        if (_lifecycleSuspended) {
          _lifecycleSuspended = false;
          _applyRenderPause();
          _logger.info('App foregrounded, web rendering resumed');
        }
        break;
      case AppLifecycleState.inactive:
        // An unfocused tab can still be visible, so keep rendering.
        break;
    }
  }
}

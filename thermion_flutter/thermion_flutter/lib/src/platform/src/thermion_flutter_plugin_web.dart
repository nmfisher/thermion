import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

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

/// One engine per viewer on web: each viewer owns a canvas element, a
/// RenderThread (worker), a WebGL context and a headless swapchain. All
/// per-viewer state lives in this bundle; the plugin-wide statics are shared
/// across engines (rAF loop, FPS pacing, pause state).
class _WebViewerApp {
  _WebViewerApp({
    required this.canvasId,
    required this.app,
    required this.swapChain,
  });

  /// DOM element id of this viewer's canvas (no '#' prefix).
  final String canvasId;
  final FFIFilamentApp app;
  final SwapChain swapChain;
}

class ThermionFlutterPluginImpl extends ThermionFlutterPlugin
    with WidgetsBindingObserver {
  static js.Pointer<js.Void>? _stackPtr;

  static final _logger = Logger('ThermionFlutterPluginImpl');
  static int? _frameRequestId;
  static int _pacedFps = 0;
  static double? _nextRenderDeadlineMs;
  static bool _explicitlyPaused = false;
  static bool _lifecycleSuspended = false;
  static int _canvasSeq = 0;

  static bool get _renderPaused => _explicitlyPaused || _lifecycleSuspended;

  static final _textureDescriptorRegistry = PlatformTextureDescriptorRegistry(
    allocator: (width, height) =>
        WebPlatformTextureDescriptor(width: width, height: height),
  );

  // Identity-keyed: the same View/SwapChain wrapper instances flow through
  // createViewer → createTextureAndBindToView → teardown, and each engine has
  // exactly one view, so there is no cross-engine handle collision.
  static final Map<View, _WebViewerApp> _appsByView = {};
  static final Map<SwapChain, _WebViewerApp> _appsBySwapChain = {};

  /// Serialises engine creation. Each createViewer builds its own engine
  /// (per-viewer), but `FFIFilamentApp.create` destroys whatever engine is
  /// current — racing calls would tear each other down (the-wne3). The chain
  /// runs one initialization at a time; the rest of the mount proceeds
  /// concurrently.
  static Future<void> _initChain = Future.value();

  @override
  Future<InitializeResult> initialize({
    bool destroySwapchain = true,
    String? canvasId,
  }) {
    final completer = Completer<InitializeResult>();
    final prev = _initChain;
    _initChain = completer.future.then((_) {}, onError: (_) {});
    return prev.then((_) async {
      try {
        final result = await _initialize(canvasId);
        completer.complete(result);
        return result;
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
        rethrow;
      }
    });
  }

  Future<InitializeResult> _initialize(String? canvasId) async {
    final maxViewers = options.webOptions.maxViewers;
    if (maxViewers > 0 && _appsBySwapChain.length >= maxViewers) {
      throw StateError(
        'Maximum of $maxViewers concurrent viewers reached on web.',
      );
    }

    // Load the WASM module bindings. If the app didn't include
    // thermion_dart.js in index.html, append it manually and wait for the
    // module to construct before initializing the interop.
    try {
      NativeLibrary.initBindings("thermion_dart");
    } catch (err) {
      _logger.info(
        "Failed to find thermion_dart in window context, appending manually",
      );
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

    // Each viewer gets its own canvas, transferred to its own worker by
    // RenderThread_createForCanvas (called inside FFIFilamentApp.create via
    // the canvasSelector). A caller-provided id adopts an existing element
    // (or creates one with that id); otherwise a default id is generated.
    final String resolvedCanvasId;
    final HTMLCanvasElement canvas;
    if (canvasId != null) {
      if (_appsBySwapChain.values.any((b) => b.canvasId == canvasId)) {
        throw StateError(
          'Canvas "$canvasId" is already in use by another viewer.',
        );
      }
      resolvedCanvasId = canvasId;
      final existing = document.getElementById(canvasId);
      if (existing is HTMLCanvasElement) {
        canvas = existing;
      } else {
        canvas = document.createElement('canvas') as HTMLCanvasElement;
        canvas.id = canvasId;
        document.body!.appendChild(canvas);
      }
    } else {
      resolvedCanvasId = 'thermion_canvas_${_canvasSeq++}';
      canvas = document.createElement('canvas') as HTMLCanvasElement;
      canvas.id = resolvedCanvasId;
      document.body!.appendChild(canvas);
    }

    if (!options.webOptions.importCanvasAsWidget) {
      // Legacy single-canvas layout: the canvas floats behind the app.
      (canvas as HTMLElement).style.position = 'fixed';
      (canvas as HTMLElement).style.zIndex = '-1';
    } else {
      // Host the canvas inside the viewer's widget via a platform view.
      ui_web.platformViewRegistry.registerViewFactory(
        'imported-canvas-$resolvedCanvasId',
        (int viewId, {Object? params}) => canvas as Object,
      );
    }

    final config = FFIFilamentConfig(
      backend: Backend.OPENGL,
      loadResource: loadAsset,
      platform: nullptr,
      sharedContext: null,
      uberArchivePath: options.uberarchivePath,
    );
    // destroyExisting: false — this is a NEW engine for a NEW viewer;
    // FFIFilamentApp.create would otherwise destroy the previous viewer's
    // engine (and its worker) underneath its render loop, deadlocking when
    // the destructor drains pending render tasks on the main thread.
    await FFIFilamentApp.create(
      config: config,
      canvasSelector: '#$resolvedCanvasId',
      destroyExisting: false,
    );
    final app = FilamentApp.instance as FFIFilamentApp;

    // Use a headless swapchain as the scheduling token; the view renders
    // into this engine's canvas framebuffer 0.
    final swapChain = await app.createHeadlessSwapChain(1, 1);
    _logger.info('Created swapchain for canvas #$resolvedCanvasId');

    final bundle = _WebViewerApp(
      canvasId: resolvedCanvasId,
      app: app,
      swapChain: swapChain,
    );
    _appsBySwapChain[swapChain] = bundle;

    // Per-viewer teardown: when this engine is destroyed (viewer disposed),
    // remove its canvas and bundle entries; only when the last engine goes
    // away do we stop the shared rAF loop and unregister the observer.
    app.onDestroy(() async {
      _appsByView.removeWhere((_, b) => b.app == app);
      _appsBySwapChain.removeWhere((_, b) => b.app == app);
      canvas.remove();
      if (_appsBySwapChain.isEmpty) {
        WidgetsBinding.instance.removeObserver(this);
        _resetWebState();
      }
    });

    _ensureFrameLoopRunning();
    WidgetsBinding.instance.addObserver(this);
    _syncLifecycleState();
    _applyRenderPause();

    return InitializeResult(app: app, swapChain: swapChain);
  }

  static void _applyRenderPause() {
    for (final bundle in _appsBySwapChain.values) {
      RenderManager_setPaused(
        bundle.app.renderManager.getNativeHandle(),
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
    return asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes);
  }

  static void _tick(JSNumber timestamp) {
    if (_stackPtr != null) {
      js.NativeLibrary.instance.stackRestore(_stackPtr!);
    }

    _stackPtr = js.NativeLibrary.instance.stackSave();

    final apps = _appsBySwapChain.values.map((b) => b.app).toList();
    final targetFps = apps.isEmpty ? 0 : apps.first.targetFramerate;
    final rendered = _shouldRender(timestamp.toDartDouble, targetFps);
    if (rendered) {
      // One rAF loop drives every engine.
      for (final app in apps) {
        app.render();
      }

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
  }

  @override
  void onViewerCreated(View view, SwapChain? swapChain) {
    if (swapChain == null) {
      return;
    }
    final bundle = _appsBySwapChain[swapChain];
    if (bundle != null) {
      _appsByView[view] = bundle;
    }
  }

  @override
  Future<void> onViewerDisposed(View view) async {
    final bundle = _appsByView.remove(view);
    if (bundle == null) {
      return;
    }
    _appsBySwapChain.remove(bundle.swapChain);
    // The canvas element is removed by the app's onDestroy hook.
    await bundle.app.destroy();
  }

  @override
  String? canvasIdForView(View view) => _appsByView[view]?.canvasId;

  @override
  void setTargetFramerate(int fps) {
    for (final bundle in _appsBySwapChain.values) {
      bundle.app.setTargetFramerate(fps);
    }
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
    final bundle = _appsByView[view];
    if (bundle == null) {
      throw StateError(
        'No web app registered for view (onViewerCreated not called?)',
      );
    }

    final descriptor = await _textureDescriptorRegistry.create(width, height);
    try {
      await _textureDescriptorRegistry.bindToView(descriptor, view);
      final dpr = window.devicePixelRatio;
      _logger.info(
        "Creating descriptor for canvas #${bundle.canvasId} "
        "${descriptor.width}x${descriptor.height} at dpr $dpr",
      );

      var overlay = view.getHighlightOverlay();
      await overlay?.setSwapChain(bundle.swapChain);

      Thermion_setCanvasElementSize(
        js.StringUtils('#${bundle.canvasId}').toNativeUtf8(),
        descriptor.width,
        descriptor.height,
      );

      // [width] and [height] have already been scaled by [devicePixelRatio]
      // so we need to undo this when setting the CSS dimensions
      final canvas =
          document.getElementById(bundle.canvasId) as HTMLCanvasElement;
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

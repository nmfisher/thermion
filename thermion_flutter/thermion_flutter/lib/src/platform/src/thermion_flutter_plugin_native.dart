import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:thermion_flutter/src/platform/src/darwin_platform_texture_descriptor.dart';
import 'package:thermion_flutter/src/platform/src/method_channel_platform_texture_descriptor.dart';
import '../../../thermion_flutter.dart';
import 'platform_texture_descriptor.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/bindings/src/thermion_dart_ffi.g.dart'
    show
        FrameScheduler_start,
        FrameScheduler_stop,
        FrameCallbackFunction,
        FrameScheduler_initDartApi,
        FrameScheduler_startWithPort,
        FrameScheduler_setRenderThread,
        FrameScheduler_setRenderManager,
        FrameScheduler_setPostRenderCallback,
        FrameScheduler_requestRender;

/// Handles platform-specific initialization to create a backing rendering
/// surface in a Flutter application and lifecycle listeners to pause rendering
/// when the app is inactive or in the background.
///
/// ## Frame Scheduling Architecture
///
/// All platforms use a unified C API for frame scheduling via FFI:
///
/// ```
/// Dart (this file)
///     │
///     ▼
/// C API (FrameScheduler_start, FrameScheduler_stop, etc.)
///     │
///     ├── macOS/iOS ──► CVDisplayLinkScheduler (vsync via CVDisplayLink)
///     ├── Windows ────► DXGIFrameScheduler (vsync via DXGI WaitForVBlank)
///     ├── Android ────► AChoreographerFrameScheduler (vsync via AChoreographer)
///     └── Linux ──────► TimerFrameScheduler (timer-based fallback)
/// ```
///
/// ### Two Modes of Operation
///
/// **Release builds**: Direct callback mode for maximum performance.
/// The native scheduler calls a Dart function pointer directly.
///
/// **Debug builds**: Port-based mode for hot restart safety.
/// The native scheduler posts messages to a Dart port. When Flutter hot
/// restarts, the old port becomes invalid and messages are silently dropped
/// (via `Dart_PostCObject_DL`) instead of crashing on a dangling pointer.
///
/// ### Native Implementations
///
/// - `thermion_dart/native/include/rendering/FrameScheduler.hpp` - Class definitions
/// - `thermion_dart/native/src/rendering/FrameScheduler.cpp` - Platform implementations
/// - `thermion_dart/native/src/c_api/ThermionDartRenderThreadApi.cpp` - C API dispatch
class ThermionFlutterPluginImpl extends ThermionFlutterPlugin {
  final channel = const MethodChannel("dev.thermion.flutter/event");

  static final _logger = Logger("ThermionFlutterPluginImpl");

  static ThermionFlutterPluginImpl get instance =>
      ThermionFlutterPlugin.instance as ThermionFlutterPluginImpl;

  static Future<Uint8List> loadAsset(String path) async {
    if (path.startsWith("file://")) {
      return File(path.replaceAll("file://", "")).readAsBytesSync();
    }
    if (path.startsWith("asset://")) {
      path = path.replaceAll("asset://", "");
    }
    var asset = await rootBundle.load(path);
    return asset.buffer.asUint8List(asset.offsetInBytes);
  }

  static final _descriptors = <PlatformTextureDescriptor>[];
  static final _destroyed = <PlatformTextureDescriptor>[];

  // Track render targets created by Flutter for each view.
  // This allows us to destroy the correct RT on resize, even when the view
  // has been redirected to an internal RT (e.g., in composite highlight mode).
  static final _viewRenderTargets = <View, RenderTarget>{};

  // Track the SwapChain currently bound to each view (Android only).
  // The Android branch of createTextureAndBindToView destroys this view's
  // *previous* swap chain after creating the new one. Keying by view
  // (rather than iterating FilamentApp's global swap-chain list) is what
  // makes multi-viewer apps work — without this, mounting viewer #N
  // would destroy viewer #(N-1)'s swap chain and freeze it.
  static final _viewSwapChains = <View, SwapChain>{};

  // Deferred Filament render target cleanup for Windows resize.
  // Old RT stays alive so native can Blit from it during the swap window.
  static final _deferredRenderTargets = <(RenderTarget, int)>[];

  static bool _rendering = false;
  static bool _resizing = false;
  static ffi.NativeCallable<FrameCallbackFunction>? _frameCallable;
  static bool _schedulerActive = false;

  // Port-based mode for debug builds (hot restart safe)
  static ReceivePort? _framePort;
  static bool _usePortMode = false;
  static bool _dartApiInitialized = false;

  // Diagnostic timing state
  static int _diagFrameCount = 0;
  static int _diagDropCount = 0;
  static int _diagJankCount = 0;
  static double _diagMaxFrameMs = 0;
  static double _diagSumFrameMs = 0;
  static final _diagStopwatch = Stopwatch();
  static int _diagTransitSum = 0;
  static int _diagTransitCount = 0;
  static int _diagTransitMax = 0;
  static bool _frameSchedulerPaused = false;

  /// Called by native FrameScheduler at vsync/timer intervals.
  /// Not async — guards against re-entrant calls with [_rendering] flag.
  ///
  /// IMPORTANT: This can be called from native code even after hot restart
  /// while the native scheduler is being stopped. We MUST guard against this.
  static void _onFrame(int frameTimeNanos) {
    // Critical safety check: Ignore callbacks if scheduler is being shut down
    // or if we're in a hot restart scenario where FilamentApp is null
    if (!_schedulerActive || FilamentApp.instance == null) return;

    if (_rendering || _resizing || _frameSchedulerPaused) return;
    _rendering = true;
    _diagStopwatch.reset();
    _diagStopwatch.start();
    _renderFrame().then((_) {
      _diagStopwatch.stop();
      _rendering = false;
      final frameMs = _diagStopwatch.elapsedMicroseconds / 1000.0;
      _diagFrameCount++;
      _diagSumFrameMs += frameMs;
      if (frameMs > _diagMaxFrameMs) _diagMaxFrameMs = frameMs;
      if (frameMs > 20.0) _diagJankCount++;
      if (frameMs > 20.0) {
        _logger.warning(
            '#$_diagFrameCount JANK renderFrame=${frameMs.toStringAsFixed(1)}ms');
      }
      if (_diagFrameCount % 120 == 0) {
        final avgMs = _diagSumFrameMs / 120.0;
        _logger.finest('120-frame avg=${avgMs.toStringAsFixed(1)}ms '
            'max=${_diagMaxFrameMs.toStringAsFixed(1)}ms '
            'jank=$_diagJankCount drop=$_diagDropCount');
        _diagJankCount = 0;
        _diagDropCount = 0;
        _diagMaxFrameMs = 0;
        _diagSumFrameMs = 0;
      }
    }).catchError((error) {
      _logger.warning('Frame render error: $error');
      _rendering = false;
    });
  }

  /// Stop the frame scheduler and clean up the callback.
  ///
  /// IMPORTANT: This gets called at the START of initialize() in the new isolate
  /// after hot restart. At that point _frameCallable is null (static reset), but
  /// the NATIVE scheduler is still running with a dangling pointer. We MUST stop
  /// the native scheduler even when _frameCallable is null.
  static void stopFrameScheduler() {
    // Mark scheduler as inactive FIRST to prevent race conditions
    // Any in-flight callbacks will see this and return early
    _schedulerActive = false;

    // Always stop the native scheduler, even if _frameCallable is null
    // (which happens after hot restart when statics are reset)
    // All platforms use C API
    FrameScheduler_stop();

    // Clean up the Dart callback if it exists (release mode)
    if (_frameCallable != null) {
      _frameCallable!.close();
      _frameCallable = null;
    }

    // Clean up the port if it exists (debug mode)
    _framePort?.close();
    _framePort = null;
  }

  /// Initialize port-based frame scheduling (debug mode only).
  /// This mode is hot restart safe because Dart_PostCObject silently
  /// drops messages to dead ports instead of crashing.
  static Future<void> _initializePortMode() async {
    // Initialize Dart API DL in native code (only once per process)
    // All platforms use C API
    if (!_dartApiInitialized) {
      FrameScheduler_initDartApi(ffi.NativeApi.initializeApiDLData);
      _dartApiInitialized = true;
    }

    // Create receive port and listen for frame timestamps
    _framePort = ReceivePort();
    _framePort!.listen((message) {
      if (message is List) {
        // [frameTimeNanos, postTimeUs] — measure port transit latency
        final frameTimeNanos = message[0] as int;
        final postTimeUs = message[1] as int;
        final recvTimeUs = FrameScheduler_steadyClockUs();
        final transitUs = recvTimeUs - postTimeUs;
        _diagTransitSum += transitUs;
        _diagTransitCount++;
        if (transitUs > _diagTransitMax) _diagTransitMax = transitUs;
        if (transitUs > 2000) {
          // > 2ms transit
          _logger.warning(
              '[PORT] transit=${(transitUs / 1000.0).toStringAsFixed(1)}ms');
        }
        if (_diagTransitCount % 120 == 0) {
          final avgMs = _diagTransitSum / (_diagTransitCount * 1000.0);
          _logger.info(
              '[PORT] 120-frame transit avg=${(avgMs).toStringAsFixed(2)}ms '
              'max=${(_diagTransitMax / 1000.0).toStringAsFixed(1)}ms');
          _diagTransitSum = 0;
          _diagTransitCount = 0;
          _diagTransitMax = 0;
        }
        _onFrame(frameTimeNanos);
      } else {
        // Legacy: single int
        _onFrame(message as int);
      }
    });

    // Start scheduler with port
    // All platforms use C API (CVDisplayLink on macOS/iOS, DXGI on Windows, timer on others)
    final nativePort = _framePort!.sendPort.nativePort;
    FrameScheduler_startWithPort(nativePort, 60);

    _logger.info('Frame scheduler started in port mode (hot restart safe)');
  }

  /// Initialize Flutter-synced render loop on Linux.
  /// Flutter's frame scheduler controls timing; rendering happens on the
  /// native render thread. Each Flutter frame triggers:
  ///   FrameScheduler_requestRender → render thread → mark textures
  static Future<void> _initializeNativeRenderLoop() async {
    final dylib = ffi.DynamicLibrary.process();

    // Look up cross-library symbols from thermion_flutter_plugin.so
    final getHandleFn = dylib.lookupFunction<ffi.Pointer<ffi.Void> Function(),
        ffi.Pointer<ffi.Void> Function()>('thermion_flutter_get_plugin_handle');

    final pluginHandle = getHandleFn();

    // Look up the texture marking function from the Flutter plugin
    final markTexturesFnPtr = dylib
        .lookup<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>>(
            'thermion_flutter_mark_textures');

    final app = FilamentApp.instance as FFIFilamentApp;

    // Configure native render: set render thread, render manager + post-render texture mark
    FrameScheduler_setRenderThread(app.renderThreadHandle);
    FrameScheduler_setRenderManager(app.renderManager.getNativeHandle());
    FrameScheduler_setPostRenderCallback(markTexturesFnPtr, pluginHandle);

    // Synchronize with Flutter's frame clock via persistent frame callback.
    // Each Flutter frame triggers a non-blocking render request to the
    // native render thread.
    SchedulerBinding.instance.addPersistentFrameCallback(_onFlutterFrame);
    SchedulerBinding.instance.scheduleFrame();

    _logger.info('Flutter-synced render loop started');
  }

  /// Called on each Flutter frame. Triggers a native render and requests
  /// the next frame to keep the loop running.
  static void _onFlutterFrame(Duration timeStamp) {
    if (!_schedulerActive || FilamentApp.instance == null) return;
    FrameScheduler_requestRender(timeStamp.inMicroseconds * 1000);
    SchedulerBinding.instance.scheduleFrame();
  }

  static Future<void> _renderFrame() async {
    await FilamentApp.instance?.render();

    for (final descriptor in _descriptors) {
      descriptor.markTextureFrameAvailable();
    }
    for (final descriptor in _destroyed) {
      _descriptors.remove(descriptor);
      _logger.info(
        "Removed descriptor (hardware ID ${descriptor.hardwareId}, flutter ID ${descriptor.flutterTextureId}",
      );
    }
    _destroyed.clear();

    // Process deferred render target cleanup (Windows resize path).
    // Old RTs stay alive for a few frames so native can Blit from them.
    if (_deferredRenderTargets.isNotEmpty) {
      final ready = <(RenderTarget, int)>[];
      final remaining = <(RenderTarget, int)>[];
      for (final (rt, frames) in _deferredRenderTargets) {
        if (frames <= 0) {
          ready.add((rt, frames));
        } else {
          remaining.add((rt, frames - 1));
        }
      }
      _deferredRenderTargets
        ..clear()
        ..addAll(remaining);
      for (final (rt, _) in ready) {
        final color = await rt.getColorTexture();
        final depth = await rt.getDepthTexture();
        await color.destroy();
        await depth.destroy();
        await rt.destroy();
      }
    }
  }

  @override
  Future<SwapChain?> initialize({bool destroySwapchain = true}) async {
    // Stop any existing frame scheduler from a previous session (e.g., hot restart)
    // This prevents crashes from dangling callback pointers
    stopFrameScheduler();

    late Backend backend;
    if (options.nativeOptions.backend != null) {
      switch (options.nativeOptions.backend) {
        case Backend.VULKAN:
          if (!Platform.isWindows && !Platform.isLinux) {
            throw Exception("Vulkan only supported on Windows and Linux");
          }
        case Backend.METAL:
          if (!Platform.isIOS || !Platform.isMacOS) {
            throw Exception("Metal only supported on iOS/macOS");
          }
        case Backend.OPENGL:
          if (!Platform.isAndroid && !Platform.isLinux) {
            throw Exception("OpenGL only supported on Android and Linux");
          }
        default:
          throw Exception("Unsupported backend");
      }
      backend = options.nativeOptions.backend!;
    } else {
      if (Platform.isWindows) {
        backend = Backend.VULKAN;
      } else if (Platform.isMacOS || Platform.isIOS) {
        backend = Backend.METAL;
      } else if (Platform.isAndroid || Platform.isLinux) {
        backend = Backend.OPENGL;
      } else {
        throw Exception("Unsupported platform");
      }
    }

    int? driverPlatform;
    Pointer<Void> platformPtr = nullptr;
    int? sharedContext;
    Pointer<Void> sharedContextPtr = nullptr;
    if (!Platform.isMacOS && !Platform.isIOS) {
      driverPlatform =
          await channel.invokeMethod("getDriverPlatform", backend.index);
      platformPtr = driverPlatform == null
          ? nullptr
          : VoidPointerClass.fromAddress(driverPlatform);

      sharedContext =
          await channel.invokeMethod("getSharedContext", backend.index);

      sharedContextPtr = sharedContext == null
          ? nullptr
          : VoidPointerClass.fromAddress(sharedContext);
    }

    final config = FFIFilamentConfig(
      backend: backend,
      loadResource: loadAsset,
      platform: platformPtr,
      sharedContext: sharedContextPtr,
      uberArchivePath: options.uberarchivePath,
    );

    if (FilamentApp.instance == null) {
      await FFIFilamentApp.create(config: config);
      FilamentApp.instance!.onDestroy(() async {
        // Stop the frame scheduler BEFORE destroying the engine
        // to prevent crashes from dangling callback pointers
        stopFrameScheduler();

        if (Platform.isWindows || Platform.isLinux) {
          await channel.invokeMethod("destroyContext");
        }
      });
    }

    // on MacOS/iOS, even though we render directly into a render target,
    // for some reason we still need to create a headless swapchain (though the
    // dimensions don't seem to matter).
    // TODO - see if we can use `renderStandaloneView` in FilamentViewer to
    // avoid this
    SwapChain? swapChain;
    if (Platform.isMacOS ||
        Platform.isIOS ||
        Platform.isWindows ||
        Platform.isLinux) {
      swapChain ??= await FilamentApp.instance!.createHeadlessSwapChain(
        1,
        1,
        hasStencilBuffer: true,
      );
    }

    // Mark scheduler as active BEFORE starting it
    _schedulerActive = true;

    if (Platform.isLinux) {
      // Native render loop: vsync → render → mark textures all in native.
      // Bypasses Dart event loop entirely for minimal frame latency.
      await _initializeNativeRenderLoop();
    } else {
      // Use port-based mode in debug builds (hot restart safe)
      // Use direct callback in release builds (maximum performance)
      _usePortMode = kDebugMode &&
          (Platform.isMacOS ||
              Platform.isIOS ||
              Platform.isAndroid ||
              Platform.isWindows);

      if (_usePortMode) {
        // DEBUG MODE: Port-based (hot restart safe)
        // Messages to dead ports are silently dropped - no crash
        await _initializePortMode();
      } else {
        // RELEASE MODE: Direct callback (maximum performance)
        // All platforms use C API
        _frameCallable = ffi.NativeCallable<FrameCallbackFunction>.listener(
          _onFrame,
        );
        FrameScheduler_start(_frameCallable!.nativeFunction, 60);
      }
    }

    return swapChain;
  }

  @override
  void pauseFrameScheduler() {
    _frameSchedulerPaused = true;
  }

  @override
  void resumeFrameScheduler() {
    _frameSchedulerPaused = false;
  }

  /// Creates Filament textures + render target and binds them to [view].
  /// Extracted so it can be called immediately or deferred.
  static Future<void> _createFilamentResources(
    PlatformTextureDescriptor descriptor,
    View view,
    int width,
    int height,
  ) async {
    // Determine if we need the Vulkan external image path or direct GL/Metal import.
    // Vulkan path: builder.external() + setExternalImage (Windows, or Linux with Vulkan)
    // Direct import path: builder.import(textureId) (macOS/iOS Metal, Linux with OpenGL)
    final useExternalImage = Platform.isWindows ||
        ThermionFlutterPlugin.instance.options.nativeOptions.backend ==
            Backend.VULKAN;

    final color = await FilamentApp.instance!.createTexture(
      width,
      height,
      importedTextureHandle: useExternalImage ? -1 : descriptor.hardwareId,
      flags: {
        TextureUsage.TEXTURE_USAGE_BLIT_SRC,
        TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
        TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
      },
      textureFormat:
          instance.options.nativeOptions.renderTargetColorTextureFormat,
      textureSamplerType: TextureSamplerType.SAMPLER_2D,
    );

    if (useExternalImage) {
      await FilamentApp.instance!.setExternalImage(
        color,
        descriptor.hardwareId,
      );
    }

    final depth = await FilamentApp.instance!.createTexture(
      width,
      height,
      flags: {
        TextureUsage.TEXTURE_USAGE_BLIT_SRC,
        TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT,
        TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
        TextureUsage.TEXTURE_USAGE_STENCIL_ATTACHMENT,
      },
      textureFormat:
          instance.options.nativeOptions.renderTargetDepthTextureFormat,
      textureSamplerType: TextureSamplerType.SAMPLER_2D,
    );

    // Use tracked RT for destruction (not view.getRenderTarget()) because
    // in composite mode the view's RT may be an internal RT, not the Flutter RT
    final existingRenderTarget = _viewRenderTargets[view];

    var renderTarget = await FilamentApp.instance!.createRenderTarget(
      width,
      height,
      color: color,
      depth: depth,
    );

    await view.setRenderTarget(renderTarget);
    _viewRenderTargets[view] = renderTarget; // Track the new RT

    if (existingRenderTarget != null) {
      final color = await existingRenderTarget.getColorTexture();
      final depth = await existingRenderTarget.getDepthTexture();
      await color.destroy();
      await depth.destroy();
      await existingRenderTarget.destroy();
    }
    final swapChains = await FilamentApp.instance!.getSwapChains();
    await FilamentApp.instance!.renderManager.attach(view, swapChains.first);
  }

  /// Fire-and-forget: waits for populate() to create the GL texture,
  /// then creates Filament resources. Runs after createTextureAndBindToView
  /// returns so the Texture widget can be built first.
  static void _scheduleDeferredBinding(
    MethodChannelPlatformTextureDescriptor descriptor,
    View view,
    int width,
    int height,
  ) async {
    try {
      final hardwareId = await descriptor.awaitTextureReady();
      if (descriptor.destroyed) return;
      descriptor.hardwareId = hardwareId;
      _logger.info(
        'Deferred texture ready: flutter=${descriptor.flutterTextureId} hardware=$hardwareId',
      );
      await _createFilamentResources(descriptor, view, width, height);
    } catch (e) {
      _logger.warning('Deferred texture binding failed: $e');
    }
  }

  @override
  Future<PlatformTextureDescriptor?> createTextureAndBindToView(
    View view,
    int width,
    int height,
  ) async {
    if (width == 0 || height == 0) {
      throw Exception(
        "Invalid dimensions for texture descriptor : ${width}x${height}",
      );
    }

    late PlatformTextureDescriptor descriptor;

    if (Platform.isMacOS || Platform.isIOS) {
      descriptor = DarwinPlatformTextureDescriptorImpl.allocate(width, height);
    } else {
      descriptor = await MethodChannelPlatformTextureDescriptor.allocate(
        channel,
        width,
        height,
      );
    }

    // Add to descriptors early so markTextureFrameAvailable is called
    // (triggers populate() which creates the deferred GL texture)
    _descriptors.add(descriptor);

    // On Android, we recreate the swapchain whenever the size changes
    // TODO - why not allocate a larger swapchain initially and just change
    // the viewport?
    // In fact we can probably do this for all platforms
    if (Platform.isAndroid) {
      // The OLD swap chain to destroy is the one *previously bound to
      // this view* — not whatever happens to be at the front of
      // FilamentApp's global list. Earlier code iterated
      // `getSwapChains()` and destroyed `swapChains.first`, which in a
      // multi-viewer app destroyed *another* viewer's swap chain, freezing
      // its viewport. Tracking per-view in `_viewSwapChains` scopes the
      // destroy to this view only.
      final oldSwapChain = _viewSwapChains[view];

      final swapChain = await FilamentApp.instance!.createSwapChain(
        Pointer<Void>.fromAddress(descriptor.windowHandle!),
      );

      await FilamentApp.instance!.renderManager.attach(view, swapChain);
      _viewSwapChains[view] = swapChain;

      // Destroy the old swap chain after the new one is attached so the
      // view never has a window of being unattached.
      if (oldSwapChain != null) {
        await FilamentApp.instance!.destroySwapChain(oldSwapChain);
      }

      // On other platforms, if a hardware texture ID is returned, this means
      // the texture is immediately available for rendering.
    } else if (descriptor.hardwareId != 0) {
      await _createFilamentResources(descriptor, view, width, height);

      // On Linux, when running via EGL/OpenGL backend (Wayland),
      // we can only access the EGL context in the native populate() callback;
      // in other words, the platform thread cannot return a hardware texture ID.
      // We need to defer binding the surface.
      //
    } else if (Platform.isLinux) {
      _scheduleDeferredBinding(
          descriptor as MethodChannelPlatformTextureDescriptor,
          view,
          width,
          height);
    }

    await view.setViewport(width, height);

    return descriptor;
  }

  Future<PlatformTextureDescriptor> resizeTexture(
    PlatformTextureDescriptor texture,
    View view,
    int width,
    int height,
  ) async {
    // Block new frames while we swap textures.
    _resizing = true;
    while (_rendering) {
      await Future.delayed(const Duration(milliseconds: 1));
    }

    // Flush Filament's render thread so all queued GPU commands complete.
    await FilamentApp.instance!.flush();

    try {
      if (Platform.isWindows) {
        return await _resizeTextureWindows(texture, view, width, height);
      }

      // Non-Windows: full destroy + recreate (existing path)
      var newTexture = await createTextureAndBindToView(view, width, height);
      if (newTexture == null) {
        throw Exception('Failed to create texture during resize');
      }

      _descriptors.remove(texture);
      await texture.destroy();

      return newTexture;
    } finally {
      _resizing = false;
    }
  }

  /// Windows-specific resize: reuses the Flutter texture ID.
  ///
  /// The native side creates new D3D + Vulkan textures and stores a
  /// pending swap.  The swap fires after the first successful Blit into
  /// the new render target, so Flutter keeps compositing the last valid
  /// frame until the new one is ready.  No black frame.
  Future<PlatformTextureDescriptor> _resizeTextureWindows(
    PlatformTextureDescriptor texture,
    View view,
    int width,
    int height,
  ) async {
    // Ask native to create new GPU resources (no new Flutter texture)
    final result = await channel.invokeMethod("resizeTexture", [
      texture.flutterTextureId,
      width,
      height,
    ]);

    final externalImage = result[0] as int;

    // Re-create Filament render target with the new external image
    final color = await FilamentApp.instance!.createTexture(
      width,
      height,
      importedTextureHandle: -1,
      flags: {
        TextureUsage.TEXTURE_USAGE_BLIT_SRC,
        TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
        TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
      },
      textureFormat: options.nativeOptions.renderTargetColorTextureFormat,
      textureSamplerType: TextureSamplerType.SAMPLER_2D,
    );
    await FilamentApp.instance!.setExternalImage(color, externalImage);

    final depth = await FilamentApp.instance!.createTexture(
      width,
      height,
      flags: {
        TextureUsage.TEXTURE_USAGE_BLIT_SRC,
        TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT,
        TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
        TextureUsage.TEXTURE_USAGE_STENCIL_ATTACHMENT,
      },
      textureFormat: options.nativeOptions.renderTargetDepthTextureFormat,
      textureSamplerType: TextureSamplerType.SAMPLER_2D,
    );

    final existingRenderTarget = _viewRenderTargets[view];

    var renderTarget = await FilamentApp.instance!.createRenderTarget(
      width,
      height,
      color: color,
      depth: depth,
    );

    await view.setRenderTarget(renderTarget);
    _viewRenderTargets[view] = renderTarget;

    if (existingRenderTarget != null) {
      // Defer destruction: native still needs the old render target's
      // VkImage for Blit during the swap window (1-2 frames).
      // Clean up after 5 frames to be safe.
      _deferredRenderTargets.add((existingRenderTarget, 5));
    }

    final swapChains = await FilamentApp.instance!.getSwapChains();
    await FilamentApp.instance!.renderManager.attach(view, swapChains.first);

    await view.setViewport(width, height);

    // Update the existing descriptor in place — same Flutter texture ID
    texture.hardwareId = externalImage;
    texture.width = width;
    texture.height = height;

    return texture;
  }
}

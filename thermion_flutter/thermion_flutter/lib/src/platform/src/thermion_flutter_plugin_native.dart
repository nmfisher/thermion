import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart' show kDebugMode;
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
    show FrameScheduler_start, FrameScheduler_stop, FrameCallbackFunction,
         FrameScheduler_initDartApi, FrameScheduler_startWithPort;

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

  static bool _rendering = false;
  static ffi.NativeCallable<FrameCallbackFunction>? _frameCallable;
  static bool _schedulerActive = false;

  // Port-based mode for debug builds (hot restart safe)
  static ReceivePort? _framePort;
  static bool _usePortMode = false;
  static bool _dartApiInitialized = false;

  /// Called by native FrameScheduler at vsync/timer intervals.
  /// Not async — guards against re-entrant calls with [_rendering] flag.
  ///
  /// IMPORTANT: This can be called from native code even after hot restart
  /// while the native scheduler is being stopped. We MUST guard against this.
  static void _onFrame(int frameTimeNanos) {
    // Critical safety check: Ignore callbacks if scheduler is being shut down
    // or if we're in a hot restart scenario where FilamentApp is null
    if (!_schedulerActive || FilamentApp.instance == null) return;

    if (_rendering) return;
    _rendering = true;
    _renderFrame().then((_) {
      _rendering = false;
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
      // message is the frame timestamp in nanoseconds
      _onFrame(message as int);
    });

    // Start scheduler with port
    // All platforms use C API (CVDisplayLink on macOS/iOS, DXGI on Windows, timer on others)
    final nativePort = _framePort!.sendPort.nativePort;
    FrameScheduler_startWithPort(nativePort, 60);

    _logger.info('Frame scheduler started in port mode (hot restart safe)');
  }

  static Future<void> _renderFrame() async {
    await FilamentApp.instance?.render();

    for (final descriptor in _descriptors) {
        descriptor.markTextureFrameAvailable();
    }
    for (final descriptor in _destroyed) {
      _descriptors.remove(descriptor);
      _logger.info(
          "Removed descriptor (hardware ID ${descriptor.hardwareId}, flutter ID ${descriptor.flutterTextureId}");
    }
    _destroyed.clear();
  }

  @override
  Future<SwapChain?> initialize({bool destroySwapchain = true}) async {
    // Stop any existing frame scheduler from a previous session (e.g., hot restart)
    // This prevents crashes from dangling callback pointers
    stopFrameScheduler();

    var driverPlatform;
    Pointer<Void> platformPtr = nullptr;
    var sharedContext;
    Pointer<Void> sharedContextPtr = nullptr;
    if (!Platform.isMacOS && !Platform.isIOS) {
      driverPlatform = await channel.invokeMethod("getDriverPlatform");
      platformPtr = driverPlatform == null
          ? nullptr
          : VoidPointerClass.fromAddress(driverPlatform);

      sharedContext = await channel.invokeMethod("getSharedContext");

      sharedContextPtr = sharedContext == null
          ? nullptr
          : VoidPointerClass.fromAddress(sharedContext);
    }

    late Backend backend;
    if (options.nativeOptions.backend != null) {
      switch (options.nativeOptions.backend) {
        case Backend.VULKAN:
          if (!Platform.isWindows) {
            throw Exception("Vulkan only supported on Windows");
          }
        case Backend.METAL:
          if (!Platform.isIOS || !Platform.isMacOS) {
            throw Exception("Metal only supported on iOS/macOS");
          }
        case Backend.OPENGL:
          if (!Platform.isAndroid) {
            throw Exception("OpenGL only supported on Android");
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
      } else if (Platform.isAndroid) {
        backend = Backend.OPENGL;
      } else {
        throw Exception("Unsupported platform");
      }
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
        if (Platform.isWindows) {
          await channel.invokeMethod("destroyContext");
        }
      });
    }

    SwapChain? swapChain;

    // on MacOS/iOS, even though we render directly into a render target,
    // for some reason we still need to create a headless swapchain (though the
    // dimensions don't seem to matter).
    // TODO - see if we can use `renderStandaloneView` in FilamentViewer to
    // avoid this
    if (Platform.isMacOS || Platform.isIOS || Platform.isWindows) {
      swapChain ??= await FilamentApp.instance!
          .createHeadlessSwapChain(1, 1, hasStencilBuffer: true);
    }

    // Mark scheduler as active BEFORE starting it
    _schedulerActive = true;

    // Use port-based mode in debug builds (hot restart safe)
    // Use direct callback in release builds (maximum performance)
    // Supported on macOS, iOS, Android, and Windows
    _usePortMode = kDebugMode && (Platform.isMacOS || Platform.isIOS || Platform.isAndroid || Platform.isWindows);

    if (_usePortMode) {
      // DEBUG MODE: Port-based (hot restart safe)
      // Messages to dead ports are silently dropped - no crash
      await _initializePortMode();
    } else {
      // RELEASE MODE: Direct callback (maximum performance)
      // All platforms use C API
      _frameCallable = ffi.NativeCallable<FrameCallbackFunction>.listener(_onFrame);
      FrameScheduler_start(_frameCallable!.nativeFunction, 60);
    }

    return swapChain;
  }

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
          channel, width, height);
    }

    if (Platform.isAndroid) {
      final swapChain = await FilamentApp.instance!.createSwapChain(
        Pointer<Void>.fromAddress(descriptor.windowHandle!),
      );

      final existingSwapChain = await FilamentApp.instance!.getSwapChain(view);
      
      await FilamentApp.instance!.setRenderOrder(swapChain, view);
      
      if (existingSwapChain != null) {
        await FilamentApp.instance!.setRenderOrder(existingSwapChain, view, renderOrder: -1);
        await FilamentApp.instance!.destroySwapChain(existingSwapChain);
      }
    } else {
      final swapChains = await FilamentApp.instance!.getSwapChains();
      final color = await FilamentApp.instance!.createTexture(
        descriptor.width,
        descriptor.height,
        importedTextureHandle: Platform.isWindows ? -1 : descriptor.hardwareId,
        flags: {
          TextureUsage.TEXTURE_USAGE_BLIT_SRC,
          TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
          TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
        },
        textureFormat: options.nativeOptions.renderTargetColorTextureFormat,
        textureSamplerType: TextureSamplerType.SAMPLER_2D,
      );
      if (Platform.isWindows) {
        await FilamentApp.instance!.setExternalImage(color, descriptor.hardwareId);
      }
      final depth = await FilamentApp.instance!.createTexture(
        descriptor.width,
        descriptor.height,
        flags: {
          TextureUsage.TEXTURE_USAGE_BLIT_SRC,
          TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT,
          TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
          TextureUsage.TEXTURE_USAGE_STENCIL_ATTACHMENT
        },
        textureFormat: options.nativeOptions.renderTargetDepthTextureFormat,
        textureSamplerType: TextureSamplerType.SAMPLER_2D,
      );

      // Use tracked RT for destruction (not view.getRenderTarget()) because
      // in composite mode the view's RT may be an internal RT, not the Flutter RT
      final existingRenderTarget = _viewRenderTargets[view];

      var renderTarget = await FilamentApp.instance!.createRenderTarget(
        descriptor.width,
        descriptor.height,
        color: color,
        depth: depth,
      );

      await view.setRenderTarget(renderTarget);
      _viewRenderTargets[view] = renderTarget;  // Track the new RT

      if (existingRenderTarget != null) {
        final color = await existingRenderTarget.getColorTexture();
        final depth = await existingRenderTarget.getDepthTexture();
        await color.destroy();
        await depth.destroy();
        await existingRenderTarget.destroy();
      }
      await FilamentApp.instance!.setRenderOrder(swapChains.first, view);

    }

    await view.setViewport(width, height);

    _descriptors.add(descriptor);

    return descriptor;
  }

  Future<PlatformTextureDescriptor> resizeTexture(
    PlatformTextureDescriptor texture,
    View view,
    int width,
    int height,
  ) async {
    var newTexture = await createTextureAndBindToView(view, width, height);
    if (newTexture == null) {
      throw Exception();
    }

    _descriptors.remove(texture);

    texture.destroy();

    return newTexture;
  }
}

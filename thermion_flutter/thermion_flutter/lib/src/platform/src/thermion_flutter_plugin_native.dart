import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' hide View;
import 'package:logging/logging.dart';
import 'package:thermion_flutter/src/platform/src/frame_scheduler.dart';
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor_factory.dart';
import '../../../thermion_flutter.dart';
import 'platform_texture_descriptor.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

/// Handles platform-specific initialization to create a backing rendering
/// surface in a Flutter application and lifecycle listeners to pause rendering
/// when the app is inactive or in the background.
///
/// Frame scheduling is delegated to [FrameScheduler]; this class owns the
/// descriptor / render-target lifecycle and the [WidgetsBindingObserver]
/// hookup.
class ThermionFlutterPluginImpl extends ThermionFlutterPlugin
    with WidgetsBindingObserver {
  final channel = const MethodChannel("dev.thermion.flutter/event");

  ThermionFlutterPluginImpl() {
    channel.setMethodCallHandler(_handlePlatformMethodCall);
  }

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
  // has been redirected to an internal RT (e.g. in composite highlight mode).
  static final _viewRenderTargets = <View, RenderTarget>{};

  Future<void> _textureOperationChain = Future<void>.value();

  // Deferred Filament render target cleanup for Windows resize.
  // Old RT stays alive so native can Blit from it during the swap window.
  static final _deferredRenderTargets = <(RenderTarget, int)>[];

  bool _explicitlyPaused = false;
  bool _lifecycleSuspended = false;
  bool _resizing = false;

  bool get _pauseRequested =>
      _explicitlyPaused ||
      _lifecycleSuspended ||
      _resizing ||
      _descriptors.any((descriptor) => !descriptor.isSurfaceAvailable);

  PlatformTextureDescriptor? _descriptorForTextureId(int textureId) {
    for (final descriptor in _descriptors) {
      if (descriptor.flutterTextureId == textureId) return descriptor;
    }
    return null;
  }

  Future<Object?> _handlePlatformMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSurfaceCleanup':
        final descriptor = _descriptorForTextureId(call.arguments as int);
        if (descriptor == null) return null;
        descriptor.markSurfaceUnavailable();
        FrameScheduler.instance.pause();
        await _serializeTextureOperation(() async {
          if (_descriptors.contains(descriptor)) {
            await descriptor.cleanupSurface();
          }
        });
        return null;
      case 'onSurfaceAvailable':
        final arguments = call.arguments as List<Object?>;
        final textureId = arguments[0] as int;
        final descriptor = _descriptorForTextureId(textureId);
        if (descriptor == null) return null;
        final wasAvailable = descriptor.isSurfaceAvailable;
        descriptor.markSurfaceUnavailable();
        if (wasAvailable) {
          FrameScheduler.instance.pause();
        }
        try {
          await _serializeTextureOperation(() async {
            if (!_descriptors.contains(descriptor)) return;
            await descriptor.restoreSurface(arguments[1] as int);
            _resumeTextureRenderingIfReady();
          });
        } catch (error, stackTrace) {
          _logger.severe(
            'Failed to restore texture surface $textureId',
            error,
            stackTrace,
          );
          rethrow;
        }
        return null;
      case 'onSurfaceError':
        final arguments = call.arguments as List<Object?>;
        final textureId = arguments[0] as int;
        final descriptor = _descriptorForTextureId(textureId);
        if (descriptor == null) return null;
        descriptor.markSurfaceError();
        FrameScheduler.instance.pause();
        _logger.severe(
          'Surface recovery failed for texture $textureId: ${arguments[1]}',
        );
        return null;
      default:
        throw MissingPluginException(
          'Unknown platform callback ${call.method}',
        );
    }
  }

  Future<R> _serializeTextureOperation<R>(Future<R> Function() operation) {
    final completer = Completer<R>();
    _textureOperationChain = _textureOperationChain.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void _resumeTextureRenderingIfReady() {
    if (!_pauseRequested) {
      FrameScheduler.instance.resume();
    }
  }

  bool _suspendForLifecycle() {
    if (_lifecycleSuspended) return false;
    _lifecycleSuspended = true;

    if (Platform.isLinux) {
      // Linux registers one persistent Flutter frame callback. Keep it
      // registered, but stop it from re-arming while the app is hidden.
      FrameScheduler.instance.pause();
    } else {
      FrameScheduler.instance.stop();
    }
    return true;
  }

  Future<void> _resumeFromLifecycle() async {
    if (!_lifecycleSuspended) return;
    _lifecycleSuspended = false;

    if (FilamentApp.instance == null) return;

    if (Platform.isLinux) {
      if (!_pauseRequested) {
        FrameScheduler.instance.resume();
      }
    } else {
      await FrameScheduler.instance.start();
      if (_pauseRequested) {
        FrameScheduler.instance.pause();
      } else {
        FrameScheduler.instance.resume();
      }
    }
    _logger.info('App foregrounded, frame scheduler resumed');
  }

  void _syncLifecycleState() {
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null) {
      didChangeAppLifecycleState(state);
    }
  }

  Future<void> _renderFrame() async {
    if (FilamentApp.instance == null) return;

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
    // After a hot restart in debug mode, any previous Dart isolate no longer
    // exists, but the native scheduler may have retained a dangling callback
    // pointer to the old isolate. We call stop() here (which is idempotent)
    // to ensure this is disposed cleanly before instantiating a new FrameScheduler.instance.
    FrameScheduler.instance.stop();
    WidgetsBinding.instance.removeObserver(this);

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
      driverPlatform = await channel.invokeMethod(
        "getDriverPlatform",
        backend.index,
      );
      platformPtr = driverPlatform == null
          ? nullptr
          : VoidPointerClass.fromAddress(driverPlatform);

      sharedContext = await channel.invokeMethod(
        "getSharedContext",
        backend.index,
      );

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
        FrameScheduler.instance.stop();
        WidgetsBinding.instance.removeObserver(this);

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

    FrameScheduler.instance.setOnFrame(_renderFrame);

    if (Platform.isLinux) {
      // Native render loop: vsync → render → mark textures all in native.
      // Bypasses Dart event loop entirely for minimal frame latency.
      final dylib = ffi.DynamicLibrary.process();
      final getHandleFn = dylib
          .lookupFunction<
            ffi.Pointer<ffi.Void> Function(),
            ffi.Pointer<ffi.Void> Function()
          >('thermion_flutter_get_plugin_handle');
      final pluginHandle = getHandleFn();
      final markTexturesFnPtr = dylib
          .lookup<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>>(
            'thermion_flutter_mark_textures',
          );

      final app = FilamentApp.instance as FFIFilamentApp;
      await FrameScheduler.instance.startFlutterSynced(
        renderThreadHandle: app.renderThreadHandle,
        renderManagerHandle: app.renderManager.getNativeHandle(),
        postRenderCallback: markTexturesFnPtr,
        postRenderUserData: pluginHandle,
      );
    } else {
      await FrameScheduler.instance.start();
    }

    // Register only after the scheduler has started, then immediately apply
    // the current state. This covers initialization while already hidden
    // without allowing the subsequent start call to undo the suspension.
    WidgetsBinding.instance.addObserver(this);
    _syncLifecycleState();
    if (_pauseRequested) {
      FrameScheduler.instance.pause();
    }

    return swapChain;
  }

  @override
  void pauseFrameScheduler() {
    _explicitlyPaused = true;
    FrameScheduler.instance.pause();
  }

  @override
  void resumeFrameScheduler() {
    _explicitlyPaused = false;
    if (!_pauseRequested) {
      FrameScheduler.instance.resume();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_suspendForLifecycle()) {
          _logger.info('App hidden, frame scheduler suspended');
        }
        break;
      case AppLifecycleState.resumed:
        unawaited(
          _resumeFromLifecycle().catchError((Object error) {
            _logger.severe('Failed to resume frame scheduler: $error');
          }),
        );
        break;
      case AppLifecycleState.inactive:
        // The app can remain visible while inactive (split screen, system UI,
        // or an unfocused desktop window), so rendering remains enabled.
        break;
    }
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
    final useExternalImage =
        Platform.isWindows ||
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
    PlatformTextureDescriptor descriptor,
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
  ) {
    return _serializeTextureOperation(
      () => _createTextureAndBindToView(view, width, height),
    );
  }

  Future<PlatformTextureDescriptor?> _createTextureAndBindToView(
    View view,
    int width,
    int height,
  ) async {
    if (width == 0 || height == 0) {
      throw Exception(
        "Invalid dimensions for texture descriptor : ${width}x$height",
      );
    }

    final descriptor = await createPlatformTextureDescriptor(
      channel,
      width,
      height,
    );

    // Add to descriptors early so markTextureFrameAvailable is called
    // (triggers populate() which creates the deferred GL texture)
    _descriptors.add(descriptor);

    final bound = await _bindDescriptorToView(descriptor, view);
    if (!bound && descriptor.hardwareId != 0) {
      // If a hardware texture ID is returned, the texture is immediately
      // available for rendering.
      await _createFilamentResources(descriptor, view, width, height);

      // On Linux, when running via EGL/OpenGL backend (Wayland),
      // we can only access the EGL context in the native populate() callback;
      // in other words, the platform thread cannot return a hardware texture ID.
      // We need to defer binding the surface.
      //
    } else if (Platform.isLinux) {
      if (!descriptor.deferred) {
        throw StateError(
          'Deferred texture creation requires a deferred descriptor',
        );
      }
      _scheduleDeferredBinding(descriptor, view, width, height);
    }

    await view.setViewport(width, height);

    return descriptor;
  }

  @override
  Future<PlatformTextureDescriptor> resizeTexture(
    PlatformTextureDescriptor texture,
    View view,
    int width,
    int height,
  ) {
    return _serializeTextureOperation(
      () => _resizeTexture(texture, view, width, height),
    );
  }

  Future<PlatformTextureDescriptor> _resizeTexture(
    PlatformTextureDescriptor texture,
    View view,
    int width,
    int height,
  ) async {
    // Block new frames while we swap textures, then wait for any in-flight
    // frame to finish before we touch render targets.
    _resizing = true;
    FrameScheduler.instance.pause();
    while (FrameScheduler.instance.isRendering) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }

    // Flush Filament's render thread so all queued GPU commands complete.
    await FilamentApp.instance!.flush();

    try {
      if (Platform.isWindows) {
        return await _resizeTextureWindows(texture, view, width, height);
      }

      // Non-Windows: full destroy + recreate (existing path).
      // TODO: alternatively, allocate a larger swapchain up front and just
      // change the viewport on resize, avoiding the destroy/recreate.
      var newTexture = await _createTextureAndBindToView(view, width, height);
      if (newTexture == null) {
        throw Exception('Failed to create texture during resize');
      }

      _descriptors.remove(texture);
      await texture.destroy();

      return newTexture;
    } finally {
      _resizing = false;
      if (!_pauseRequested) {
        FrameScheduler.instance.resume();
      }
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

  /// Binds [descriptor] to [view], then releases any *other* descriptor still
  /// bound to the same view, so a view never holds two active bindings.
  ///
  /// Scoping the release to descriptors on *this* view (matched via
  /// [PlatformTextureDescriptor.boundView]) — rather than touching every swap
  /// chain in FilamentApp's global list — is what makes multi-viewer apps
  /// work: without the per-view scoping, mounting viewer #N would release
  /// viewer #(N-1)'s swap chain and freeze it.
  Future<bool> _bindDescriptorToView(
    PlatformTextureDescriptor descriptor,
    View view,
  ) async {
    if (!await descriptor.bindToView(view)) return false;
    for (final other in _descriptors) {
      if (other != descriptor && other.boundView == view) {
        await other.releaseBinding();
      }
    }
    return true;
  }

  @override
  Future<void> releaseTextureBindingForView(View view) {
    return _serializeTextureOperation(() => _releaseBindingForView(view));
  }

  Future<void> _releaseBindingForView(View view) async {
    final released = _descriptors
        .where((descriptor) => descriptor.boundView == view)
        .toList();
    for (final descriptor in released) {
      await descriptor.releaseBinding();
      _descriptors.remove(descriptor);
    }
    _resumeTextureRenderingIfReady();
  }
}

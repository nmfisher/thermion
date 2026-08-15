import 'dart:io';

import 'package:flutter/services.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

import 'native_rendering_lifecycle_controller.dart';
import 'native_texture_surface_manager.dart';
import 'platform_texture_descriptor.dart';
import '../../../thermion_flutter.dart';

/// Initializes the native Filament application and delegates frame lifecycle
/// and texture-surface ownership to focused collaborators.
class ThermionFlutterPluginImpl extends ThermionFlutterPlugin {
  ThermionFlutterPluginImpl() {
    _lifecycle = NativeRenderingLifecycleController(
      hasUnavailableSurfaces: () => _textureSurfaces.hasUnavailableSurfaces,
      onFrameRendered: () => _textureSurfaces.onFrameRendered(),
    );
    _textureSurfaces = NativeTextureSurfaceManager(
      lifecycle: _lifecycle,
      options: () => options.nativeOptions,
    );
  }

  late final NativeRenderingLifecycleController _lifecycle;
  late final NativeTextureSurfaceManager _textureSurfaces;

  static Future<Uint8List> loadAsset(String path) async {
    if (path.startsWith('file://')) {
      return File(path.replaceAll('file://', '')).readAsBytesSync();
    }
    if (path.startsWith('asset://')) {
      path = path.replaceAll('asset://', '');
    }
    final asset = await rootBundle.load(path);
    return asset.buffer.asUint8List(asset.offsetInBytes);
  }

  /// Serialises concurrent [initialize] calls.
  ///
  /// Batch-mounting viewers (several `ViewerWidget`s inflating in the same
  /// frame) call `createViewer` → `initialize` concurrently. Each call used
  /// to run engine creation itself: the `FilamentApp.instance == null` check
  /// below sits after an await, so every racing call saw null, and each
  /// `FFIFilamentApp.create` destroyed the engine the previous call had just
  /// built (create() tears down whatever engine is current before creating a
  /// new one). Viewers and the frame scheduler then held swapchains and
  /// render managers belonging to engines that were torn down underneath
  /// them, and Filament aborted on the next frame with `endFrame:490 —
  /// SwapChain must remain valid` inside `RenderManager::render`.
  ///
  /// All callers now share one in-flight initialization (and therefore one
  /// engine); the rest of the mount proceeds concurrently as before.
  static Future<InitializeResult>? _initialization;

  @override
  Future<InitializeResult> initialize({
    bool destroySwapchain = true,
    String? canvasId,
  }) {
    // canvasId is web-only; native renders into its own surfaces.
    return _initialization ??= _initialize().whenComplete(
      () => _initialization = null,
    );
  }

  Future<InitializeResult> _initialize() async {
    // A hot restart can leave the native scheduler holding a callback into the
    // previous isolate. stop() is idempotent and clears that callback first.
    _lifecycle.prepareForInitialization();

    final backend = _resolveBackend();
    final renderingContext = await _textureSurfaces.getFilamentRenderingContext(
      backend,
    );
    final config = FFIFilamentConfig(
      backend: backend,
      loadResource: loadAsset,
      platform: renderingContext.platform,
      sharedContext: renderingContext.sharedContextPointer,
      uberArchivePath: options.uberarchivePath,
    );

    if (FilamentApp.instance == null) {
      await FFIFilamentApp.create(config: config);
      FilamentApp.instance!.onBeforeDestroy(() async {
        // Stop and drain the native scheduler while its RenderManager and
        // RenderThread pointers are still valid.
        _lifecycle.stop();
      });
      FilamentApp.instance!.onDestroy(() async {
        _textureSurfaces.onEngineDestroyed();
        await _textureSurfaces.destroyFilamentRenderingContext();
      });
    }

    final swapChain = await _createDefaultSwapChain();
    await _lifecycle.start();
    return InitializeResult(app: FilamentApp.instance!, swapChain: swapChain);
  }

  Backend _resolveBackend() {
    final configured = options.nativeOptions.backend;
    if (configured != null) {
      switch (configured) {
        case Backend.VULKAN:
          if (!Platform.isWindows && !Platform.isLinux) {
            throw UnsupportedError(
              'Vulkan is only supported on Windows and Linux',
            );
          }
        case Backend.METAL:
          if (!Platform.isIOS && !Platform.isMacOS) {
            throw UnsupportedError('Metal is only supported on iOS and macOS');
          }
        case Backend.OPENGL:
          if (!Platform.isAndroid && !Platform.isLinux) {
            throw UnsupportedError(
              'OpenGL is only supported on Android and Linux',
            );
          }
        case Backend.WEBGPU:
          // Local-testing only. Requires the thermion_dart native lib to
          // have been built with hooks.user_defines.thermion_dart.webgpu:
          // true (which links Dawn) against a Filament built with
          // FILAMENT_SUPPORTS_WEBGPU=ON. Engine_create auto-constructs
          // the platform-specific WebGPUPlatform subclass on the C++ side.
        default:
          throw UnsupportedError('Unsupported backend: $configured');
      }
      return configured;
    }

    if (Platform.isWindows) return Backend.VULKAN;
    if (Platform.isMacOS || Platform.isIOS) return Backend.METAL;
    if (Platform.isAndroid || Platform.isLinux) return Backend.OPENGL;
    throw UnsupportedError('Unsupported platform: $Platform');
  }

  Future<SwapChain?> _createDefaultSwapChain() async {
    if (!Platform.isMacOS &&
        !Platform.isIOS &&
        !Platform.isWindows &&
        !Platform.isLinux) {
      return null;
    }

    // Direct render targets on desktop and Darwin still require a headless
    // swapchain for RenderManager scheduling.
    return FilamentApp.instance!.createHeadlessSwapChain(
      1,
      1,
      hasStencilBuffer: true,
    );
  }

  @override
  void pauseFrameScheduler() {
    _lifecycle.pauseExplicitly();
  }

  @override
  void resumeFrameScheduler() {
    _lifecycle.resumeExplicitly();
  }

  @override
  Future<PlatformTextureDescriptor?> createTextureAndBindToView(
    View view,
    int width,
    int height,
  ) {
    return _textureSurfaces.createAndBind(view, width, height);
  }

  @override
  Future<PlatformTextureDescriptor> resizeTexture(
    PlatformTextureDescriptor texture,
    View view,
    int width,
    int height,
  ) {
    return _textureSurfaces.resize(texture, view, width, height);
  }

  @override
  Future<void> destroyTextureForView(View view) {
    return _textureSurfaces.destroyForView(view);
  }
}

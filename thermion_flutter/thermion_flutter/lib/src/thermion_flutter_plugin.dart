import 'dart:async';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_flutter/src/options.dart';
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor.dart';
import 'platform/platform.dart';
import 'package:logging/logging.dart';

export 'platform/platform.dart' hide ThermionFlutterPluginImpl;

/// An implementation of [ThermionFlutterPlatform] that uses
/// a Flutter platform channel to create a native rendering context, resource
/// loader and rendering surfaces.
abstract class ThermionFlutterPlugin {
  static late final _logger = Logger("ThermionFlutterPlugin");
  static ThermionFlutterPluginImpl? _instance;

  static ThermionFlutterPlugin get instance {
    _instance ??= ThermionFlutterPluginImpl();
    return _instance!;
  }

  ThermionFlutterOptions _options = const ThermionFlutterOptions();

  ThermionFlutterOptions get options => _options;

  void setOptions(ThermionFlutterOptions options) {
    _options = options;
  }

  void pauseFrameScheduler();

  void resumeFrameScheduler();

  // Initialize the plugin and create the default swapchain.
  Future<SwapChain?> initialize({bool destroySwapchain = true});

  // Creates a rendering surface and binds to the given [View].
  // This is an internal method, don't call this yourself unless you are a 
  // thermion package developer. 

  // The specific surface type created will depend on the platform.
  // [width] and [height] are expected to be in physical pixels; make sure
  // these have been scaled by devicePixelRatio if appropriate.
  Future<PlatformTextureDescriptor?> createTextureAndBindToView(
    View view,
    int width,
    int height,
  );

  // Resize an existing texture. On Windows this reuses the Flutter texture ID
  // to avoid a black frame flash. On other platforms falls back to destroy +
  // recreate.
  Future<PlatformTextureDescriptor> resizeTexture(
    PlatformTextureDescriptor texture,
    View view,
    int width,
    int height,
  );

  /// Release plugin-side resources bound to this view (e.g. the per-view
  /// `SwapChain` the Android plugin tracks). Call this BEFORE destroying
  /// the underlying texture / surface descriptor — otherwise on Android
  /// the SurfaceTexture is released first, the swap chain's native
  /// window becomes invalid, and Filament's next `eglSwapBuffers` call
  /// for that swap chain returns `EGL_BAD_SURFACE` until the widget
  /// finishes unmounting.
  ///
  /// Safe to call on platforms that don't track per-view bindings (e.g.
  /// the web plugin) — it's a no-op there.
  Future<void> releaseTextureBindingForView(View view);

  static Future<ThermionViewer> createViewer(
      {bool destroySwapchain = true}) async {
    _logger.finest("Creating viewer");
    final swapChain =
        await instance.initialize(destroySwapchain: destroySwapchain);
    _logger.finest("Plugin initialized");
    final viewer = ThermionViewerFFI(
        createOverlay: instance.options.nativeOptions.createOverlay);
    await viewer.initialized;
    _logger.finest("Viewer initialized");
    if (swapChain != null) {
      _logger.finest("Registering swapchain");
      await FilamentApp.instance!.renderManager.attach(viewer.view, swapChain);
      _logger.finest("Swapchain registered");
    }

    return viewer;
  }
}

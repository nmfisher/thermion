import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:thermion_dart/thermion_dart.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_flutter/src/options.dart';
import 'package:thermion_flutter/src/platform/src/platform_texture_descriptor.dart';

import 'platform/platform.dart';

import 'package:logging/logging.dart';

export 'platform/platform.dart' hide ThermionFlutterPluginImpl;

/// Result of [ThermionFlutterPlugin.initialize].
///
/// Callers must use [app] (never `FilamentApp.instance`): on web each
/// `createViewer` builds its own engine, and the static may have moved on
/// to a newer engine by the time the caller resumes.
class InitializeResult {
  const InitializeResult({required this.app, this.swapChain});

  /// The engine app created (or reused) by this initialization.
  final FilamentApp app;

  /// The default swapchain to attach new views to, or null on platforms
  /// that provide their own surfaces.
  final SwapChain? swapChain;
}

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

  /// Initialize the plugin and create the default swapchain.
  ///
  /// [canvasId] is web-only: the DOM id of the canvas this viewer's engine
  /// should render into. An existing element with that id is adopted
  /// (transfer happens immediately, so it must exist before the call);
  /// otherwise one is created. Null generates a default id.
  Future<InitializeResult> initialize({
    bool destroySwapchain = true,
    String? canvasId,
  });

  /// Hook invoked by [createViewer] once [view] exists and is attached to
  /// [swapChain]. Web uses it to route the view to the engine/canvas that
  /// this initialization created. Defaults to a no-op.
  void onViewerCreated(View view, SwapChain? swapChain) {}

  /// Hook invoked after a viewer's resources (its View etc.) have been
  /// disposed. Web destroys the viewer's engine here (one engine per viewer).
  /// Defaults to a no-op.
  Future<void> onViewerDisposed(View view) async {}

  /// Web-only: the DOM canvas id hosting [view]'s engine, or null when the
  /// canvas is not hosted as a widget. Used by the web surface builder.
  String? canvasIdForView(View view) => null;

  /// Applies the target frame rate to every engine (web runs one engine per
  /// viewer).
  void setTargetFramerate(int fps) {
    FilamentApp.instance?.setTargetFramerate(fps);
  }

  /// Allocates the throwaway external texture that must be composited by
  /// Flutter before the native viewer can be created. Returns null when the
  /// running platform has no such prerequisite and the caller may initialize
  /// immediately.
  ///
  /// Consumed by ThermionTextureBootstrap; not part of the public API.
  @internal
  Future<int?> createContextBootstrap() async => null;

  /// Waits until Flutter has populated a texture returned by
  /// [createContextBootstrap]. Not part of the public API.
  @internal
  Future<void> awaitContextBootstrap(int textureId) async {}

  /// Releases a texture returned by [createContextBootstrap]. Not part of the
  /// public API.
  @internal
  Future<void> destroyContextBootstrap(int textureId) async {}

  /// Creates a rendering surface and binds to the given [View].
  /// This is an internal method, don't call this yourself unless you are a
  /// thermion package developer.
  /// The specific surface type created will depend on the platform.
  /// [width] and [height] are expected to be in physical pixels; make sure
  /// these have been scaled by devicePixelRatio if appropriate.
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

  /// Releases every texture resource bound to [view].
  ///
  /// Implementations must detach descriptor-managed surfaces, destroy
  /// Filament render targets, and only then destroy the underlying platform
  /// texture. Descriptors previously bound to [view] are invalid after this
  /// future completes.
  Future<void> destroyTextureForView(View view);

  @Deprecated('Use destroyTextureForView')
  Future<void> releaseTextureBindingForView(View view) =>
      destroyTextureForView(view);

  static Future<ThermionViewer> createViewer({
    bool destroySwapchain = true,
    String? canvasId,
  }) async {
    _logger.finest("Creating viewer");
    final result = await instance.initialize(
      destroySwapchain: destroySwapchain,
      canvasId: canvasId,
    );
    _logger.finest("Plugin initialized");
    final viewer = ThermionViewerFFI(
      createOverlay: instance.options.nativeOptions.createOverlay,
      app: result.app as FFIFilamentApp,
    );
    await viewer.initialized;
    _logger.finest("Viewer initialized");
    final swapChain = result.swapChain;
    if (swapChain != null) {
      _logger.finest("Registering swapchain");
      // Use the app from THIS initialization — on web each createViewer
      // builds its own engine, so FilamentApp.instance may already point at
      // a newer one by the time we resume.
      await result.app.renderManager.attach(viewer.view, swapChain);
      _logger.finest("Swapchain registered");
    }
    instance.onViewerCreated(viewer.view, swapChain);

    return viewer;
  }
}

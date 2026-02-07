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

  // Initialize the plugin and create the default swapchain.
  Future<SwapChain?> initialize({bool destroySwapchain = true});

  // Create a rendering surface and binds to the given [View]. This is internal;
  // unless you are [thermion_*] package developer, don't
  // call this yourself. May not be supported on all platforms.
  Future<PlatformTextureDescriptor?> createTextureAndBindToView(
    View view,
    int width,
    int height,
  );

  // Destroy any platform resources (swapchains, render targets) bound to a view.
  // Called when the widget displaying this view is disposed.
  Future<void> destroyViewResources(View view);

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
      await FilamentApp.instance!.setRenderOrder(swapChain, viewer.view, renderOrder: 0);
      _logger.finest("Swapchain registered");
    }

    // Allow rendering now that the new view is registered.
    // The native render list has been updated with the new view via
    // setRenderOrder → updateRenderOrder → RenderManager_setRenderableRenderThread.
    ThermionFlutterPluginImpl.viewerCreating = false;

    return viewer;
  }
}

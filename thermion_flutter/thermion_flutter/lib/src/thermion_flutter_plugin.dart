import 'dart:async';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_flutter/src/options.dart';
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

  Future<SwapChain?> initialize({bool destroySwapchain = true});

  static Future<ThermionViewer> createViewer(
      {bool destroySwapchain = true}) async {
    _logger.finest("Creating viewer");
    final swapChain = await instance.initialize(destroySwapchain: destroySwapchain);
    _logger.finest("Plugin initialized");
    final viewer = ThermionViewerFFI();
    await viewer.initialized;
    _logger.finest("Viewer initialized");
    if (swapChain != null) {
      _logger.finest("Registering swapchain");
      await FilamentApp.instance!.register(swapChain, viewer.view);
      _logger.finest("Swapchain registered");
    }

    await viewer.view.setRenderable(true);
    _logger.finest("Set view to renderable");

    return viewer;
  }
}

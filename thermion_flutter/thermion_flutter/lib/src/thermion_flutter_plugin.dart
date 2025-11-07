import 'dart:async';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_flutter/src/options.dart';
import 'platform/platform.dart';

export 'platform/platform.dart' hide ThermionFlutterPluginImpl;

/// An implementation of [ThermionFlutterPlatform] that uses
/// a Flutter platform channel to create a native rendering context, resource
/// loader and rendering surfaces.
abstract class ThermionFlutterPlugin {
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

  Future<SwapChain?> initialize();

  static Future<ThermionViewer> createViewer(
      {bool destroySwapchain = true}) async {
    final swapChain = await instance.initialize();
    final viewer = ThermionViewerFFI();
    await viewer.initialized;
    if (swapChain != null) {
      await FilamentApp.instance!.register(swapChain, viewer.view);
    }

      await viewer.view.setRenderable(true);
    
    return viewer;
  }
}

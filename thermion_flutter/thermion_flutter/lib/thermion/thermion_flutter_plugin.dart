import 'dart:async';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:flutter/widgets.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';

///
/// Handles all platform-specific initialization to create a backing rendering
/// surface in a Flutter application and lifecycle listeners to pause rendering
/// when the app is inactive or in the background.
/// Call [createViewer] to create an instance of [ThermionViewer].
///
class ThermionFlutterPlugin {
  ThermionFlutterPlugin._();

  static AppLifecycleListener? _appLifecycleListener;

  static bool _initializing = false;

  static ThermionViewer? _viewer;

  static bool _wasRenderingOnInactive = false;

  static void _handleStateChange(AppLifecycleState state) async {
    if (_viewer == null) {
      return;
    }

    await _viewer!.initialized;
    switch (state) {
      case AppLifecycleState.detached:
        if (!_wasRenderingOnInactive) {
          _wasRenderingOnInactive = _viewer!.rendering;
        }
        await _viewer!.setRendering(false);
        break;
      case AppLifecycleState.hidden:
        if (!_wasRenderingOnInactive) {
          _wasRenderingOnInactive = _viewer!.rendering;
        }
        await _viewer!.setRendering(false);
        break;
      case AppLifecycleState.inactive:
        if (!_wasRenderingOnInactive) {
          _wasRenderingOnInactive = _viewer!.rendering;
        }
        // on Windows in particular, restoring a window after minimizing stalls the renderer (and the whole application) for a considerable length of time.
        // disabling rendering on minimize seems to fix the issue (so I wonder if there's some kind of command buffer that's filling up while the window is minimized).
        await _viewer!.setRendering(false);
        break;
      case AppLifecycleState.paused:
        if (!_wasRenderingOnInactive) {
          _wasRenderingOnInactive = _viewer!.rendering;
        }
        await _viewer!.setRendering(false);
        break;
      case AppLifecycleState.resumed:
        await _viewer!.setRendering(_wasRenderingOnInactive);
        break;
    }
  }

  @Deprecated("Use createViewerWithOptions")
  static Future<ThermionViewer> createViewer({String? uberArchivePath}) async {
    if (_initializing) {
      throw Exception("Existing call to createViewer has not completed.");
    }
    _initializing = true;

    _viewer = await ThermionFlutterPlatform.instance
        .createViewer(uberarchivePath: uberArchivePath);
    _appLifecycleListener = AppLifecycleListener(
      onStateChange: _handleStateChange,
    );
    _viewer!.onDispose(() async {
      _viewer = null;
      _appLifecycleListener?.dispose();
      _appLifecycleListener = null;
    });
    _initializing = false;
    return _viewer!;
  }

  static Future<ThermionViewer> createViewerWithOptions(
      {ThermionFlutterOptions options = const ThermionFlutterOptions.empty()}) async {
    if (_initializing) {
      throw Exception("Existing call to createViewer has not completed.");
    }
    _initializing = true;
    _viewer =
        await ThermionFlutterPlatform.instance.createViewerWithOptions(options);
    _appLifecycleListener = AppLifecycleListener(
      onStateChange: _handleStateChange,
    );
    _viewer!.onDispose(() async {
      _viewer = null;
      _appLifecycleListener?.dispose();
      _appLifecycleListener = null;
    });
    _initializing = false;
    return _viewer!;
  }

  static Future<ThermionFlutterTexture?> createTexture(
      double width,
      double height,
      double offsetLeft,
      double offsetTop,
      double pixelRatio) async {
    return ThermionFlutterPlatform.instance
        .createTexture(width, height, offsetLeft, offsetTop, pixelRatio);
  }

  static Future destroyTexture(ThermionFlutterTexture texture) async {
    return ThermionFlutterPlatform.instance.destroyTexture(texture);
  }

  static Future<ThermionFlutterTexture?> resizeTexture(
      ThermionFlutterTexture texture,
      int width,
      int height,
      int offsetLeft,
      int offsetTop,
      double pixelRatio) async {
    return ThermionFlutterPlatform.instance.resizeTexture(
        texture, width, height, offsetLeft, offsetTop, pixelRatio);
  }
}

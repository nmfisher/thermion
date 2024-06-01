import 'dart:async';
import 'dart:ui';
import 'package:dart_filament/dart_filament/abstract_filament_viewer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament_platform_interface/flutter_filament_platform_interface.dart';
import 'package:flutter_filament_platform_interface/flutter_filament_texture.dart';

///
/// A Flutter-only class that instantiates/wraps a [AbstractFilamentViewer],
/// handling all platform-specific initialization work necessary to create a 
/// backing rendering surface.
///
class FlutterFilamentPlugin {
  bool _wasRenderingOnInactive = false;

  void _handleStateChange(AppLifecycleState state) async {
    await initialized;
    switch (state) {
      case AppLifecycleState.detached:
        print("Detached");
        if (!_wasRenderingOnInactive) {
          _wasRenderingOnInactive = viewer.rendering;
        }
        await viewer.setRendering(false);
        break;
      case AppLifecycleState.hidden:
        print("Hidden");
        if (!_wasRenderingOnInactive) {
          _wasRenderingOnInactive = viewer.rendering;
        }
        await viewer.setRendering(false);
        break;
      case AppLifecycleState.inactive:
        print("Inactive");
        if (!_wasRenderingOnInactive) {
          _wasRenderingOnInactive = viewer.rendering;
        }
        // on Windows in particular, restoring a window after minimizing stalls the renderer (and the whole application) for a considerable length of time.
        // disabling rendering on minimize seems to fix the issue (so I wonder if there's some kind of command buffer that's filling up while the window is minimized).
        await viewer.setRendering(false);
        break;
      case AppLifecycleState.paused:
        print("Paused");
        if (!_wasRenderingOnInactive) {
          _wasRenderingOnInactive = viewer.rendering;
        }
        await viewer.setRendering(false);
        break;
      case AppLifecycleState.resumed:
        print("Resumed");
        await viewer.setRendering(_wasRenderingOnInactive);
        break;
    }
  }

  AppLifecycleListener? _appLifecycleListener;

  AbstractFilamentViewer get viewer => FlutterFilamentPlatform.instance.viewer;

  final _initialized = Completer<bool>();
  Future<bool> get initialized => _initialized.future;

  Future initialize({String? uberArchivePath}) async {
    if (_initialized.isCompleted) {
      throw Exception("Instance already initialized");
    }
    await FlutterFilamentPlatform.instance
        .initialize(uberArchivePath: uberArchivePath);

    _appLifecycleListener = AppLifecycleListener(
      onStateChange: _handleStateChange,
    );
    _initialized.complete(true);

    await viewer.initialized;
  }

  Future<FlutterFilamentTexture?> createTexture(
      int width, int height, int offsetLeft, int offsetRight) async {
    return FlutterFilamentPlatform.instance
        .createTexture(width, height, offsetLeft, offsetRight);
  }

  Future destroyTexture(FlutterFilamentTexture texture) async {
    return FlutterFilamentPlatform.instance.destroyTexture(texture);
  }

  @override
  Future<FlutterFilamentTexture?> resizeTexture(FlutterFilamentTexture texture,
      int width, int height, int offsetLeft, int offsetRight) async {
    return FlutterFilamentPlatform.instance
        .resizeTexture(texture, width, height, offsetLeft, offsetRight);
  }

  void dispose() {
    FlutterFilamentPlatform.instance.dispose();
    _appLifecycleListener?.dispose();
  }
}

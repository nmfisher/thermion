import 'dart:async';
import 'package:flutter/services.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_flutter_ffi/src/thermion_flutter_method_channel_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';
import 'package:logging/logging.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_window.dart';

///
/// A Windows-only implementation of [ThermionFlutterPlatform] that uses
/// a Flutter platform channel to create a rendering context,
/// resource loader and a native HWND that will be sit behind the running 
/// Flutter application.
///
class ThermionFlutterWindows
    extends ThermionFlutterMethodChannelInterface {
  
  final _channel = const MethodChannel("dev.thermion.flutter/event");

  final _logger = Logger("ThermionFlutterWindows");

  ThermionViewer? _viewer;

  SwapChain? _swapChain;

  ThermionFlutterWindows._() {}

  static void registerWith() {
    ThermionFlutterPlatform.instance = ThermionFlutterWindows._();
  }

  @override
  Future<ThermionViewer> createViewer({ThermionFlutterOptions? options}) async {
    if(_viewer != null) {
      throw Exception("Only one viewer should be instantiated over the life of the app");
    }
    _viewer = await super.createViewer(options: options);
    _viewer!.onDispose(() async {
      _viewer = null;
    });
    return _viewer!;
  }

  ///
  /// Not supported on Windows. Throws an exception.
  ///
  @override
  Future<ThermionFlutterTexture?> createTexture(View view, int width, int height) {
    throw UnimplementedError();
  }

  
  @override
  Future<ThermionFlutterWindow> createWindow(int width, int height, int offsetLeft, int offsetTop) async {

    var result = await _channel
        .invokeMethod("createWindow", [width, height, offsetLeft, offsetLeft]);

    if (result == null || result[2] == -1) {
      throw Exception("Failed to create window");
    }

    var window =
        ThermionFlutterWindowImpl(result[2], _channel, viewer!);
    await window.resize(width, height, offsetLeft, offsetTop);
    var view = await _viewer!.getViewAt(0);
    
    await view.updateViewport(width, height);
    _swapChain = await _viewer!.createSwapChain(window.handle);    
    await view.setRenderable(true, _swapChain!);
    return window;
  }
  
  
}

class ThermionFlutterWindowImpl extends ThermionFlutterWindow {

  final ThermionViewer viewer;
  final int handle;
  int height = 0;
  int width = 0;
  int offsetLeft = 0;
  int offsetTop = 0;
  final MethodChannel _channel;
  
  ThermionFlutterWindowImpl(this.handle, this._channel, this.viewer);

  @override
  Future destroy() async {
      await _channel
        .invokeMethod("destroyWindow", this.handle);
  }

  @override
  Future markFrameAvailable() {
    // TODO: implement markFrameAvailable
    throw UnimplementedError();
  }

  bool _resizing = false;
  
  ///
  /// Called by [ThermionWidget] to resize the window. Don't call this yourself.
  ///
  @override
  Future resize(
      int width, int height, int offsetLeft, int offsetTop) async {
    if (_resizing) {
      throw Exception("Resize underway");
    }

    if (width == this.width && height == this.height && this.offsetLeft == offsetLeft && this.offsetTop == offsetTop) {
      return;
    }

    this.width = width;
    this.height = height;
    this.offsetLeft = offsetLeft;
    this.offsetTop = offsetTop;

    _resizing = true;

    await _channel
        .invokeMethod("resizeWindow", [width, height, offsetLeft, offsetTop]);
    _resizing = false;
  }

  
}
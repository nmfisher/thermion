import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:ffi';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/viewer/src/ffi/thermion_viewer_ffi.dart';
import 'package:thermion_flutter_ffi/thermion_flutter_method_channel_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';
import 'package:logging/logging.dart';

///
/// An implementation of [ThermionFlutterPlatform] that uses
/// Flutter platform channels to create a rendering context,
/// resource loaders, and surface/render target(s).
///
class ThermionFlutterWindows
    extends ThermionFlutterMethodChannelInterface {
  final _channel = const MethodChannel("dev.thermion.flutter/event");

  final _logger = Logger("ThermionFlutterWindows");

  ThermionViewerFFI? _viewer;

  ThermionFlutterWindows._() {}

  SwapChain? _swapChain;

  static void registerWith() {
    ThermionFlutterPlatform.instance = ThermionFlutterWindows._();
  }

  ///
  /// Not supported on Windows. Throws an exception.
  ///
  Future<ThermionFlutterTexture?> createTexture(int width, int height) async {
    throw Exception("Texture not supported on Windows");
  }

  bool _resizing = false;

  ///
  /// Called by [ThermionWidget] to resize a texture. Don't call this yourself.
  ///
  @override
  Future resizeWindow(
      int width, int height, int offsetLeft, int offsetTop) async {
    if (_resizing) {
      throw Exception("Resize underway");
    }

    throw Exception("TODO");

    // final view = await this._viewer!.getViewAt(0);
    // final viewport = await view.getViewport();
    // final swapChain = await this._viewer.getSwapChainAt(0);

    // if (width == viewport.width && height - viewport.height == 0) {
    //   return;
    // }

    // _resizing = true;
    // bool wasRendering = _viewer!.rendering;
    // await _viewer!.setRendering(false);
    // await _swapChain?.destroy();

    // var result = await _channel
    //     .invokeMethod("createTexture", [width, height, offsetLeft, offsetLeft]);

    // if (result == null || result[0] == -1) {
    //   throw Exception("Failed to create texture");
    // }

    // var newTexture =
    //     ThermionFlutterTexture(result[0], result[1], width, height, result[2]);

    // await _viewer!.createSwapChain(width, height,
    //     surface: newTexture.surfaceAddress == null
    //         ? nullptr
    //         : Pointer<Void>.fromAddress(newTexture.surfaceAddress!));

    // if (newTexture.hardwareTextureId != null) {
    //   // ignore: unused_local_variable
    //   var renderTarget = await _viewer!
    //       .createRenderTarget(width, height, newTexture.hardwareTextureId!);
    // }

    // await _viewer!
    //     .updateViewportAndCameraProjection(width.toDouble(), height.toDouble());

    // if (wasRendering) {
    //   await _viewer!.setRendering(true);
    // }
    // _textures.add(newTexture);
    // _resizing = false;
    // return newTexture;
  }
}

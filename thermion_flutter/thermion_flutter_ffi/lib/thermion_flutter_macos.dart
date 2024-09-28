import 'dart:async';
import 'package:flutter/services.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_flutter_ffi/thermion_flutter_method_channel_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';
import 'package:logging/logging.dart';

///
/// An implementation of [ThermionFlutterPlatform] that uses
/// Flutter platform channels to create a rendering context,
/// resource loaders, and surface/render target(s).
///
class ThermionFlutterMacOS extends ThermionFlutterMethodChannelInterface {
  final _channel = const MethodChannel("dev.thermion.flutter/event");
  final _logger = Logger("ThermionFlutterFFI");

  SwapChain? _swapChain;

  ThermionFlutterMacOS._() {}

  static void registerWith() {
    ThermionFlutterPlatform.instance = ThermionFlutterMacOS._();
  }

  // On desktop platforms, textures are always created
  Future<ThermionFlutterTexture?> createTexture(int width, int height) async {
    if (_swapChain == null) {
      // this is the headless swap chain
      // since we will be using render targets, the actual dimensions don't matter
      _swapChain = await viewer!.createSwapChain(width, height);
    }
    // Get screen width and height
    int screenWidth = width; //1920;
    int screenHeight = height; //1080;

    if (width > screenWidth || height > screenHeight) {
      throw Exception("TODO - unsupported");
    }

    var result = await _channel
        .invokeMethod("createTexture", [screenWidth, screenHeight, 0, 0]);

    if (result == null || (result[0] == -1)) {
      throw Exception("Failed to create texture");
    }
    final flutterTextureId = result[0] as int?;
    final hardwareTextureId = result[1] as int?;
    final surfaceAddress = result[2] as int?;
    

    _logger.info(
        "Created texture with flutter texture id ${flutterTextureId}, hardwareTextureId $hardwareTextureId and surfaceAddress $surfaceAddress");

    return MacOSMethodChannelFlutterTexture(_channel, flutterTextureId!,
        hardwareTextureId!, screenWidth, screenHeight);
  }

  // On MacOS, we currently use textures/render targets, so there's no window to resize
  @override
  Future<ThermionFlutterTexture?> resizeWindow(
      int width, int height, int offsetTop, int offsetRight) {
    throw UnimplementedError();
  }
}

class MacOSMethodChannelFlutterTexture extends MethodChannelFlutterTexture {
  MacOSMethodChannelFlutterTexture(super.channel, super.flutterId,
      super.hardwareId, super.width, super.height);

  @override
  Future resize(int width, int height, int left, int top) async {
    if (width > this.width || height > this.height || left != 0 || top != 0) {
      throw Exception();
    }
  }
}

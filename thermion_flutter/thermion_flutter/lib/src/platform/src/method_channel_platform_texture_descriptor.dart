import 'package:flutter/services.dart';

import 'platform_texture_descriptor.dart';

class MethodChannelPlatformTextureDescriptor extends PlatformTextureDescriptor {
  final MethodChannel channel;

  MethodChannelPlatformTextureDescriptor(this.channel,
      {required super.flutterTextureId,
      required super.hardwareId,
      required super.windowHandle,
      required super.width,
      required super.height});

  @override
  Future destroy() async {
    destroyed = true;
    await channel.invokeMethod("destroyTexture", flutterTextureId);
  }

  @override
  void markTextureFrameAvailable() async {
    if (destroyed) return;
    await channel.invokeMethod(
      "markTextureFrameAvailable",
      flutterTextureId,
    );
  }

  static Future<MethodChannelPlatformTextureDescriptor> allocate(
      MethodChannel channel, int width, int height) async {
    final result = await channel.invokeMethod("createTexture", [
      width,
      height,
      0,
      0,
    ]);
    if (result == null || (result[0] == -1)) {
      throw Exception("Failed to create texture");
    }
    final flutterTextureId = result[0] as int;
    final hardwareTextureId = result[1] as int;
    final windowHandle = result[2] as int?; // usually 0 for nullptr
    return MethodChannelPlatformTextureDescriptor(channel,
        flutterTextureId: flutterTextureId,
        hardwareId: hardwareTextureId,
        windowHandle: windowHandle,
        width: width,
        height: height);
  }

  /// Waits for populate() to create the GL texture (deferred path).
  /// Returns the hardware texture ID once ready.
  Future<int> awaitTextureReady() async {
    final result =
        await channel.invokeMethod("awaitTextureReady", flutterTextureId);
    return result as int;
  }

  bool destroyed = false;
}

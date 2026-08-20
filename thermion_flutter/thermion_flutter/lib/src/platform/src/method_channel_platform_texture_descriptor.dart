import 'package:flutter/services.dart';

import 'platform_texture_descriptor.dart';

class MethodChannelPlatformTextureDescriptor extends PlatformTextureDescriptor {
  final MethodChannel channel;

  MethodChannelPlatformTextureDescriptor(
    this.channel, {
    required super.flutterTextureId,
    required super.hardwareId,
    required super.windowHandle,
    required super.width,
    required super.height,
    bool deferred = false,
  }) : _deferred = deferred;

  @override
  Future<void> destroy() async {
    if (_destroyed) return;
    _destroyed = true;
    await channel.invokeMethod("destroyTexture", flutterTextureId);
  }

  @override
  void markTextureFrameAvailable() async {
    if (destroyed) {
      throw Exception(
        "markTextureFrameAvailable cannot be called on a "
        "destroyed texture descriptor.",
      );
    }
    await channel.invokeMethod("markTextureFrameAvailable", flutterTextureId);
  }

  static Future<MethodChannelPlatformTextureDescriptor> allocate(
    MethodChannel channel,
    int width,
    int height, {
    bool deferred = false,
  }) async {
    final allocation = await allocateMethodChannelTexture(
      channel,
      width,
      height,
    );
    return MethodChannelPlatformTextureDescriptor(
      channel,
      flutterTextureId: allocation.flutterTextureId,
      hardwareId: allocation.hardwareTextureId,
      windowHandle: allocation.windowHandle,
      width: width,
      height: height,
      deferred: deferred,
    );
  }

  /// Registers a Flutter texture whose GL name is allocated by Flutter's
  /// raster context during the first populate callback.
  ///
  /// This allocation deliberately bypasses the normal native texture creation
  /// path because Filament's OpenGL context does not exist yet.
  static Future<MethodChannelPlatformTextureDescriptor>
  allocateContextBootstrap(MethodChannel channel, int width, int height) async {
    final flutterTextureId = await channel.invokeMethod<int>(
      'createContextBootstrap',
      [width, height],
    );
    if (flutterTextureId == null || flutterTextureId < 0) {
      throw StateError('Failed to create Flutter context bootstrap texture');
    }
    return MethodChannelPlatformTextureDescriptor(
      channel,
      flutterTextureId: flutterTextureId,
      hardwareId: 0,
      windowHandle: 0,
      width: width,
      height: height,
      deferred: true,
    );
  }

  /// Waits for populate() to create the GL texture (deferred path).
  /// Returns the hardware texture ID once ready.
  @override
  Future<int> awaitTextureReady() async {
    final result = await channel.invokeMethod(
      "awaitTextureReady",
      flutterTextureId,
    );
    return result as int;
  }

  @override
  bool get deferred => _deferred;

  @override
  bool get destroyed => _destroyed;

  final bool _deferred;
  bool _destroyed = false;
}

typedef MethodChannelTextureAllocation = ({
  int flutterTextureId,
  int hardwareTextureId,
  int? windowHandle,
});

Future<MethodChannelTextureAllocation> allocateMethodChannelTexture(
  MethodChannel channel,
  int width,
  int height, {
  List<Object?> additionalArguments = const [],
}) async {
  final result = await channel.invokeMethod("createTexture", [
    width,
    height,
    0,
    0,
    ...additionalArguments,
  ]);
  if (result == null || (result[0] == -1)) {
    throw Exception("Failed to create texture");
  }
  final flutterTextureId = result[0] as int;
  final hardwareTextureId = result[1] as int;
  final windowHandle = result[2] as int?; // usually 0 for nullptr
  return (
    flutterTextureId: flutterTextureId,
    hardwareTextureId: hardwareTextureId,
    windowHandle: windowHandle,
  );
}

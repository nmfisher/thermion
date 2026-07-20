import 'package:flutter/services.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'method_channel_platform_texture_descriptor.dart';

/// Describes an Android SurfaceProducer texture and its native window.
class AndroidPlatformTextureDescriptor
    extends MethodChannelPlatformTextureDescriptor {
  AndroidPlatformTextureDescriptor(
    super.channel, {
    required super.flutterTextureId,
    required super.hardwareId,
    required super.windowHandle,
    required super.width,
    required super.height,
  });

  _AndroidPlatformTextureBinding? _binding;

  @override
  View? get boundView => _binding?.view;

  /// Android gets its SurfaceProducer surface synchronously, so it is not
  /// deferred despite extending the (Linux-oriented) method-channel base.
  @override
  bool get deferred => false;

  static Future<AndroidPlatformTextureDescriptor> allocate(
    MethodChannel channel,
    int width,
    int height,
  ) async {
    final allocation = await allocateMethodChannelTexture(
      channel,
      width,
      height,
    );
    final windowHandle = allocation.windowHandle;
    if (windowHandle == null || windowHandle == 0) {
      throw StateError('Android texture has no native window');
    }
    return AndroidPlatformTextureDescriptor(
      channel,
      flutterTextureId: allocation.flutterTextureId,
      hardwareId: allocation.hardwareTextureId,
      windowHandle: windowHandle,
      width: width,
      height: height,
    );
  }

  @override
  Future<bool> bindToView(View view) async {
    final replacement = _AndroidPlatformTextureBinding(this, view);
    await replacement.bind();

    final previous = _binding;
    _binding = replacement;
    await previous?.release();
    return true;
  }

  @override
  Future<void> releaseBinding() async {
    final binding = _binding;
    _binding = null;
    await binding?.release();
  }
}

class _AndroidPlatformTextureBinding {
  _AndroidPlatformTextureBinding(this.descriptor, this.view);

  final AndroidPlatformTextureDescriptor descriptor;
  final View view;

  SwapChain? _swapChain;

  Future<void> bind() async {
    if (descriptor.destroyed) {
      throw StateError('Cannot bind a destroyed texture descriptor');
    }
    final windowHandle = descriptor.windowHandle;
    if (windowHandle == null || windowHandle == 0) {
      throw StateError('Android texture has no native window');
    }

    final app = FilamentApp.instance;
    if (app == null) {
      throw StateError('Cannot bind a surface after Filament shutdown');
    }

    final swapChain = await app.createSwapChain(
      Pointer<Void>.fromAddress(windowHandle),
    );
    await app.renderManager.attach(view, swapChain);
    _swapChain = swapChain;
  }

  Future<void> release() async {
    final swapChain = _swapChain;
    _swapChain = null;
    final app = FilamentApp.instance;
    if (swapChain != null && app != null) {
      await app.destroySwapChain(swapChain);
    }
  }
}

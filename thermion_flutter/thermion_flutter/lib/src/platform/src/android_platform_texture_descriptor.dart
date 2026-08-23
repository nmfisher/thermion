import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_flutter/src/options.dart';

import 'method_channel_platform_texture_descriptor.dart';
import 'platform_texture_descriptor.dart';

/// Describes an Android texture-registry surface and its native window.
class AndroidPlatformTextureDescriptor
    extends MethodChannelPlatformTextureDescriptor
    with ReplaceablePlatformTextureDescriptorMixin {
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

  /// Android's texture-registry surfaces publish queued buffers without an
  /// explicit method-channel notification. The old call only acknowledged the
  /// texture ID, adding one platform message per frame without changing
  /// presentation state.
  @override
  Future<void> markTextureFrameAvailable() => Future<void>.value();

  static Future<AndroidPlatformTextureDescriptor> allocate(
    MethodChannel channel,
    int width,
    int height,
    AndroidTextureSource textureSource,
  ) async {
    final allocation = await allocateMethodChannelTexture(
      channel,
      width,
      height,
      additionalArguments: [
        textureSource == AndroidTextureSource.surfaceProducer,
      ],
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

  @override
  Future<void> cleanupSurface() async {
    await _binding?.onSurfaceCleanup();
  }

  @override
  Future<void> restoreSurface(int nativeWindowHandle) async {
    updateSurfaceHandle(nativeWindowHandle);
    await _binding?.onSurfaceAvailable(nativeWindowHandle);
    markSurfaceRestored();
  }

  @override
  Future<void> destroy() async {
    if (destroyed) return;
    markSurfaceError();
    await releaseBinding();
    await super.destroy();
  }
}

class _AndroidPlatformTextureBinding {
  _AndroidPlatformTextureBinding(this.descriptor, this.view);

  final AndroidPlatformTextureDescriptor descriptor;
  final View view;

  static final _logger = Logger('AndroidPlatformTextureBinding');

  SwapChain? _swapChain;

  Future<void> bind() => _replaceSwapChain();

  Future<void> onSurfaceCleanup() async {
    // The plugin pauses the frame scheduler before invoking cleanup, so the
    // render loop is already drained by the time we reach here.
    await release();
    _logger.info(
      'Released swapchain for Android texture '
      '${descriptor.flutterTextureId}',
    );
  }

  Future<void> onSurfaceAvailable(int nativeWindowHandle) async {
    await _replaceSwapChain(nativeWindowHandle);
    _logger.info(
      'Recreated swapchain for Android texture '
      '${descriptor.flutterTextureId}',
    );
  }

  /// Creates and attaches the replacement [SwapChain] for [view] *before*
  /// destroying the previous one, so there is never a frame with no swap
  /// chain attached (which would render into a freed surface). On failure to
  /// attach, the replacement is destroyed and the previous chain is left
  /// attached.
  Future<void> _replaceSwapChain([int? nativeWindowHandle]) async {
    if (descriptor.destroyed) {
      throw StateError('Cannot bind a destroyed texture descriptor');
    }
    final windowHandle = nativeWindowHandle ?? descriptor.windowHandle;
    if (windowHandle == null || windowHandle == 0) {
      throw StateError('Android texture has no native window');
    }

    final app = FilamentApp.instance;
    if (app == null) {
      throw StateError('Cannot bind a surface after Filament shutdown');
    }

    final previous = _swapChain;
    final replacement = await app.createSwapChain(
      Pointer<Void>.fromAddress(windowHandle),
    );
    try {
      await app.renderManager.attach(view, replacement);
    } catch (error, stackTrace) {
      // attach failed — destroy the orphaned replacement so it doesn't leak,
      // leaving any previous swapchain still attached, then rethrow.
      await app.destroySwapChain(replacement);
      Error.throwWithStackTrace(error, stackTrace);
    }
    _swapChain = replacement;

    if (previous != null) {
      await app.destroySwapChain(previous);
    }
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

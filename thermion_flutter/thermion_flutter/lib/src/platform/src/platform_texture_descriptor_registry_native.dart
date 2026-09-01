import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_flutter/src/options.dart';

import 'android_platform_texture_descriptor.dart';
import 'darwin_platform_texture_descriptor.dart';
import 'method_channel_platform_texture_descriptor.dart';
import 'platform_texture_descriptor.dart';
import 'platform_texture_descriptor_registry.dart';

typedef TextureMutationRunner =
    Future<T> Function<T>(Future<T> Function() operation);

class FilamentRenderingContext {
  const FilamentRenderingContext({
    required this.driverPlatform,
    required this.platform,
    required this.sharedContext,
    required this.sharedContextPointer,
  });

  final int? driverPlatform;
  final Pointer<Void> platform;
  final int? sharedContext;
  final Pointer<Void> sharedContextPointer;
}

/// Native registry implementation backed by Thermion's platform method
/// channel. Android surface callbacks are handled here because they mutate
/// descriptors owned by this registry.
class NativePlatformTextureDescriptorRegistry
    extends PlatformTextureDescriptorRegistry {
  NativePlatformTextureDescriptorRegistry({
    required void Function() pauseRendering,
    required void Function() resumeRenderingIfReady,
    required TextureMutationRunner runTextureMutation,
    required AndroidTextureSource Function() androidTextureSource,
    required bool Function() flipLinuxTextureVertically,
  }) : _pauseRendering = pauseRendering,
       _resumeRenderingIfReady = resumeRenderingIfReady,
       _runTextureMutation = runTextureMutation,
       super(
         allocator: (width, height) => _allocate(
           width,
           height,
           androidTextureSource(),
           flipLinuxTextureVertically(),
         ),
       ) {
    if (Platform.isAndroid) {
      channel.setMethodCallHandler(_handlePlatformMethodCall);
    }
  }

  static const channel = MethodChannel('dev.thermion.flutter/event');

  final void Function() _pauseRendering;
  final void Function() _resumeRenderingIfReady;
  final TextureMutationRunner _runTextureMutation;
  final Logger _logger = Logger('NativePlatformTextureDescriptorRegistry');

  static Future<PlatformTextureDescriptor> _allocate(
    int width,
    int height,
    AndroidTextureSource androidTextureSource,
    bool flipLinuxTextureVertically,
  ) {
    if (Platform.isMacOS || Platform.isIOS) {
      return Future.value(
        DarwinPlatformTextureDescriptorImpl.allocate(width, height),
      );
    }
    if (Platform.isAndroid) {
      return AndroidPlatformTextureDescriptor.allocate(
        channel,
        width,
        height,
        androidTextureSource,
      );
    }
    if (Platform.isWindows) {
      return MethodChannelPlatformTextureDescriptor.allocate(
        channel,
        width,
        height,
      );
    }
    if (Platform.isLinux) {
      return MethodChannelPlatformTextureDescriptor.allocate(
        channel,
        width,
        height,
        deferred: true,
        flipVertically: flipLinuxTextureVertically,
      );
    }
    throw UnsupportedError('Platform textures are not supported on $Platform');
  }

  Future<FilamentRenderingContext> getFilamentRenderingContext(
    Backend backend,
  ) async {
    if (Platform.isMacOS || Platform.isIOS) {
      return FilamentRenderingContext(
        driverPlatform: null,
        platform: nullptr,
        sharedContext: null,
        sharedContextPointer: nullptr,
      );
    }

    final driverPlatform = await channel.invokeMethod<int>(
      'getDriverPlatform',
      backend.index,
    );
    final sharedContext = await channel.invokeMethod<int>(
      'getSharedContext',
      backend.index,
    );
    return FilamentRenderingContext(
      driverPlatform: driverPlatform,
      platform: driverPlatform == null
          ? nullptr
          : VoidPointerClass.fromAddress(driverPlatform),
      sharedContext: sharedContext,
      sharedContextPointer: sharedContext == null
          ? nullptr
          : VoidPointerClass.fromAddress(sharedContext),
    );
  }

  Future<void> destroyFilamentRenderingContext() async {
    if (Platform.isWindows || Platform.isLinux) {
      await channel.invokeMethod<void>('destroyContext');
    }
  }

  Future<int> resizeWindowsTexture(
    PlatformTextureDescriptor descriptor,
    int width,
    int height,
  ) async {
    final result = await channel.invokeMethod<List<Object?>>('resizeTexture', [
      descriptor.flutterTextureId,
      width,
      height,
    ]);
    if (result == null || result.isEmpty) {
      throw StateError('Native texture resize returned no external image');
    }
    return result.first as int;
  }

  Future<void> cancelWindowsTextureResize(
    PlatformTextureDescriptor descriptor,
  ) {
    return channel.invokeMethod<void>(
      'cancelResizeTexture',
      descriptor.flutterTextureId,
    );
  }

  PlatformTextureDescriptor? _descriptorForTextureId(int textureId) {
    for (final descriptor in descriptors) {
      if (descriptor.flutterTextureId == textureId) {
        return descriptor;
      }
    }
    return null;
  }

  Future<Object?> _handlePlatformMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSurfaceCleanup':
        final descriptor = _descriptorForTextureId(call.arguments as int);
        if (descriptor == null) return null;
        descriptor.markSurfaceUnavailable();
        _pauseRendering();
        try {
          await serialized(() async {
            if (contains(descriptor)) {
              await _runTextureMutation(descriptor.cleanupSurface);
            }
          });
        } finally {
          _resumeRenderingIfReady();
        }
        return null;
      case 'onSurfaceAvailable':
        final arguments = call.arguments as List<Object?>;
        final textureId = arguments[0] as int;
        final descriptor = _descriptorForTextureId(textureId);
        if (descriptor == null) return null;
        descriptor.markSurfaceUnavailable();
        _pauseRendering();
        try {
          await serialized(() async {
            if (!contains(descriptor)) return;
            await _runTextureMutation(
              () => descriptor.restoreSurface(arguments[1] as int),
            );
          });
        } catch (error, stackTrace) {
          _logger.severe(
            'Failed to restore texture surface $textureId',
            error,
            stackTrace,
          );
          rethrow;
        } finally {
          _resumeRenderingIfReady();
        }
        return null;
      case 'onSurfaceError':
        final arguments = call.arguments as List<Object?>;
        final textureId = arguments[0] as int;
        final descriptor = _descriptorForTextureId(textureId);
        if (descriptor == null) return null;
        descriptor.markSurfaceError();
        _pauseRendering();
        _logger.severe(
          'Surface recovery failed for texture $textureId: ${arguments[1]}',
        );
        return null;
      default:
        throw MissingPluginException(
          'Unknown platform callback ${call.method}',
        );
    }
  }
}

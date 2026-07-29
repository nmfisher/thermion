import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_flutter/src/options.dart';

import 'native_rendering_lifecycle_controller.dart';
import 'platform_texture_descriptor.dart';
import 'platform_texture_descriptor_registry_native.dart';

@visibleForTesting
bool shouldDeferNativeTextureBinding({
  required bool managesFilamentSurface,
  required int hardwareId,
  required bool supportsDeferredBinding,
}) {
  return !managesFilamentSurface && hardwareId == 0 && supportsDeferredBinding;
}

/// Owns native platform texture descriptors and their Filament resources.
///
/// Allocation, view binding, resize, deferred cleanup, and destruction stay in
/// one place so imported platform memory always outlives the Filament render
/// target that refers to it.
class NativeTextureSurfaceManager {
  NativeTextureSurfaceManager({
    required NativeRenderingLifecycleController lifecycle,
    required NativeOptions Function() options,
  }) : _lifecycle = lifecycle,
       _options = options,
       registry = NativePlatformTextureDescriptorRegistry(
         pauseRendering: lifecycle.pauseRendering,
         resumeRenderingIfReady: lifecycle.resumeRenderingIfReady,
         runTextureMutation: lifecycle.duringTextureMutation,
       );

  static final _logger = Logger('NativeTextureSurfaceManager');

  final NativeRenderingLifecycleController _lifecycle;
  final NativeOptions Function() _options;
  final NativePlatformTextureDescriptorRegistry registry;

  // The view can be redirected to an internal target in composite highlight
  // mode, so track the Flutter-facing render target independently.
  final _viewRenderTargets = <View, RenderTarget>{};

  // Windows keeps old render targets alive briefly while the native side
  // blits into a pending replacement image.
  final _deferredRenderTargets = <(RenderTarget, int)>[];

  bool get hasUnavailableSurfaces => registry.hasUnavailableSurfaces;

  Future<FilamentRenderingContext> getFilamentRenderingContext(
    Backend backend,
  ) {
    return registry.getFilamentRenderingContext(backend);
  }

  Future<void> destroyFilamentRenderingContext() {
    return registry.destroyFilamentRenderingContext();
  }

  /// Releases references whose native resources are owned by a dying engine.
  void onEngineDestroyed() {
    registry.clear();
    _viewRenderTargets.clear();
    _deferredRenderTargets.clear();
  }

  /// Notifies live descriptors and reaps render targets deferred by Windows
  /// resize operations.
  Future<void> onFrameRendered() async {
    registry.markFrameAvailable();

    if (_deferredRenderTargets.isEmpty) return;

    final ready = <RenderTarget>[];
    final remaining = <(RenderTarget, int)>[];
    for (final (renderTarget, frames) in _deferredRenderTargets) {
      if (frames <= 0) {
        ready.add(renderTarget);
      } else {
        remaining.add((renderTarget, frames - 1));
      }
    }
    _deferredRenderTargets
      ..clear()
      ..addAll(remaining);

    for (final renderTarget in ready) {
      await _destroyRenderTarget(renderTarget);
    }
  }

  Future<PlatformTextureDescriptor> createAndBind(
    View view,
    int width,
    int height,
  ) {
    return registry.serialized(() => _createAndBind(view, width, height));
  }

  Future<PlatformTextureDescriptor> _createAndBind(
    View view,
    int width,
    int height,
  ) async {
    if (width == 0 || height == 0) {
      throw ArgumentError(
        'Invalid dimensions for texture descriptor: ${width}x$height',
      );
    }

    final descriptor = await registry.create(width, height);
    try {
      final managesFilamentSurface = await registry.bindToView(
        descriptor,
        view,
      );

      // Prefer a hardware handle returned by native allocation. In particular,
      // Linux Vulkan returns an ExternalVulkanImage pointer here; replacing it
      // with awaitTextureReady's Flutter-side GL texture ID is invalid.
      if (!managesFilamentSurface && descriptor.hardwareId != 0) {
        await _createFilamentResources(descriptor, view, width, height);
      } else if (shouldDeferNativeTextureBinding(
        managesFilamentSurface: managesFilamentSurface,
        hardwareId: descriptor.hardwareId,
        supportsDeferredBinding: descriptor.deferred,
      )) {
        // Some Linux EGL/OpenGL paths can only publish the hardware texture
        // from Flutter's populate callback, after the Texture widget exists.
        unawaited(_completeDeferredBinding(descriptor, view, width, height));
      } else if (!managesFilamentSurface) {
        throw StateError(
          'Platform texture did not provide a hardware handle and does not '
          'support deferred binding',
        );
      }

      await view.setViewport(width, height);
      return descriptor;
    } catch (error, stackTrace) {
      await _destroyAfterBindingFailure(descriptor);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _completeDeferredBinding(
    PlatformTextureDescriptor descriptor,
    View view,
    int width,
    int height,
  ) async {
    try {
      final hardwareId = await descriptor.awaitTextureReady();
      await registry.serialized(() async {
        if (!registry.contains(descriptor) || descriptor.destroyed) return;
        descriptor.hardwareId = hardwareId;
        _logger.info(
          'Deferred texture ready: flutter=${descriptor.flutterTextureId} '
          'hardware=$hardwareId',
        );
        await _createFilamentResources(descriptor, view, width, height);
      });
    } catch (error, stackTrace) {
      _logger.warning('Deferred texture binding failed', error, stackTrace);
      try {
        await registry.serialized(() async {
          if (registry.contains(descriptor)) {
            await registry.destroy(descriptor);
          }
        });
      } catch (cleanupError, cleanupStackTrace) {
        _logger.warning(
          'Failed to clean up deferred texture descriptor',
          cleanupError,
          cleanupStackTrace,
        );
      }
    }
  }

  Future<void> _destroyAfterBindingFailure(
    PlatformTextureDescriptor descriptor,
  ) async {
    try {
      await registry.destroy(descriptor);
    } catch (cleanupError, cleanupStackTrace) {
      _logger.warning(
        'Failed to clean up texture descriptor after binding failure',
        cleanupError,
        cleanupStackTrace,
      );
    }
  }

  Future<void> _createFilamentResources(
    PlatformTextureDescriptor descriptor,
    View view,
    int width,
    int height,
  ) async {
    final options = _options();
    final useExternalImage =
        Platform.isWindows || options.backend == Backend.VULKAN;
    final app = FilamentApp.instance;
    if (app == null) {
      throw StateError('Cannot bind a texture after Filament shutdown');
    }

    final color = await app.createTexture(
      width,
      height,
      importedTextureHandle: useExternalImage ? -1 : descriptor.hardwareId,
      flags: {
        TextureUsage.TEXTURE_USAGE_BLIT_SRC,
        TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
        TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
      },
      textureFormat: options.renderTargetColorTextureFormat,
      textureSamplerType: TextureSamplerType.SAMPLER_2D,
    );

    if (useExternalImage) {
      await app.setExternalImage(color, descriptor.hardwareId);
    }

    final depth = await app.createTexture(
      width,
      height,
      flags: {
        TextureUsage.TEXTURE_USAGE_BLIT_SRC,
        TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT,
        TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
        TextureUsage.TEXTURE_USAGE_STENCIL_ATTACHMENT,
      },
      textureFormat: options.renderTargetDepthTextureFormat,
      textureSamplerType: TextureSamplerType.SAMPLER_2D,
    );

    final existingRenderTarget = _viewRenderTargets[view];
    final renderTarget = await app.createRenderTarget(
      width,
      height,
      color: color,
      depth: depth,
    );

    await view.setRenderTarget(renderTarget);
    _viewRenderTargets[view] = renderTarget;

    if (existingRenderTarget != null) {
      await _destroyRenderTarget(existingRenderTarget);
    }

    final swapChains = await app.getSwapChains();
    await app.renderManager.attach(view, swapChains.first);
  }

  Future<PlatformTextureDescriptor> resize(
    PlatformTextureDescriptor texture,
    View view,
    int width,
    int height,
  ) {
    return registry.serialized(
      () => _lifecycle.duringTextureMutation(
        () => _resize(texture, view, width, height),
      ),
    );
  }

  Future<PlatformTextureDescriptor> _resize(
    PlatformTextureDescriptor texture,
    View view,
    int width,
    int height,
  ) async {
    if (Platform.isWindows) {
      return _resizeWindows(texture, view, width, height);
    }

    final newTexture = await _createAndBind(view, width, height);
    await registry.destroy(texture);
    return newTexture;
  }

  Future<PlatformTextureDescriptor> _resizeWindows(
    PlatformTextureDescriptor texture,
    View view,
    int width,
    int height,
  ) async {
    final externalImage = await registry.resizeWindowsTexture(
      texture,
      width,
      height,
    );
    final app = FilamentApp.instance;
    if (app == null) {
      throw StateError('Cannot resize a texture after Filament shutdown');
    }
    final options = _options();

    final color = await app.createTexture(
      width,
      height,
      importedTextureHandle: -1,
      flags: {
        TextureUsage.TEXTURE_USAGE_BLIT_SRC,
        TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
        TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
      },
      textureFormat: options.renderTargetColorTextureFormat,
      textureSamplerType: TextureSamplerType.SAMPLER_2D,
    );
    await app.setExternalImage(color, externalImage);

    final depth = await app.createTexture(
      width,
      height,
      flags: {
        TextureUsage.TEXTURE_USAGE_BLIT_SRC,
        TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT,
        TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
        TextureUsage.TEXTURE_USAGE_STENCIL_ATTACHMENT,
      },
      textureFormat: options.renderTargetDepthTextureFormat,
      textureSamplerType: TextureSamplerType.SAMPLER_2D,
    );

    final existingRenderTarget = _viewRenderTargets[view];
    final renderTarget = await app.createRenderTarget(
      width,
      height,
      color: color,
      depth: depth,
    );

    await view.setRenderTarget(renderTarget);
    _viewRenderTargets[view] = renderTarget;

    if (existingRenderTarget != null) {
      _deferredRenderTargets.add((existingRenderTarget, 5));
    }

    final swapChains = await app.getSwapChains();
    await app.renderManager.attach(view, swapChains.first);
    await view.setViewport(width, height);

    texture.hardwareId = externalImage;
    texture.width = width;
    texture.height = height;
    return texture;
  }

  Future<void> releaseView(View view) {
    return registry.serialized(
      () => _lifecycle.duringTextureMutation(() async {
        await registry.releaseBindingsForView(view);
        await _destroyRenderTargetForView(view);
      }),
    );
  }

  Future<void> _destroyRenderTargetForView(View view) async {
    final renderTarget = _viewRenderTargets.remove(view);
    if (renderTarget == null) return;

    final app = FilamentApp.instance;
    if (app == null) {
      // The engine owns resources that survived until shutdown.
      return;
    }

    final overlay = view.getHighlightOverlay();
    if (overlay == null) {
      await view.setRenderTarget(null);
    } else {
      await overlay.overlayView.setRenderTarget(null);
    }
    await _destroyRenderTarget(renderTarget);
  }

  Future<void> _destroyRenderTarget(RenderTarget renderTarget) async {
    final color = await renderTarget.getColorTexture();
    final depth = await renderTarget.getDepthTexture();
    await renderTarget.destroy();
    await color.destroy();
    await depth.destroy();
  }
}

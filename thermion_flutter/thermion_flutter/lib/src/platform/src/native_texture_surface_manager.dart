import 'dart:async';
import 'dart:ffi' as ffi;
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

/// Destroys a render target before the textures it references.
///
/// Exposed for regression tests because reversing this order can free imported
/// platform memory while Filament still retains it through the render target.
@visibleForTesting
Future<void> destroyRenderTargetResourcesInOrder({
  required Future<void> Function()? destroyRenderTarget,
  required Future<void> Function()? destroyColorTexture,
  required Future<void> Function()? destroyDepthTexture,
}) async {
  await destroyRenderTarget?.call();
  await destroyColorTexture?.call();
  await destroyDepthTexture?.call();
}

class _FilamentResourceRollbackFailure implements Exception {
  const _FilamentResourceRollbackFailure(this.cause);

  final Object cause;

  @override
  String toString() =>
      'Could not safely roll back partially-created Filament resources: '
      '$cause';
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
         androidTextureSource: () => options().androidTextureSource,
       );

  static final _logger = Logger('NativeTextureSurfaceManager');

  final NativeRenderingLifecycleController _lifecycle;
  final NativeOptions Function() _options;
  final NativePlatformTextureDescriptorRegistry registry;

  /// Linux can notify every registered external texture with one direct FFI
  /// call. Keep this presentation detail here, after the common Dart render
  /// future completes, rather than coupling it to frame scheduling.
  late final void Function()? _markLinuxTextures = Platform.isLinux
      ? _createLinuxTextureMarker()
      : null;

  // The view can be redirected to an internal target in composite highlight
  // mode, so track the Flutter-facing render target independently.
  final _viewRenderTargets = <View, RenderTarget>{};

  // Windows keeps old render targets alive briefly while the native side
  // blits into a pending replacement image.
  final _deferredRenderTargets = <(RenderTarget, int)>[];

  // A Linux descriptor may need to enter the widget tree before populate()
  // can publish its hardware texture. Staged resize waits on this future
  // before rendering the replacement's first visible frame.
  final _replacementBindings = <PlatformTextureDescriptor, Future<void>>{};

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
    _replacementBindings.clear();
  }

  /// Notifies live descriptors and reaps render targets deferred by Windows
  /// resize operations.
  Future<void> onFrameRendered() async {
    final markLinuxTextures = _markLinuxTextures;
    if (markLinuxTextures != null) {
      markLinuxTextures();
    } else {
      registry.markFrameAvailable();
    }

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

  static void Function() _createLinuxTextureMarker() {
    final dylib = ffi.DynamicLibrary.process();
    final getPluginHandle = dylib
        .lookupFunction<
          ffi.Pointer<ffi.Void> Function(),
          ffi.Pointer<ffi.Void> Function()
        >('thermion_flutter_get_plugin_handle');
    final markTextures = dylib
        .lookupFunction<
          ffi.Void Function(ffi.Pointer<ffi.Void>),
          void Function(ffi.Pointer<ffi.Void>)
        >('thermion_flutter_mark_textures');

    return () => markTextures(getPluginHandle());
  }

  Future<PlatformTextureDescriptor> createAndBind(
    View view,
    int width,
    int height,
  ) {
    return registry.serialized(
      () => _lifecycle.duringTextureMutation(
        () => _createAndBind(view, width, height),
      ),
    );
  }

  Future<PlatformTextureDescriptor> _createAndBind(
    View view,
    int width,
    int height, {
    PlatformTextureDescriptor? destroyAfterDeferredBinding,
    bool preserveExistingBindings = false,
    Completer<void>? bindingReady,
  }) async {
    if (width == 0 || height == 0) {
      throw ArgumentError(
        'Invalid dimensions for texture descriptor: ${width}x$height',
      );
    }

    final previousBindings = registry.descriptors
        .where((descriptor) => descriptor.boundView == view)
        .toList();
    final descriptor = await registry.create(width, height);
    try {
      // Complete the only fallible view mutation shared by descriptor-managed
      // surfaces before replacing their existing binding.
      await view.setViewport(width, height);

      final mayRequireDeferredBinding =
          descriptor.hardwareId == 0 && descriptor.deferred;
      final managesFilamentSurface = await registry.bindToView(
        descriptor,
        view,
        // Keep the previous descriptor associated with this view until the
        // deferred replacement has a Filament target. Teardown can then find
        // and destroy both descriptors if the widget unmounts while waiting.
        releaseExistingBindings:
            !mayRequireDeferredBinding && !preserveExistingBindings,
      );

      // Prefer a hardware handle returned by native allocation. In particular,
      // Linux Vulkan returns an ExternalVulkanImage pointer here; replacing it
      // with awaitTextureReady's Flutter-side GL texture ID is invalid.
      if (!managesFilamentSurface && descriptor.hardwareId != 0) {
        await _createFilamentResources(descriptor, view, width, height);
        if (!(bindingReady?.isCompleted ?? true)) bindingReady!.complete();
      } else if (shouldDeferNativeTextureBinding(
        managesFilamentSurface: managesFilamentSurface,
        hardwareId: descriptor.hardwareId,
        supportsDeferredBinding: descriptor.deferred,
      )) {
        // Some Linux EGL/OpenGL paths can only publish the hardware texture
        // from Flutter's populate callback, after the Texture widget exists.
        unawaited(
          _completeDeferredBinding(
            descriptor,
            view,
            width,
            height,
            destroyAfterBinding: destroyAfterDeferredBinding,
            bindingReady: bindingReady,
          ),
        );
      } else if (!managesFilamentSurface) {
        throw StateError(
          'Platform texture did not provide a hardware handle and does not '
          'support deferred binding',
        );
      }

      if (managesFilamentSurface && !(bindingReady?.isCompleted ?? true)) {
        bindingReady!.complete();
      }

      return descriptor;
    } catch (error, stackTrace) {
      if (!(bindingReady?.isCompleted ?? true)) {
        bindingReady!.completeError(error, stackTrace);
      }
      if (error is _FilamentResourceRollbackFailure) {
        // The descriptor's platform memory must outlive the Filament objects
        // that could not be destroyed. Detach it from the view but deliberately
        // keep both the descriptor and its native allocation alive.
        await descriptor.releaseBinding();
        _logger.severe(error);
      } else {
        await _destroyAfterBindingFailure(descriptor);
      }
      await _restoreBindingsAfterFailure(previousBindings, view);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _completeDeferredBinding(
    PlatformTextureDescriptor descriptor,
    View view,
    int width,
    int height, {
    PlatformTextureDescriptor? destroyAfterBinding,
    Completer<void>? bindingReady,
  }) async {
    try {
      final hardwareId = await descriptor.awaitTextureReady();
      await registry.serialized(() async {
        if (!registry.contains(descriptor) || descriptor.destroyed) return;
        await _lifecycle.duringTextureMutation(() async {
          if (!registry.contains(descriptor) || descriptor.destroyed) return;
          descriptor.hardwareId = hardwareId;
          _logger.info(
            'Deferred texture ready: flutter=${descriptor.flutterTextureId} '
            'hardware=$hardwareId',
          );
          await _createFilamentResources(descriptor, view, width, height);
          if (destroyAfterBinding != null &&
              registry.contains(destroyAfterBinding)) {
            await registry.destroy(destroyAfterBinding);
          }
          if (!(bindingReady?.isCompleted ?? true)) bindingReady!.complete();
        });
      });
    } catch (error, stackTrace) {
      if (!(bindingReady?.isCompleted ?? true)) {
        bindingReady!.completeError(error, stackTrace);
      }
      _logger.warning('Deferred texture binding failed', error, stackTrace);
      if (error is _FilamentResourceRollbackFailure) {
        // Keep the platform allocation alive for any Filament object whose
        // rollback failed. It remains registry-owned until engine shutdown.
        await registry.serialized(descriptor.releaseBinding);
        _logger.severe(error);
        return;
      }
      try {
        await registry.serialized(() async {
          if (registry.contains(descriptor)) {
            await _lifecycle.duringTextureMutation(
              () => registry.destroy(descriptor),
            );
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

  Future<void> _restoreBindingsAfterFailure(
    List<PlatformTextureDescriptor> descriptors,
    View view,
  ) async {
    for (final descriptor in descriptors) {
      if (!registry.contains(descriptor) || descriptor.destroyed) continue;
      try {
        await registry.bindToView(descriptor, view);
      } catch (error, stackTrace) {
        _logger.warning(
          'Failed to restore the previous texture binding',
          error,
          stackTrace,
        );
      }
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

    final existingRenderTarget = _viewRenderTargets[view];
    Texture? color;
    Texture? depth;
    RenderTarget? renderTarget;
    try {
      color = await app.createTexture(
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

      depth = await app.createTexture(
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

      renderTarget = await app.createRenderTarget(
        width,
        height,
        color: color,
        depth: depth,
      );

      // Do every operation that can reject the replacement before publishing
      // it in _viewRenderTargets or destroying the previous target.
      final swapChains = await app.getSwapChains();
      await app.renderManager.attach(view, swapChains.first);
      await view.setPresentationRenderTarget(renderTarget);
    } catch (error, stackTrace) {
      final rolledBack = await _destroyCreatedRenderTarget(
        renderTarget: renderTarget,
        color: color,
        depth: depth,
      );
      if (!rolledBack) {
        throw _FilamentResourceRollbackFailure(error);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    _viewRenderTargets[view] = renderTarget;
    if (existingRenderTarget != null) {
      await _destroyRenderTargetBestEffort(
        existingRenderTarget,
        'replacing a texture render target',
      );
    }
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

    if (!Platform.isMacOS && !Platform.isLinux) {
      final newTexture = await _createAndBind(
        view,
        width,
        height,
        destroyAfterDeferredBinding: texture,
      );
      if (!shouldDeferNativeTextureBinding(
        managesFilamentSurface: false,
        hardwareId: newTexture.hardwareId,
        supportsDeferredBinding: newTexture.deferred,
      )) {
        await registry.destroy(texture);
      }
      return newTexture;
    }

    final bindingReady = Completer<void>();
    final newTexture = await _createAndBind(
      view,
      width,
      height,
      preserveExistingBindings: true,
      bindingReady: bindingReady,
    );
    _replacementBindings[newTexture] = bindingReady.future;
    return newTexture;
  }

  /// Waits for deferred platform binding, then renders the replacement once
  /// while the scheduler is paused. The widget continues to cover this
  /// texture with the previous descriptor until this future completes.
  Future<void> prepareForPresentation(PlatformTextureDescriptor texture) async {
    final binding = _replacementBindings[texture];
    if (binding == null) return;
    await binding;

    await registry.serialized(
      () => _lifecycle.duringTextureMutation(() async {
        if (!registry.contains(texture) || texture.destroyed) return;
        final app = FilamentApp.instance;
        if (app == null) {
          throw StateError('Cannot prime a texture after Filament shutdown');
        }
        await app.render();
        await texture.markTextureFrameAvailable();
      }),
    );
  }

  /// The old descriptor remains registered until the first Flutter frame
  /// containing its replacement has completed.
  Future<void> retireAfterResize(PlatformTextureDescriptor texture) {
    return registry.serialized(() async {
      _replacementBindings.remove(texture);
      if (registry.contains(texture)) {
        await registry.destroy(texture);
      }
    });
  }

  /// Rebinds the last visible descriptor if preparing its replacement fails.
  Future<void> cancelStagedResize(
    PlatformTextureDescriptor replacement,
    PlatformTextureDescriptor previous,
    View view,
  ) {
    return registry.serialized(
      () => _lifecycle.duringTextureMutation(() async {
        _replacementBindings.remove(replacement);
        if (!registry.contains(previous) || previous.destroyed) return;

        await registry.bindToView(previous, view);
        await view.setViewport(previous.width, previous.height);
        await _createFilamentResources(
          previous,
          view,
          previous.width,
          previous.height,
        );
        if (registry.contains(replacement)) {
          await registry.destroy(replacement);
        }
      }),
    );
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
    final existingRenderTarget = _viewRenderTargets[view];
    Texture? color;
    Texture? depth;
    RenderTarget? renderTarget;
    try {
      final app = FilamentApp.instance;
      if (app == null) {
        throw StateError('Cannot resize a texture after Filament shutdown');
      }
      final options = _options();

      color = await app.createTexture(
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

      depth = await app.createTexture(
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

      renderTarget = await app.createRenderTarget(
        width,
        height,
        color: color,
        depth: depth,
      );

      final swapChains = await app.getSwapChains();
      await app.renderManager.attach(view, swapChains.first);
      await view.setViewport(width, height);
      await view.setPresentationRenderTarget(renderTarget);
    } catch (error, stackTrace) {
      await _destroyCreatedRenderTarget(
        renderTarget: renderTarget,
        color: color,
        depth: depth,
      );
      try {
        await registry.cancelWindowsTextureResize(texture);
      } catch (cleanupError, cleanupStackTrace) {
        _logger.severe(
          'Failed to cancel native Windows texture resize',
          cleanupError,
          cleanupStackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    _viewRenderTargets[view] = renderTarget;
    if (existingRenderTarget != null) {
      _deferredRenderTargets.add((existingRenderTarget, 5));
    }

    texture.hardwareId = externalImage;
    texture.width = width;
    texture.height = height;
    return texture;
  }

  Future<void> destroyForView(View view) {
    return registry.serialized(
      () => _lifecycle.duringTextureMutation(() async {
        await registry.destroyBindingsForView(
          view,
          beforeDescriptorDestroy: () => _destroyRenderTargetForView(view),
        );
        _replacementBindings.removeWhere(
          (descriptor, _) =>
              descriptor.boundView == view || descriptor.destroyed,
        );
      }),
    );
  }

  Future<void> _destroyRenderTargetForView(View view) async {
    final renderTarget = _viewRenderTargets[view];
    if (renderTarget == null) return;

    final app = FilamentApp.instance;
    if (app == null) {
      // The engine owns resources that survived until shutdown.
      _viewRenderTargets.remove(view);
      return;
    }

    await view.setPresentationRenderTarget(null);
    await _destroyRenderTarget(renderTarget);
    if (identical(_viewRenderTargets[view], renderTarget)) {
      _viewRenderTargets.remove(view);
    }
  }

  Future<void> _destroyRenderTarget(RenderTarget renderTarget) async {
    final color = await renderTarget.getColorTexture();
    final depth = await renderTarget.getDepthTexture();
    await destroyRenderTargetResourcesInOrder(
      destroyRenderTarget: renderTarget.destroy,
      destroyColorTexture: color.destroy,
      destroyDepthTexture: depth.destroy,
    );
  }

  Future<bool> _destroyCreatedRenderTarget({
    required RenderTarget? renderTarget,
    required Texture? color,
    required Texture? depth,
  }) async {
    try {
      await destroyRenderTargetResourcesInOrder(
        destroyRenderTarget: renderTarget?.destroy,
        destroyColorTexture: color?.destroy,
        destroyDepthTexture: depth?.destroy,
      );
      return true;
    } catch (error, stackTrace) {
      _logger.warning(
        'Failed to roll back partially-created Filament resources',
        error,
        stackTrace,
      );
      return false;
    }
  }

  Future<void> _destroyRenderTargetBestEffort(
    RenderTarget renderTarget,
    String operation,
  ) async {
    try {
      await _destroyRenderTarget(renderTarget);
    } catch (error, stackTrace) {
      // The replacement is already committed. Do not tear it back down because
      // cleanup of the superseded target failed; retain the old resources and
      // keep the new surface usable.
      _logger.warning(
        'Failed while $operation; retaining superseded resources',
        error,
        stackTrace,
      );
    }
  }
}

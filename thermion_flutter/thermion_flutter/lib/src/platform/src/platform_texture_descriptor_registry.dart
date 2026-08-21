import 'dart:async';

import 'package:logging/logging.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'platform_texture_descriptor.dart';

typedef PlatformTextureDescriptorAllocator =
    FutureOr<PlatformTextureDescriptor> Function(int width, int height);

/// Owns the platform texture descriptors created by a plugin implementation.
///
/// Platform-specific allocation and callbacks live in subclasses. This class
/// keeps the common lifecycle rules in one place: texture operations are
/// serialized, frame notifications only target live descriptors, and a view
/// never retains more than one descriptor binding.
class PlatformTextureDescriptorRegistry {
  PlatformTextureDescriptorRegistry({
    required PlatformTextureDescriptorAllocator allocator,
  }) : _allocator = allocator;

  final PlatformTextureDescriptorAllocator _allocator;
  final List<PlatformTextureDescriptor> _descriptors = [];
  final Logger _logger = Logger('PlatformTextureDescriptorRegistry');

  Future<void> _operationChain = Future<void>.value();

  Iterable<PlatformTextureDescriptor> get descriptors =>
      List<PlatformTextureDescriptor>.unmodifiable(_descriptors);

  bool get hasUnavailableSurfaces =>
      _descriptors.any((descriptor) => !descriptor.isSurfaceAvailable);

  bool contains(PlatformTextureDescriptor descriptor) =>
      _descriptors.any((candidate) => identical(candidate, descriptor));

  Future<PlatformTextureDescriptor> create(int width, int height) async {
    final descriptor = await _allocator(width, height);
    _descriptors.add(descriptor);
    return descriptor;
  }

  /// Binds [descriptor] to [view] and releases any older binding for the same
  /// view. The return value is true when the descriptor itself supplies the
  /// Filament surface (Android); false means the plugin must create a render
  /// target backed by [PlatformTextureDescriptor.hardwareId].
  Future<bool> bindToView(
    PlatformTextureDescriptor descriptor,
    View view, {
    bool releaseExistingBindings = true,
  }) async {
    if (!contains(descriptor)) {
      throw StateError('Cannot bind an unregistered texture descriptor');
    }

    final managesFilamentSurface = await descriptor.bindToView(view);
    if (releaseExistingBindings) {
      for (final other in List<PlatformTextureDescriptor>.of(_descriptors)) {
        if (!identical(other, descriptor) && other.boundView == view) {
          await other.releaseBinding();
        }
      }
    }
    return managesFilamentSurface;
  }

  /// Stops tracking [descriptor], releases its view binding, and destroys its
  /// platform texture. Descriptor destruction is required to be idempotent.
  Future<void> destroy(PlatformTextureDescriptor descriptor) async {
    _remove(descriptor);
    await descriptor.releaseBinding();
    await descriptor.destroy();
  }

  /// Releases and forgets descriptors bound to [view].
  ///
  /// The caller may destroy the returned descriptors after any other
  /// view-owned resources have been torn down.
  Future<List<PlatformTextureDescriptor>> releaseBindingsForView(
    View view,
  ) async {
    final released = _descriptors
        .where((descriptor) => descriptor.boundView == view)
        .toList();
    for (final descriptor in released) {
      await descriptor.releaseBinding();
      _remove(descriptor);
    }
    return released;
  }

  /// Releases every descriptor bound to [view], runs
  /// [beforeDescriptorDestroy], then destroys the released descriptors.
  ///
  /// The callback is where a native owner tears down Filament render targets.
  /// Keeping descriptor destruction here makes the required dependency order
  /// explicit:
  ///
  /// 1. detach descriptor-managed surfaces such as Android swapchains;
  /// 2. destroy Filament objects that reference platform memory;
  /// 3. release the underlying platform textures.
  Future<void> destroyBindingsForView(
    View view, {
    FutureOr<void> Function()? beforeDescriptorDestroy,
  }) async {
    final released = _descriptors
        .where((descriptor) => descriptor.boundView == view)
        .toList();
    for (final descriptor in released) {
      await descriptor.releaseBinding();
    }

    try {
      await beforeDescriptorDestroy?.call();
    } catch (error, stackTrace) {
      // Keep the descriptors owned and recover their view association so a
      // caller can retry teardown. Android also recreates its swapchain here;
      // the platform surface is deliberately still alive.
      for (final descriptor in released) {
        if (!descriptor.destroyed) {
          try {
            await descriptor.bindToView(view);
          } catch (_) {
            // Preserve the teardown error. The descriptor remains tracked even
            // if restoring a platform binding is itself unsuccessful.
          }
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    Object? firstError;
    StackTrace? firstStackTrace;
    for (final descriptor in released) {
      try {
        await descriptor.destroy();
        _remove(descriptor);
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }

  void markFrameAvailable() {
    final destroyed = _descriptors
        .where((descriptor) => descriptor.destroyed)
        .toList();
    for (final descriptor in destroyed) {
      _remove(descriptor);
      _logger.info(
        'Removed descriptor (hardware ID ${descriptor.hardwareId}, '
        'flutter ID ${descriptor.flutterTextureId})',
      );
    }

    for (final descriptor in List<PlatformTextureDescriptor>.of(_descriptors)) {
      descriptor.markTextureFrameAvailable();
    }
  }

  void clear() {
    _descriptors.clear();
  }

  void _remove(PlatformTextureDescriptor descriptor) {
    _descriptors.removeWhere((candidate) => identical(candidate, descriptor));
  }

  /// Runs [operation] after all previously submitted texture operations.
  ///
  /// A failure is reported to its caller without poisoning the chain, so later
  /// operations can still run.
  Future<R> serialized<R>(Future<R> Function() operation) {
    final completer = Completer<R>();
    _operationChain = _operationChain.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

import 'dart:io';

import 'package:thermion_flutter/src/swift/swift_bindings.g.dart';

import 'platform_texture_descriptor.dart';

/// Whether Flutter's Darwin texture registry reported a failed registration.
///
/// macOS returns zero when registration fails. iOS also uses zero, but as the
/// first valid texture ID because its registry returns `nextTextureId++`.
bool didDarwinTextureRegistrationFail({
  required bool isIOS,
  required int textureId,
}) {
  return !isIOS && textureId == 0;
}

class DarwinTextureRegistration {
  DarwinTextureRegistration({
    required this.texture,
    required this.adapter,
    required this.flutterTextureId,
  });

  final MetalTextureWrapper texture;
  final FlutterMetalTextureWrapper adapter;
  final int flutterTextureId;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    DarwinPlatformTextureDescriptorImpl._textureRegistry.unregisterTexture_(
      flutterTextureId,
    );
    adapter.ref.release();
    texture.flushCache();
    texture.ref.release();
  }
}

/// Keeps one released macOS texture registration available for the next
/// descriptor with matching dimensions.
///
/// Flutter's macOS external-texture path can retain substantial Metal driver
/// allocations for every distinct registered IOSurface it sees. Reusing the
/// registered producer prevents repeated widget mount/unmount cycles from
/// continually introducing new external textures. Filament resources are
/// still recreated and destroyed normally.
class DarwinPlatformTexturePool {
  DarwinPlatformTexturePool({this.capacity = 1});

  final int capacity;
  final List<DarwinTextureRegistration> _registrations = [];
  bool _disposed = false;

  DarwinTextureRegistration? take(int width, int height) {
    if (_disposed) return null;
    final index = _registrations.indexWhere(
      (registration) =>
          registration.texture.width == width &&
          registration.texture.height == height,
    );
    if (index == -1) return null;
    return _registrations.removeAt(index);
  }

  void recycle(DarwinTextureRegistration registration) {
    registration.texture.flushCache();
    if (_disposed || capacity <= 0) {
      registration.dispose();
      return;
    }

    _registrations.add(registration);
    while (_registrations.length > capacity) {
      _registrations.removeAt(0).dispose();
    }
  }

  void clear() {
    _disposed = true;
    for (final registration in _registrations) {
      registration.dispose();
    }
    _registrations.clear();
  }
}

/// [DarwinPlatformTextureDescriptorImpl] now handles the Metal platform texture
/// allocation/lifecycle that was previously handled by
/// [SwiftThermionFlutterPlugin]. The latter now exists only
/// to capture/pass FlutterTextureRegistry to this class.
///
/// This class will now:
///   - allocate the [MetalTextureWrapper] (CVPixelBuffer + CVMetalTexture +
///     MTLTexture),
///   - wraps in a native [FlutterMetalTextureWrapper] (the FlutterTexture
///     adapter whose `copyPixelBuffer` Flutter calls on the raster thread),
///   - registers that adapter with the registry, and
///   - drives `textureFrameAvailable` each frame.
///
/// On macOS, destruction can return the complete registration to a one-entry
/// pool. Eviction or engine teardown performs the eventual unregister.
class DarwinPlatformTextureDescriptorImpl extends PlatformTextureDescriptor {
  final DarwinTextureRegistration _registration;
  final DarwinPlatformTexturePool? _texturePool;

  FlutterMetalTextureWrapper get adapter => _registration.adapter;
  MetalTextureWrapper get texture => _registration.texture;

  bool _destroyed = false;

  @override
  bool get destroyed => _destroyed;

  DarwinPlatformTextureDescriptorImpl(
    this._registration, {
    DarwinPlatformTexturePool? texturePool,
    required super.flutterTextureId,
    required super.hardwareId,
    required super.width,
    required super.height,
  }) : _texturePool = texturePool;

  /// The FlutterTextureRegistry exposed by the plugin
  static ThermionTextureRegistry? _registry;
  static ThermionTextureRegistry get _textureRegistry =>
      _registry ??= ThermionTextureRegistry.castFrom(
        SwiftThermionFlutterPluginObjCAPI.textureRegistry(),
      );

  @override
  Future<void> destroy() async {
    if (_destroyed) {
      return;
    }
    // Set flag early to ensure markTextureFrameAvailable is not called with a
    // destroyed texture handle.
    _destroyed = true;
    final pool = _texturePool;
    if (pool == null) {
      _registration.dispose();
    } else {
      pool.recycle(_registration);
    }
    await releaseBinding();
  }

  @override
  void markTextureFrameAvailable() {
    if (_destroyed) {
      throw Exception(
        "markTextureFrameAvailable cannot be called on a "
        "destroyed texture descriptor.",
      );
    }
    _textureRegistry.textureFrameAvailable_(flutterTextureId);
  }

  @override
  int acquireHardwareIdForImport() {
    final handle = texture.retainMetalTextureForImport();
    if (handle <= 0) {
      throw StateError('Metal texture is unavailable for Filament import');
    }
    return handle;
  }

  @override
  void releaseHardwareIdAfterFailedImport(int acquiredHardwareId) {
    texture.releaseMetalTextureAfterFailedImport_(acquiredHardwareId);
  }

  static DarwinPlatformTextureDescriptorImpl allocate(
    int width,
    int height, {
    DarwinPlatformTexturePool? texturePool,
  }) {
    final pooledRegistration = texturePool?.take(width, height);
    if (pooledRegistration != null) {
      return DarwinPlatformTextureDescriptorImpl(
        pooledRegistration,
        texturePool: texturePool,
        flutterTextureId: pooledRegistration.flutterTextureId,
        hardwareId: pooledRegistration.texture.metalTextureAddress,
        width: width,
        height: height,
      );
    }

    final metalTexture =
        MetalTextureWrapper.allocateWithWidth_height_isDepth_isStencil_(
          width,
          height,
          false,
          false,
        );
    if (metalTexture.metalTextureAddress <= 0) {
      metalTexture.ref.release();
      throw StateError('Failed to allocate a Metal platform texture');
    }

    final adapter = FlutterMetalTextureWrapper.alloc().initWithTexture_(
      metalTexture,
    );
    final flutterTextureId = _textureRegistry.registerTexture_(adapter);
    if (didDarwinTextureRegistrationFail(
      isIOS: Platform.isIOS,
      textureId: flutterTextureId,
    )) {
      adapter.ref.release();
      metalTexture.ref.release();
      throw Exception('Failed to register Flutter texture');
    }
    final registration = DarwinTextureRegistration(
      texture: metalTexture,
      adapter: adapter,
      flutterTextureId: flutterTextureId,
    );

    return DarwinPlatformTextureDescriptorImpl(
      registration,
      texturePool: texturePool,
      flutterTextureId: flutterTextureId,
      hardwareId: metalTexture.metalTextureAddress,
      width: width,
      height: height,
    );
  }
}

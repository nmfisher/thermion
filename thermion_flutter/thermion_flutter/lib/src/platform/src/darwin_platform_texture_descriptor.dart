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
///   - drives `textureFrameAvailable` each frame and `unregisterTexture` on
///     destroy, keeping the adapter alive while registered.
class DarwinPlatformTextureDescriptorImpl extends PlatformTextureDescriptor {
  final FlutterMetalTextureWrapper adapter;
  final MetalTextureWrapper texture;

  bool _destroyed = false;

  @override
  bool get destroyed => _destroyed;

  DarwinPlatformTextureDescriptorImpl(
    this.texture,
    this.adapter, {
    required super.flutterTextureId,
    required super.hardwareId,
    required super.width,
    required super.height,
  });

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
    _textureRegistry.unregisterTexture_(flutterTextureId);

    // Drop our Dart-owned NSObject retains explicitly and deterministically
    // — do NOT rely on Dart GC finalizers to release them. `ref.release()`
    // calls objc_release immediately AND detaches the GC finalizer (with a
    // built-in double-release guard), so the retain the interop layer took on
    // our behalf is balanced the moment destroy() runs, not whenever GC
    // happens to sweep the wrappers.
    //
    // This only removes the Dart-owned retain from the critical path. It does
    // not, by itself, deallocate either object if another owner still holds a
    // strong ref: the adapter is also retained by Flutter's registry until its
    // async unregister completes (onTextureUnregistered), and
    // MetalTextureWrapper is also retained by the adapter's Swift `texture`
    // property. Sequencing those is a separate step; this just makes the
    // Dart-owned half explicit instead of GC-deferred.
    texture.flushCache();
    adapter.ref.release();
    texture.ref.release();
    await releaseBinding();
  }

  @override
  Future<void> markTextureFrameAvailable() {
    if (_destroyed) {
      throw Exception(
        "markTextureFrameAvailable cannot be called on a "
        "destroyed texture descriptor.",
      );
    }
    _textureRegistry.textureFrameAvailable_(flutterTextureId);
    return Future<void>.value();
  }

  static DarwinPlatformTextureDescriptorImpl allocate(int width, int height) {
    final metalTexture =
        MetalTextureWrapper.allocateWithWidth_height_isDepth_isStencil_(
          width,
          height,
          false,
          false,
        );

    final adapter = FlutterMetalTextureWrapper.alloc().initWithTexture_(
      metalTexture,
    );
    final flutterTextureId = _textureRegistry.registerTexture_(adapter);
    if (didDarwinTextureRegistrationFail(
      isIOS: Platform.isIOS,
      textureId: flutterTextureId,
    )) {
      throw Exception('Failed to register Flutter texture');
    }

    return DarwinPlatformTextureDescriptorImpl(
      metalTexture,
      adapter,
      flutterTextureId: flutterTextureId,
      hardwareId: metalTexture.metalTextureAddress,
      width: width,
      height: height,
    );
  }
}

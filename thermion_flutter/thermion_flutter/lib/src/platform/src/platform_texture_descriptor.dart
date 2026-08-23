import 'package:thermion_dart/thermion_dart.dart';

abstract class PlatformTextureDescriptor {
  final int flutterTextureId;

  int hardwareId;

  final int? windowHandle;

  int width;

  int height;

  View? _boundView;

  /// The (possibly null) view this descriptor is bound to
  /// (see [bindToView]).
  View? get boundView => _boundView;

  /// On some platforms, the backing surface may become unavailable (e.g.
  /// when a mobile app is backgrounded). When [isSurfaceAvailable] is false,
  /// this indicates the Thermion framework should re-allocate a surface.
  bool get isSurfaceAvailable => true;

  PlatformTextureDescriptor({
    required this.flutterTextureId,
    required this.hardwareId,
    required this.width,
    required this.height,
    this.windowHandle,
  });

  /// Descriptors are identified by their Flutter texture id. This is stable
  /// reference that maps to the backing native surface/producer.
  @override
  bool operator ==(Object other) =>
      other is PlatformTextureDescriptor &&
      other.flutterTextureId == flutterTextureId;

  @override
  int get hashCode => flutterTextureId.hashCode;

  /// Instructs Flutter that the texture content has been updated.
  ///
  /// The returned future completes after any platform-side publication work,
  /// such as Linux's Vulkan export blit, has finished.
  Future<void> markTextureFrameAvailable();

  /// Schedules this texture for destruction.
  ///
  /// Package code should normally call
  /// `ThermionFlutterPlugin.destroyTextureForView` so any Filament
  /// resource that imports this descriptor's platform memory is destroyed
  /// first. This low-level method exists for descriptor owners and rollback.
  /// Idempotent; it is safe to call this method multiple times on the same
  /// [PlatformTextureDescriptor].
  Future<void> destroy();

  /// Records [view] as this descriptor's [boundView].
  ///
  /// Returns true when the descriptor supplies the Filament rendering surface
  /// itself. When false, the plugin must create a render target backed by
  /// [hardwareId].
  Future<bool> bindToView(View view) async {
    _boundView = view;
    return false;
  }

  Future<void> releaseBinding() async {
    _boundView = null;
  }

  void markSurfaceUnavailable() {}

  Future<void> cleanupSurface() async {}

  Future<void> restoreSurface(int nativeWindowHandle) async {}

  void markSurfaceError() {}

  /// Whether [destroy] has run.
  bool get destroyed => false;

  /// True when the backing GL texture is created asynchronously; callers must
  /// await [awaitTextureReady] before using [hardwareId].
  bool get deferred => false;

  /// Completes with the hardware texture id. Synchronous descriptors resolve
  /// immediately with the current [hardwareId].
  Future<int> awaitTextureReady() async => hardwareId;

  Future Function(Duration timestamp)? onBeginFrame;
}

mixin ReplaceablePlatformTextureDescriptorMixin on PlatformTextureDescriptor {
  bool _isSurfaceAvailable = true;

  @override
  bool get isSurfaceAvailable => _isSurfaceAvailable;

  @override
  void markSurfaceUnavailable() {
    _isSurfaceAvailable = false;
  }

  void updateSurfaceHandle(int nativeWindowHandle) {
    if (nativeWindowHandle == 0) {
      throw ArgumentError.value(
        nativeWindowHandle,
        'nativeWindowHandle',
        'must not be zero',
      );
    }
    _isSurfaceAvailable = false;
  }

  void markSurfaceRestored() {
    _isSurfaceAvailable = true;
  }

  @override
  void markSurfaceError() {
    _isSurfaceAvailable = false;
  }
}

import 'package:thermion_dart/thermion_dart.dart';

abstract class PlatformTextureDescriptor {
  final int flutterTextureId;
  int hardwareId;
  final int? windowHandle;
  int width;
  int height;

  View? get boundView => null;

  PlatformTextureDescriptor({
    required this.flutterTextureId,
    required this.hardwareId,
    required this.width,
    required this.height,
    this.windowHandle,
  });

  /// Descriptors are identified by their Flutter texture id — the stable
  /// reference that maps to the backing native surface/producer.
  @override
  bool operator ==(Object other) =>
      other is PlatformTextureDescriptor &&
      other.flutterTextureId == flutterTextureId;

  @override
  int get hashCode => flutterTextureId.hashCode;

  void markTextureFrameAvailable();
  Future destroy();

  Future<bool> bindToView(View view) async => false;

  Future<void> releaseBinding() async {}

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

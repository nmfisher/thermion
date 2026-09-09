import 'package:thermion_dart/thermion_dart.dart';

abstract class Ktx1Bundle {
  ///
  ///
  ///
  bool isCubemap();

  /// Returns when the texture has been created, before upload data is necessarily
  /// released. Keep this bundle alive until [onTextureUploadComplete] is called.
  /// That callback signals buffer release, including after submission failure;
  /// this Future separately reports creation success or failure.
  /// A failed creation Future alone does not make it safe to destroy the bundle.
  Future<Texture> createTexture({VoidCallback? onTextureUploadComplete, int? textureUploadCompleteRequestId});

  ///
  ///
  ///
  Float32List getSphericalHarmonics();

  /// Immediately frees this bundle and its native data. Repeated calls are harmless.
  ///
  /// The caller must first wait for every queued creation/upload to release its
  /// data, using the callback supplied to [createTexture]. Destroying the bundle
  /// earlier is invalid and can make native code read freed memory.
  /// This method does not wait for uploads or defer deletion.
  ///
  /// Textures created from the bundle are separate resources; call
  /// [Texture.destroy] when each texture is no longer needed.
  Future destroy();
}

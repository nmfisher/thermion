import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/interface/ktx1_bundle.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFIKtx1Bundle extends Ktx1Bundle {
  final Pointer<TKtx1Bundle> pointer;

  FFIKtx1Bundle(this.pointer);

  ///
  ///
  ///
  bool isCubemap() {
    return Ktx1Bundle_isCubemap(pointer);
  }

  ///
  ///
  ///
  Future destroy() async {
    Ktx1Bundle_destroy(pointer);
  }

  ///
  ///
  ///
  Float32List getSphericalHarmonics() {
    var harmonics = Float32List(27);
    Ktx1Bundle_getSphericalHarmonics(pointer, harmonics.address);
    return harmonics;
  }

  ///
  ///
  ///
  static Future<Ktx1Bundle> create(Uint8List data) async {
    var bundle = Ktx1Bundle_create(data.address, data.length);

    if (bundle == nullptr) {
      throw Exception("Failed to decode KTX texture");
    }

    return FFIKtx1Bundle(bundle);
  }

  Future<Texture> createTexture({VoidCallback? onTextureUploadComplete, int? textureUploadCompleteRequestId}) async {
    final texturePtr = await withPointerCallback<TTexture>((cb) {
      Ktx1Reader_createTextureRenderThread(
          (FilamentApp.instance as FFIFilamentApp).engine,
          pointer,
          textureUploadCompleteRequestId ?? 0,
          onTextureUploadComplete ?? nullptr,
          cb);
    });
    return FFITexture(FilamentApp.instance!.engine, texturePtr);
  }
}

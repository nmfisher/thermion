import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/interface/ktx1_bundle.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFIKtx1Bundle extends Ktx1Bundle {
  final Pointer<TKtx1Bundle> pointer;

  final FFIFilamentApp _app;
  bool _destroyed = false;

  void _checkAlive() {
    if (_destroyed) throw StateError("KTX bundle has been destroyed");
  }

  FFIKtx1Bundle(this.pointer, this._app);

  ///
  ///
  ///
  bool isCubemap() {
    _checkAlive();
    return Ktx1Bundle_isCubemap(pointer);
  }

  @override
  Future destroy() async {
    if (_destroyed) return;
    _destroyed = true;
    Ktx1Bundle_destroy(pointer);
  }

  ///
  ///
  ///
  Float32List getSphericalHarmonics() {
    _checkAlive();
    final harmonics = makeFloat32List(27);
    Ktx1Bundle_getSphericalHarmonics(pointer, harmonics.address);
    return harmonics;
  }

  ///
  ///
  ///
  static Future<Ktx1Bundle> create(FFIFilamentApp app, Uint8List data) async {
    var bundle = Ktx1Bundle_create(data.address, data.length);

    if (bundle == nullptr) {
      throw Exception("Failed to decode KTX texture");
    }

    return FFIKtx1Bundle(bundle, app);
  }

  Future<Texture> createTexture({VoidCallback? onTextureUploadComplete, int? textureUploadCompleteRequestId}) async {
    _checkAlive();
    final texturePtr = await withPointerCallback<TTexture>((cb) {
      Ktx1Reader_createTextureRenderThread(
        _app.engine,
        pointer,
        textureUploadCompleteRequestId ?? 0,
        onTextureUploadComplete ?? nullptr,
        cb,
      );
    });
    if (texturePtr == nullptr) throw StateError("Failed to create KTX texture");
    return FFITexture(_app.engine, texturePtr, _app);
  }
}

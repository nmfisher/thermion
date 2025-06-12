import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFIIndirectLight extends IndirectLight {
  final Pointer<TEngine> engine;
  final Pointer<TIndirectLight> pointer;
  final Texture? _irradianceTexture;
  final Texture? _reflectionsTexture;

  FFIIndirectLight._(this.engine, this.pointer, this._irradianceTexture,
      this._reflectionsTexture);

  static Future<FFIIndirectLight> fromIrradianceTexture(
      Texture irradianceTexture,
      {Texture? reflectionsTexture,
      double intensity = 30000}) async {
    final engine = (FilamentApp.instance as FFIFilamentApp).engine;
    var indirectLight = await withPointerCallback<TIndirectLight>((cb) {
      Engine_buildIndirectLightFromIrradianceTextureRenderThread(
          engine,
          (reflectionsTexture as FFITexture?)?.pointer ?? nullptr,
          (irradianceTexture as FFITexture).pointer,
          intensity,
          cb);
    });
    if (indirectLight == nullptr) {
      throw Exception("Failed to create indirect light");
    }
    return FFIIndirectLight._(
        engine, indirectLight, irradianceTexture, reflectionsTexture);
  }

  static Future<FFIIndirectLight> fromIrradianceHarmonics(
      Float32List irradianceHarmonics,
      {Texture? reflectionsTexture,
      double intensity = 30000}) async {
    final engine = (FilamentApp.instance as FFIFilamentApp).engine;

    var indirectLight = await withPointerCallback<TIndirectLight>((cb) {
      Engine_buildIndirectLightFromIrradianceHarmonicsRenderThread(
          engine,
          (reflectionsTexture as FFITexture?)?.pointer ?? nullptr,
          irradianceHarmonics.address,
          intensity,
          cb);
    });
    if (indirectLight == nullptr) {
      throw Exception("Failed to create indirect light");
    }
    return FFIIndirectLight._(engine, indirectLight, null, reflectionsTexture);
  }

  Future rotate(Matrix3 rotation) async {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      //stackPtr = stackSave();
    }

    IndirectLight_setRotation(this.pointer, rotation.storage.address);

    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
      rotation.storage.free();
    }
  }

  Future destroy() async {
    await withVoidCallback(
      (requestId, cb) => Engine_destroyIndirectLightRenderThread(
        engine,
        pointer,
        requestId,
        cb,
      ),
    );

    if (_irradianceTexture != null) {
      await withVoidCallback((requestId, cb) =>
          Engine_destroyTextureRenderThread(engine,
              (_irradianceTexture as FFITexture).pointer, requestId, cb));
    }

    if (_reflectionsTexture != null) {
      await withVoidCallback((requestId, cb) =>
          Engine_destroyTextureRenderThread(engine,
              (_reflectionsTexture as FFITexture).pointer, requestId, cb));
    }
  }
}

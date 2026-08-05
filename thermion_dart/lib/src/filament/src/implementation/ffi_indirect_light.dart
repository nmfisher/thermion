import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';

class FFIIndirectLight extends IndirectLight {
  final Pointer<TEngine> engine;
  final Pointer<TIndirectLight> pointer;
  final Texture? _irradianceTexture;
  final Texture? _reflectionsTexture;

  final FFIFilamentApp _app;

  FFIIndirectLight._(
    this.engine,
    this.pointer,
    this._irradianceTexture,
    this._reflectionsTexture,
    this._app,
  );

  static Future<FFIIndirectLight> fromIrradianceTexture(
    FFIFilamentApp app,
    Texture irradianceTexture, {
    Texture? reflectionsTexture,
    double intensity = 30000,
  }) async {
    final engine = app.engine;
    var indirectLight = await withPointerCallback<TIndirectLight>((cb) {
      Engine_buildIndirectLightFromIrradianceTextureRenderThread(
        engine,
        reflectionsTexture?.getNativeHandle() ?? nullptr,
        irradianceTexture.getNativeHandle(),
        intensity,
        cb,
      );
    });
    if (indirectLight == nullptr) {
      throw Exception("Failed to create indirect light");
    }
    return FFIIndirectLight._(
      engine,
      indirectLight,
      irradianceTexture,
      reflectionsTexture,
      app,
    );
  }

  static Future<FFIIndirectLight> fromIrradianceHarmonics(
    FFIFilamentApp app,
    Float32List irradianceHarmonics, {
    Texture? reflectionsTexture,
    double intensity = 30000,
  }) async {
    final engine = app.engine;

    var indirectLight = await withPointerCallback<TIndirectLight>((cb) {
      Engine_buildIndirectLightFromIrradianceHarmonicsRenderThread(
        engine,
        (reflectionsTexture as FFITexture?)?.pointer ?? nullptr,
        irradianceHarmonics.address,
        intensity,
        cb,
      );
    });
    if (indirectLight == nullptr) {
      throw Exception("Failed to create indirect light");
    }
    return FFIIndirectLight._(
      engine,
      indirectLight,
      null,
      reflectionsTexture,
      app,
    );
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

    if (_irradianceTexture != null || _reflectionsTexture != null) {
      // The indirect light references these textures. Engine destruction is
      // queued, so drain it before releasing the referenced textures.
      await _app.flush();
    }

    if (_irradianceTexture != null) {
      await withVoidCallback(
        (requestId, cb) => Engine_destroyTextureRenderThread(
          engine,
          _irradianceTexture.getNativeHandle(),
          requestId,
          cb,
        ),
      );
    }

    if (_reflectionsTexture != null &&
        _reflectionsTexture != _irradianceTexture) {
      await withVoidCallback(
        (requestId, cb) => Engine_destroyTextureRenderThread(
          engine,
          _reflectionsTexture.getNativeHandle(),
          requestId,
          cb,
        ),
      );
    }
  }
}

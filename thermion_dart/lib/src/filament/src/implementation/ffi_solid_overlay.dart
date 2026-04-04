import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';

class FFISolidOverlayAsset extends FFIAsset {
  static Material? _material;

  FFISolidOverlayAsset(super.asset);

  static Future<MaterialInstance> _createMaterialInstance({
    double baseR = 0.8,
    double baseG = 0.8,
    double baseB = 0.8,
    double baseA = 1.0,
    double lightDirX = 1.0,
    double lightDirY = 1.0,
    double lightDirZ = 1.0,
    double intensity = 1.0,
  }) async {
    _material ??= FFIMaterial(await withPointerCallback<TMaterial>(
      (callback) => Material_createSolidMaterialRenderThread(
        FilamentApp.instance!.engine,
        callback,
      ),
    ));

    final instance = await _material!.createInstance();

    await instance.setDoubleSided(true);
    await instance.setParameterFloat4(
        "baseColor", baseR, baseG, baseB, baseA);
    await instance.setParameterFloat3(
        "lightDirection", lightDirX, lightDirY, lightDirZ);
    await instance.setParameterFloat("intensity", intensity);

    return instance;
  }

  /// Creates a solid-shaded overlay entity from a loaded glTF asset.
  /// Uses Lambertian diffuse lighting with a configurable light direction.
  static Future<ThermionAsset> createOverlayFromAsset(
    ThermionAsset asset, {
    double baseR = 0.8,
    double baseG = 0.8,
    double baseB = 0.8,
    double baseA = 1.0,
    double lightDirX = 1.0,
    double lightDirY = 1.0,
    double lightDirZ = 1.0,
    double intensity = 1.0,
  }) async {
    final nativeHandle = asset.getNativeHandle();

    final materialInstance = await _createMaterialInstance(
      baseR: baseR,
      baseG: baseG,
      baseB: baseB,
      baseA: baseA,
      lightDirX: lightDirX,
      lightDirY: lightDirY,
      lightDirZ: lightDirZ,
      intensity: intensity,
    );

    final assetPtr =
        await withPointerCallback<TSceneAsset>((callback) {
      SceneAsset_createSolidOverlayRenderThread(
          nativeHandle,
          materialInstance.getNativeHandle(),
          callback);
    });

    if (assetPtr == nullptr) {
      throw Exception('Failed to create solid overlay');
    }

    return FFISolidOverlayAsset(assetPtr);
  }
}

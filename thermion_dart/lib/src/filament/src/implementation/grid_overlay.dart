import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/thermion_dart.dart';

class GridOverlay extends FFIAsset {
  GridOverlay(super.asset, super.app, super.animationManager);

  static GridOverlay? _overlay;
  static Material? _gridMaterial;

  static Future<GridOverlay> create(
      FFIFilamentApp app, Pointer<TAnimationManager> animationManager) async {
    if (_overlay == null) {
      _gridMaterial ??=
          FFIMaterial(Material_createGridMaterial(app.engine), app);

      final asset = await withPointerCallback<TSceneAsset>((cb) =>
          SceneAsset_createGridRenderThread(
              app.engine, _gridMaterial!.getNativeHandle(), cb));

      _overlay = GridOverlay(asset, app, animationManager);
      var materialInstance = await _overlay!.getMaterialInstanceAt();
      await materialInstance
          .setTransparencyMode(TransparencyMode.TWO_PASSES_TWO_SIDES);
      await materialInstance.setCullingMode(CullingMode.NONE);

      await materialInstance.setParameterFloat3("gridColor", 0.3, 0.35, 0.3);

      final ffiAsset =
          FFIAsset(asset, FilamentApp.instance as FFIFilamentApp, nullptr);
      await FilamentApp.instance!.setPriority(ffiAsset.entity, 0);
      for (final child in await ffiAsset.getChildEntities()) {
        await FilamentApp.instance!.setPriority(child, 7);
      }
      // await materialInstance.setParameterFloat("distance", 10.0);
    }
    return _overlay!;
  }

  ///
  ///
  ///
  @override
  Future<FFIAsset> createInstance(
      {List<MaterialInstance>? materialInstances = null}) async {
    throw Exception(
        "Only a single instance of the grid overlay can be created");
  }
}

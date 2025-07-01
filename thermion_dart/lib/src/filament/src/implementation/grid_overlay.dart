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
      _gridMaterial ??= FFIMaterial(Material_createGridMaterial(app.engine), app);
      
      final asset = await withPointerCallback<TSceneAsset>((cb) =>
          SceneAsset_createGridRenderThread(
              app.engine, _gridMaterial!.getNativeHandle(), cb));

      _overlay = GridOverlay(asset, app, animationManager);
      var materialInstance = await _overlay!.getMaterialInstanceAt();
      await materialInstance.setParameterFloat3("gridColor", 0.1, 0.1, 0.1);
    }
    return _overlay!;
  }
}

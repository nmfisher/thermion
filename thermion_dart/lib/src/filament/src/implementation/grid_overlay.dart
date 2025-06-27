import 'package:thermion_dart/src/bindings/bindings.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

class GridOverlay extends FFIAsset {
  
  GridOverlay(super.asset, super.app, super.animationManager);

  static Future<GridOverlay> create(FFIFilamentApp app, Pointer<TAnimationManager> animationManager) async {
    final gridMaterial = await app.gridMaterial;
    final asset = await withPointerCallback<TSceneAsset>((cb) => SceneAsset_createGridRenderThread(app.engine, gridMaterial.pointer, cb));
    return GridOverlay(asset, app, animationManager);
  }
}

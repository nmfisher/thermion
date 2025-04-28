import 'package:thermion_dart/src/bindings/bindings.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_asset.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_filament_app.dart';

class GridOverlay extends FFIAsset {
  
  GridOverlay(super.asset, super.app, super.animationManager);

  static Future<GridOverlay> create(FFIFilamentApp app, Pointer<TAnimationManager> animationManager) async {
    final gridMaterial = await app.gridMaterial;
    final asset = SceneAsset_createGrid(app.engine, gridMaterial.pointer);
    return GridOverlay(asset, app, animationManager);
  }
}

import 'package:thermion_dart/src/viewer/src/ffi/src/callbacks.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_asset.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_filament_app.dart';

class GridOverlay extends FFIAsset {
  GridOverlay(super.asset, super.app);

  static Future<GridOverlay> create(FFIFilamentApp app) async {
    final gridMaterial = await app.gridMaterial;
    final asset = SceneAsset_createGrid(app.engine, gridMaterial.pointer);
    return GridOverlay(asset, app);
  }
}

import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// FFI implementation for creating translation axis material instances.
class FFITranslationAxisMaterial {
  /// Creates a translation axis material instance with the specified configuration.
  ///
  /// This material renders axis lines for translation gizmos.
  /// Colors are hardcoded: X=red, Y=green, Z=blue.
  ///
  /// Parameters:
  /// - [originX], [originY], [originZ]: World-space anchor point
  /// - [axis]: Which axis to render (0=X, 1=Y, 2=Z)
  /// - [lineWidth]: Line width in world units (default 5.0)
  /// - [lineLength]: Half-length of axis line from origin (default 100.0)
  ///
  /// Returns a configured [MaterialInstance] ready to use.
  static Future<MaterialInstance> createTranslationAxisMaterialInstance({
    required FilamentApp app,
    required double originX,
    required double originY,
    required double originZ,
    required int axis,
    double lineWidth = 5.0,
    double lineLength = 100.0,
  }) async {
    // Create translation axis material
    final material = FFIMaterial(
      await withPointerCallback<TMaterial>(
        (callback) => Material_createTranslationAxisMaterialRenderThread(app.engine, callback),
      ),
      app,
    );

    // Create and configure material instance
    final instance = await material.createInstance();
    await instance.setParameterFloat3("origin", originX, originY, originZ);
    await instance.setParameterInt("axis", axis);
    await instance.setParameterFloat("lineWidth", lineWidth);
    await instance.setParameterFloat("lineLength", lineLength);

    return instance;
  }
}

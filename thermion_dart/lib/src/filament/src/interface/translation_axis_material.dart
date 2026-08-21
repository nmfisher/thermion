import 'package:thermion_dart/thermion_dart.dart';

import '../implementation/translation_axis_material.dart';

/// Utility class for creating translation axis material instances.
///
/// The translation axis material renders axis lines for translation gizmos.
/// Each instance renders a single axis line (X, Y, or Z) originating from
/// a specified world-space position. Colors are hardcoded: X=red, Y=green, Z=blue.
class TranslationAxisMaterial {
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
  ///
  /// Example:
  /// ```dart
  /// // Create a red X-axis material at origin
  /// final xAxisMaterial = await TranslationAxisMaterial.createMaterialInstance(
  ///   originX: 0.0,
  ///   originY: 0.0,
  ///   originZ: 0.0,
  ///   axis: 0, // X-axis
  ///   lineWidth: 5.0,
  ///   lineLength: 100.0,
  /// );
  /// ```
  static Future<MaterialInstance> createMaterialInstance({
    FilamentApp? app,
    required double originX,
    required double originY,
    required double originZ,
    required int axis,
    double lineWidth = 5.0,
    double lineLength = 100.0,
  }) {
    return FFITranslationAxisMaterial.createTranslationAxisMaterialInstance(
      app: app ?? FilamentApp.instance!,
      originX: originX,
      originY: originY,
      originZ: originZ,
      axis: axis,
      lineWidth: lineWidth,
      lineLength: lineLength,
    );
  }
}

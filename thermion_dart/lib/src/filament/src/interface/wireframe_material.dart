import 'material.dart';

/// A typed wrapper around a wireframe [MaterialInstance].
///
/// Provides named setters for wireframe-specific parameters so callers don't
/// need to know the underlying uniform names.
///
/// Delegates all calls to the wrapped [MaterialInstance]; does not own it.
class WireframeMaterialInstance {
  final MaterialInstance _mi;

  WireframeMaterialInstance(this._mi);

  /// The underlying [MaterialInstance] for advanced usage.
  MaterialInstance get materialInstance => _mi;

  Future setEdgeColor(double r, double g, double b, double a) =>
      _mi.setParameterFloat4('edgeColor', r, g, b, a);

  Future setFaceColor(double r, double g, double b, double a) =>
      _mi.setParameterFloat4('faceColor', r, g, b, a);

  Future setEdgeWidth(double pixels) =>
      _mi.setParameterFloat('edgeWidth', pixels);

  Future setDoubleSided(bool value) => _mi.setDoubleSided(value);
}

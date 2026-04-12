import 'material.dart';

/// A typed wrapper around a sharp-edge [MaterialInstance].
///
/// Highlights only sharp edges (high dihedral angle) using barycentric
/// coordinates and a precomputed sharp-edge mask. Requires the asset to
/// be loaded with [rebuildVertices: true].
///
/// Delegates all calls to the wrapped [MaterialInstance]; does not own it.
class SharpEdgeMaterialInstance {
  final MaterialInstance _mi;

  SharpEdgeMaterialInstance(this._mi);

  /// The underlying [MaterialInstance] for advanced usage.
  MaterialInstance get materialInstance => _mi;

  Future setEdgeColor(double r, double g, double b, double a) =>
      _mi.setParameterFloat4('edgeColor', r, g, b, a);

  Future setBaseColor(double r, double g, double b, double a) =>
      _mi.setParameterFloat4('baseColor', r, g, b, a);

  /// Width of edge lines in pixels. Default 1.0.
  Future setEdgeWidth(double pixels) =>
      _mi.setParameterFloat('edgeWidth', pixels);

  Future setDoubleSided(bool value) => _mi.setDoubleSided(value);
}

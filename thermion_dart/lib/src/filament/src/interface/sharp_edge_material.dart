import 'material.dart';

/// A typed wrapper around a sharp-edge [MaterialInstance].
///
/// For a triangle with corners A, B, C, set `CUSTOM0.xyz` to (1,0,0),
/// (0,1,0), (0,0,1) respectively. Set `CUSTOM0.w` to the same mask at
/// all three corners. Combine 1 for BC, 2 for CA, and 4 for AB.
/// For example, a mask of 5 draws BC and AB. Use 0 for no edges or 7 for all.
///
/// With Dart Geometry, supply these four floats per corner through
/// `attribute0`. The caller owns the wrapped material instance.
class SharpEdgeMaterialInstance {
  final MaterialInstance _mi;

  SharpEdgeMaterialInstance(this._mi);

  /// The underlying [MaterialInstance] for advanced usage.
  MaterialInstance get materialInstance => _mi;

  Future setEdgeColor(double r, double g, double b, double a) => _mi.setParameterFloat4('edgeColor', r, g, b, a);

  Future setBaseColor(double r, double g, double b, double a) => _mi.setParameterFloat4('baseColor', r, g, b, a);

  /// Width of edge lines in pixels. Default 1.0.
  Future setEdgeWidth(double pixels) => _mi.setParameterFloat('edgeWidth', pixels);

  Future setDoubleSided(bool value) => _mi.setDoubleSided(value);
}

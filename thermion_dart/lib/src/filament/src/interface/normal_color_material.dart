import 'material.dart';

/// A typed wrapper around a normal-color [MaterialInstance].
///
/// Colors each face based on its world-space normal direction.
/// The normal xyz components are mapped from [-1,1] to [0,1] for RGB display.
///
/// Delegates all calls to the wrapped [MaterialInstance]; does not own it.
class NormalColorMaterialInstance {
  final MaterialInstance _mi;

  NormalColorMaterialInstance(this._mi);

  /// The underlying [MaterialInstance] for advanced usage.
  MaterialInstance get materialInstance => _mi;

  /// When true, uses abs(normal) so both +X and -X show as red, etc.
  Future setUseAbsoluteValue(bool value) =>
      _mi.setParameterInt('useAbsoluteValue', value ? 1 : 0);

  Future setOpacity(double value) =>
      _mi.setParameterFloat('opacity', value);

  Future setDoubleSided(bool value) => _mi.setDoubleSided(value);
}

import 'package:thermion_dart/thermion_dart.dart';

abstract class Skybox {
  ///
  ///
  ///
  Future setColor(double r, double g, double b, double a);

  ///
  /// Sets bits in a visibility mask (see filament's Skybox::setLayerMask).
  /// Use [select] to pick the bits to affect and [values] for their
  /// replacement values.
  ///
  Future setLayerMask(int select, int values);

  ///
  /// Returns the visibility mask bits.
  ///
  int getLayerMask();

  ///
  /// Returns the skybox intensity in lux (lumen/m^2).
  ///
  double getIntensity();

  ///
  /// Returns the environment texture, or null for a color-only skybox.
  ///
  Texture? getTexture();

  ///
  ///
  ///
  Future destroy();
}

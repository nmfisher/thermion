import 'package:vector_math/vector_math_64.dart';
import 'material.dart';
import 'texture.dart';

/// A typed wrapper around a gltfio ubershader [MaterialInstance].
///
/// Provides named setters for all standard PBR parameters so callers don't
/// need to know the underlying uniform/sampler names.
///
/// Delegates all calls to the wrapped [MaterialInstance]; does not own it.
class UbershaderMaterialInstance {
  final MaterialInstance _mi;

  UbershaderMaterialInstance(this._mi);

  /// The underlying [MaterialInstance] for advanced usage.
  MaterialInstance get materialInstance => _mi;

  // -- Base Color --

  Future setBaseColorFactor(double r, double g, double b, double a) =>
      _mi.setParameterFloat4('baseColorFactor', r, g, b, a);

  Future setBaseColorTexture(Texture texture, TextureSampler sampler) =>
      _mi.setParameterTexture('baseColorMap', texture, sampler);

  Future setBaseColorUV(int index) =>
      _mi.setParameterInt('baseColorIndex', index);

  Future setBaseColorUvMatrix(Matrix3 matrix) =>
      _mi.setParameterMat3('baseColorUvMatrix', matrix);

  // -- Metallic-Roughness --

  Future setMetallicFactor(double value) =>
      _mi.setParameterFloat('metallicFactor', value);

  Future setRoughnessFactor(double value) =>
      _mi.setParameterFloat('roughnessFactor', value);

  Future setMetallicRoughnessTexture(Texture texture, TextureSampler sampler) =>
      _mi.setParameterTexture('metallicRoughnessMap', texture, sampler);

  Future setMetallicRoughnessUV(int index) =>
      _mi.setParameterInt('metallicRoughnessIndex', index);

  // -- Normal --

  Future setNormalTexture(Texture texture, TextureSampler sampler) =>
      _mi.setParameterTexture('normalMap', texture, sampler);

  Future setNormalUV(int index) => _mi.setParameterInt('normalIndex', index);

  // -- Occlusion --

  Future setOcclusionTexture(Texture texture, TextureSampler sampler) =>
      _mi.setParameterTexture('occlusionMap', texture, sampler);

  Future setOcclusionUV(int index) => _mi.setParameterInt('aoIndex', index);

  // -- Emissive --

  Future setEmissiveFactor(double r, double g, double b, double a) =>
      _mi.setParameterFloat4('emissiveFactor', r, g, b, a);

  Future setEmissiveTexture(Texture texture, TextureSampler sampler) =>
      _mi.setParameterTexture('emissiveMap', texture, sampler);

  Future setEmissiveUV(int index) =>
      _mi.setParameterInt('emissiveIndex', index);

  // -- Clear Coat --

  Future setClearCoatFactor(double value) =>
      _mi.setParameterFloat('clearcoatFactor', value);

  Future setClearCoatRoughnessFactor(double value) =>
      _mi.setParameterFloat('clearcoatRoughnessFactor', value);

  Future setClearCoatTexture(Texture texture, TextureSampler sampler) =>
      _mi.setParameterTexture('clearCoatMap', texture, sampler);

  Future setClearCoatRoughnessTexture(
    Texture texture,
    TextureSampler sampler,
  ) => _mi.setParameterTexture('clearCoatRoughnessMap', texture, sampler);

  Future setClearCoatNormalTexture(Texture texture, TextureSampler sampler) =>
      _mi.setParameterTexture('clearCoatNormalMap', texture, sampler);

  // -- Transmission --

  Future setTransmissionFactor(double value) =>
      _mi.setParameterFloat('transmissionFactor', value);

  Future setTransmissionTexture(Texture texture, TextureSampler sampler) =>
      _mi.setParameterTexture('transmissionMap', texture, sampler);

  // -- Sheen --

  Future setSheenColorFactor(double r, double g, double b) =>
      _mi.setParameterFloat3('sheenColorFactor', r, g, b);

  Future setSheenRoughnessFactor(double value) =>
      _mi.setParameterFloat('sheenRoughnessFactor', value);

  Future setSheenColorTexture(Texture texture, TextureSampler sampler) =>
      _mi.setParameterTexture('sheenColorMap', texture, sampler);

  Future setSheenRoughnessTexture(Texture texture, TextureSampler sampler) =>
      _mi.setParameterTexture('sheenRoughnessMap', texture, sampler);

  // -- Volume --

  Future setVolumeThicknessFactor(double value) =>
      _mi.setParameterFloat('volumeThicknessFactor', value);

  Future setVolumeAttenuationColor(double r, double g, double b) =>
      _mi.setParameterFloat3('volumeAttenuationColor', r, g, b);

  Future setVolumeAttenuationDistance(double value) =>
      _mi.setParameterFloat('volumeAttenuationDistance', value);

  Future setVolumeThicknessTexture(Texture texture, TextureSampler sampler) =>
      _mi.setParameterTexture('volumeThicknessMap', texture, sampler);

  // -- IOR --

  Future setIOR(double value) => _mi.setParameterFloat('ior', value);

  // -- Utility --

  Future setDoubleSided(bool value) => _mi.setDoubleSided(value);

  Future setFlipUVs(bool value) => _mi.setParameterBool('flipUVs', value);

  /// Pass-through for any parameter not covered by the typed API.
  Future setParameterFloat(String name, double x) =>
      _mi.setParameterFloat(name, x);

  Future setParameterFloat4(
    String name,
    double x,
    double y,
    double z,
    double w,
  ) => _mi.setParameterFloat4(name, x, y, z, w);

  Future setParameterInt(String name, int value) =>
      _mi.setParameterInt(name, value);

  Future setParameterBool(String name, bool value) =>
      _mi.setParameterBool(name, value);

  Future setParameterTexture(
    String name,
    Texture texture,
    TextureSampler sampler,
  ) => _mi.setParameterTexture(name, texture, sampler);
}

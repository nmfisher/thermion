abstract class MaterialInstance {
  Future setDepthWriteEnabled(bool enabled);
  Future setDepthCullingEnabled(bool enabled);
  Future setParameterFloat2(String name, double x, double y);
}

enum AlphaMode { OPAQUE, MASK, BLEND }

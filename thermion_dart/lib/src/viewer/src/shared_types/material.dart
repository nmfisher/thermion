abstract class MaterialInstance {
  Future setDepthWriteEnabled(bool enabled);
  Future setDepthCullingEnabled(bool enabled);
}

enum AlphaMode { OPAQUE, MASK, BLEND }

abstract class MaterialInstance {
  Future setDepthWriteEnabled(bool enabled);
  
  Future setDepthCullingEnabled(bool enabled);
  Future setParameterFloat4(String name, double x, double y, double z, double w);
  Future setParameterFloat2(String name, double x, double y);
  Future setParameterFloat(String name, double x);
  Future setParameterInt(String name, int value);
}

enum AlphaMode { OPAQUE, MASK, BLEND }

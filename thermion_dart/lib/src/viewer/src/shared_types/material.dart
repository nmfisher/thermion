import 'package:thermion_dart/src/viewer/src/ffi/src/callbacks.dart';

enum SamplerCompareFunction { 
  /// !< Less or equal
  LE,
  /// !< Greater or equal
  GE,
  /// !< Strictly less than
  L,
  /// !< Strictly greater than
  G,
  /// !< Equal
  E,
  /// !< Not equal
  NE,
  /// !< Always. Depth / stencil testing is deactivated.
  A,
  /// !< Never. The depth / stencil test always fails.
  N;
}
abstract class MaterialInstance {
  Future setDepthWriteEnabled(bool enabled);
  Future setDepthFunc(SamplerCompareFunction depthFunc);
  
  Future setDepthCullingEnabled(bool enabled);
  Future setParameterFloat4(String name, double x, double y, double z, double w);
  Future setParameterFloat2(String name, double x, double y);
  Future setParameterFloat(String name, double x);
  Future setParameterInt(String name, int value);
}

enum AlphaMode { OPAQUE, MASK, BLEND }

import 'package:thermion_dart/thermion_dart.dart';
import 'package:vector_math/vector_math_64.dart';

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

/// Defines stencil operations
enum StencilOperation {
  /// Keep the current value
  KEEP,

  /// Set the value to zero
  ZERO,

  /// Set the value to reference value
  REPLACE,

  /// Increment the current value with saturation
  INCR,

  /// Increment the current value without saturation
  INCR_WRAP,

  /// Decrement the current value with saturation
  DECR,

  /// Decrement the current value without saturation
  DECR_WRAP,

  /// Invert the current value
  INVERT
}

enum CullingMode {
  NONE, // No culling
  FRONT, // Cull front faces
  BACK, // Cull back faces
  FRONT_AND_BACK // Cull both front and back faces
}

/// Defines which face(s) the stencil operation affects
enum StencilFace {
  /// Front face only
  FRONT,

  /// Back face only
  BACK,

  /// Both front and back faces
  FRONT_AND_BACK
}

enum AlphaMode { OPAQUE, MASK, BLEND }

enum TransparencyMode {
  //! the transparent object is drawn honoring the raster state
  DEFAULT,
  /**
		 * the transparent object is first drawn in the depth buffer,
		 * then in the color buffer, honoring the culling mode, but ignoring the depth test function
		 */
  TWO_PASSES_ONE_SIDE,

  /**
		 * the transparent object is drawn twice in the color buffer,
		 * first with back faces only, then with front faces; the culling
		 * mode is ignored. Can be combined with two-sided lighting
		 */
  TWO_PASSES_TWO_SIDES
}

abstract class Material {
  Future<MaterialInstance> createInstance();
  Future<bool> hasParameter(String propertyName);
  Future destroy();
}

abstract class MaterialInstance {
  Future<bool> isStencilWriteEnabled();
  Future setDepthWriteEnabled(bool enabled);
  Future setDepthFunc(SamplerCompareFunction depthFunc);
  Future setDepthCullingEnabled(bool enabled);
  Future setParameterFloat(String name, double x);
  Future setParameterFloat2(String name, double x, double y);
  Future setParameterFloat3(String name, double x, double y, double z);
  Future setParameterFloat3Array(String name, List<Vector3> data);
  Future setParameterFloat4(
      String name, double x, double y, double z, double w);
  Future setParameterMat4(
      String name, Matrix4 matrix);
  
  Future setParameterInt(String name, int value);
  Future setParameterBool(String name, bool value);
  Future setParameterTexture(
      String name, covariant Texture texture, covariant TextureSampler sampler);

  /// Sets the stencil operation to be performed when the stencil test fails
  Future setStencilOpStencilFail(StencilOperation op,
      [StencilFace face = StencilFace.FRONT_AND_BACK]);

  /// Sets the stencil operation to be performed when the depth test fails
  Future setStencilOpDepthFail(StencilOperation op,
      [StencilFace face = StencilFace.FRONT_AND_BACK]);

  /// Sets the stencil operation to be performed when both depth and stencil tests pass
  Future setStencilOpDepthStencilPass(StencilOperation op,
      [StencilFace face = StencilFace.FRONT_AND_BACK]);

  /// Sets the stencil test comparison function
  Future setStencilCompareFunction(SamplerCompareFunction func,
      [StencilFace face = StencilFace.FRONT_AND_BACK]);

  /// Sets the reference value used for stencil testing
  Future setStencilReferenceValue(int value,
      [StencilFace face = StencilFace.FRONT_AND_BACK]);

  Future setStencilWriteEnabled(bool enabled);

  Future setCullingMode(CullingMode cullingMode);

  Future setStencilReadMask(int mask);
  Future setStencilWriteMask(int mask);

  Future setTransparencyMode(TransparencyMode mode);

  Future destroy();
}

import 'package:thermion_dart/src/filament/src/interface/native_handle.dart';
import 'package:thermion_dart/thermion_dart.dart';

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
  N,
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
  INVERT,
}

enum CullingMode {
  NONE, // No culling
  FRONT, // Cull front faces
  BACK, // Cull back faces
  FRONT_AND_BACK, // Cull both front and back faces
}

/// Defines which face(s) the stencil operation affects
enum StencilFace {
  /// Front face only
  FRONT,

  /// Back face only
  BACK,

  /// Both front and back faces
  FRONT_AND_BACK,
}

enum AlphaMode { OPAQUE, MASK, BLEND }

enum BlendingMode {
  /// Material is opaque
  OPAQUE,

  /// Material is transparent and color is alpha-pre-multiplied, affects diffuse lighting only
  TRANSPARENT,

  /// Material is additive (e.g.: hologram)
  ADD,

  /// Material is masked (i.e. alpha tested)
  MASKED,

  /// Material is transparent and color is alpha-pre-multiplied, affects specular lighting
  FADE,

  /// Material darkens what's behind it
  MULTIPLY,

  /// Material brightens what's behind it
  SCREEN,

  /// Custom blending function
  CUSTOM,
}

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
  TWO_PASSES_TWO_SIDES,
}

/// Shading model for runtime-compiled materials, mirroring
/// `filament::Shading` and the native `TShading` values.
enum MaterialShading { unlit, lit, subsurface, cloth, specularGlossiness }

/// Queue Filament compiles a material's variants in, mirroring
/// `filament::CompilerPriorityQueue` ([Material.compile]).
enum CompilerPriorityQueue {
  /// We need this program NOW. Where the platform cannot compile in parallel
  /// but can amortize compilation, the shader is compiled synchronously.
  critical,

  /// We will need this program soon.
  high,

  /// We will need this program eventually.
  low,
}

/// Shader variants a [Material] can be compiled for, mirroring
/// `filament::UserVariantFilterBit`.
///
/// Pass the set the application renders to [Material.compile]; each bit is
/// one variant in the native variant mask.
enum UserVariantFilterBit {
  /// Directional lighting.
  directionalLighting(0x01),

  /// Dynamic lighting. Since dynamic lighting moved to specialization
  /// constants this no longer changes the offline-compiled material, but it
  /// still prunes unnecessary pipeline compilations at runtime.
  dynamicLighting(0x02),

  /// Shadow receiver.
  shadowReceiver(0x04),

  /// Skinning.
  skinning(0x08),

  /// Fog.
  fog(0x10),

  /// Variance shadow maps.
  vsm(0x20),

  /// Screen-space reflections.
  ssr(0x40),

  /// Instanced stereo rendering.
  ste(0x80);

  const UserVariantFilterBit(this.mask);

  /// This bit's value in the native `TUserVariantFilterBit` mask.
  final int mask;

  /// Every variant. Filament advises requesting only the variants an app
  /// actually renders: for example [ste] is only used for stereoscopic
  /// rendering and compiling it is wasted work otherwise.
  static const Set<UserVariantFilterBit> all = {
    directionalLighting,
    dynamicLighting,
    shadowReceiver,
    skinning,
    fog,
    vsm,
    ssr,
    ste,
  };

  /// The native variant mask (bitwise OR of [bits]' [mask] values).
  static int maskOf(Iterable<UserVariantFilterBit> bits) {
    var mask = 0;
    for (final bit in bits) {
      mask |= bit.mask;
    }
    return mask;
  }
}

abstract class Material<T> extends NativeHandle<T> {
  Future<MaterialInstance> createInstance();

  /// Asynchronously compiles this material's shaders for [variants] so later
  /// renders do not stall on shader compilation.
  ///
  /// The returned Future completes once every requested variant that the
  /// material supports has been compiled, or when the engine is destroyed
  /// first. Compilation happens on the backend and can take hundreds of
  /// milliseconds; it progresses whenever the engine executes (a rendered
  /// frame, a flush or a readback), so no rendering is required. [priority]
  /// selects the queue Filament compiles in; when the same variant is
  /// requested more than once, the first request's priority applies.
  /// Compiling an already-compiled variant completes as soon as the engine
  /// processes the request.
  Future<void> compile({
    CompilerPriorityQueue priority = CompilerPriorityQueue.low,
    Set<UserVariantFilterBit> variants = UserVariantFilterBit.all,
  });

  Future<bool> hasParameter(String propertyName);
  Future<BlendingMode> getBlendingMode();
  Future destroy();
}

abstract class MaterialInstance<T> extends NativeHandle<T> {
  Future<bool> isStencilWriteEnabled();
  Future setDoubleSided(bool doubleSided);
  Future setDepthWriteEnabled(bool enabled);
  Future setDepthFunc(SamplerCompareFunction depthFunc);
  Future setDepthCullingEnabled(bool enabled);
  Future setParameterFloat(String name, double x);
  Future setParameterFloat2(String name, double x, double y);
  Future setParameterFloat3(String name, double x, double y, double z);
  Future setParameterFloat3Array(String name, List<Vector3> data);
  Future setParameterFloat4(String name, double x, double y, double z, double w);
  Future setParameterMat3(String name, Matrix3 matrix);
  Future setParameterMat4(String name, Matrix4 matrix);

  Future setParameterInt(String name, int value);
  Future setParameterBool(String name, bool value);
  Future setParameterTexture(String name, covariant Texture texture, covariant TextureSampler sampler);

  /// Sets the stencil operation to be performed when the stencil test fails
  Future setStencilOpStencilFail(StencilOperation op, [StencilFace face = StencilFace.FRONT_AND_BACK]);

  /// Sets the stencil operation to be performed when the depth test fails
  Future setStencilOpDepthFail(StencilOperation op, [StencilFace face = StencilFace.FRONT_AND_BACK]);

  /// Sets the stencil operation to be performed when both depth and stencil tests pass
  Future setStencilOpDepthStencilPass(StencilOperation op, [StencilFace face = StencilFace.FRONT_AND_BACK]);

  /// Sets the stencil test comparison function
  Future setStencilCompareFunction(SamplerCompareFunction func, [StencilFace face = StencilFace.FRONT_AND_BACK]);

  /// Sets the reference value used for stencil testing
  Future setStencilReferenceValue(int value, [StencilFace face = StencilFace.FRONT_AND_BACK]);

  Future setStencilWriteEnabled(bool enabled);

  Future setCullingMode(CullingMode cullingMode);

  Future setStencilReadMask(int mask);
  Future setStencilWriteMask(int mask);

  Future setTransparencyMode(TransparencyMode mode);
  Future<TransparencyMode> getTransparencyMode();

  Future destroy();
}

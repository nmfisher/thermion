import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/src/filament/src/interface/skybox.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FilamentConfig<T, U> {
  final Backend backend;
  final T? renderCallback;
  final U? renderCallbackOwner;
  Future<Uint8List> Function(String)? loadResource;
  final U? platform;
  final U? sharedContext;
  final String? uberArchivePath;
  final int stereoscopicEyeCount;
  final bool disableHandleUseAfterFreeCheck;

  FilamentConfig(
      {required this.backend,
      required this.loadResource,
      this.uberArchivePath,
      this.renderCallback,
      this.renderCallbackOwner,
      this.platform,
      this.sharedContext,
      this.stereoscopicEyeCount = 1,
      this.disableHandleUseAfterFreeCheck = false});
}

abstract class FilamentApp<T> {
  static FilamentApp? instance;

  T get engine;
  T get gltfAssetLoader;
  T get renderer;
  T get transformManager;
  T get lightManager;
  T get renderableManager;
  T get ubershaderMaterialProvider;

  ///
  ///
  ///
  Future<Uint8List> loadResource(String uri);

  ///
  ///
  ///
  Future<SwapChain> createHeadlessSwapChain(int width, int height,
      {bool hasStencilBuffer = false});

  ///
  ///
  ///
  Future<SwapChain> createSwapChain(T handle, {bool hasStencilBuffer = false});

  ///
  ///
  ///
  Future<View> createView();

  ///
  ///
  ///
  Future<Scene> createScene();

  ///
  ///
  ///
  Future<Camera> createCamera();

  ///
  ///
  ///
  Future destroySwapChain(SwapChain swapChain);

  ///
  ///
  ///
  Future destroyView(View view);

  ///
  ///
  ///
  Future destroyScene(Scene scene);

  ///
  ///
  ///
  Future destroy();

  ///
  ///
  ///
  Future destroyAsset(covariant ThermionAsset asset);

  ///
  ///
  ///
  Future<RenderTarget> createRenderTarget(int width, int height,
      {covariant Texture? color, covariant Texture? depth});

  ///
  ///
  ///
  Future<Texture> createTexture(int width, int height,
      {int depth = 1,
      int levels = 1,
      Set<TextureUsage> flags = const {TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
      TextureSamplerType textureSamplerType = TextureSamplerType.SAMPLER_2D,
      TextureFormat textureFormat = TextureFormat.RGBA32F,
      int? importedTextureHandle});

  ///
  ///
  ///
  Future<TextureSampler> createTextureSampler(
      {TextureMinFilter minFilter = TextureMinFilter.LINEAR,
      TextureMagFilter magFilter = TextureMagFilter.LINEAR,
      TextureWrapMode wrapS = TextureWrapMode.CLAMP_TO_EDGE,
      TextureWrapMode wrapT = TextureWrapMode.CLAMP_TO_EDGE,
      TextureWrapMode wrapR = TextureWrapMode.CLAMP_TO_EDGE,
      double anisotropy = 0.0,
      TextureCompareMode compareMode = TextureCompareMode.NONE,
      TextureCompareFunc compareFunc = TextureCompareFunc.LESS_EQUAL});

  ///
  /// Decodes the specified image data.
  ///
  Future<LinearImage> decodeImage(Uint8List data,
      {String name = "image", bool requireAlpha = false});

  ///
  /// Creates an (empty) imge with the given dimensions.
  ///
  Future<LinearImage> createImage(int width, int height, int channels);

  ///
  ///
  ///
  Future<Material> createMaterial(Uint8List data);

  ///
  ///
  ///
  Future<MaterialInstance> createUbershaderMaterialInstance({
    bool doubleSided = false,
    bool unlit = false,
    bool hasVertexColors = false,
    bool hasBaseColorTexture = false,
    bool hasNormalTexture = false,
    bool hasOcclusionTexture = false,
    bool hasEmissiveTexture = false,
    bool useSpecularGlossiness = false,
    AlphaMode alphaMode = AlphaMode.OPAQUE,
    bool enableDiagnostics = false,
    bool hasMetallicRoughnessTexture = false,
    int metallicRoughnessUV = -1,
    int baseColorUV = -1,
    bool hasClearCoatTexture = false,
    int clearCoatUV = -1,
    bool hasClearCoatRoughnessTexture = false,
    int clearCoatRoughnessUV = -1,
    bool hasClearCoatNormalTexture = false,
    int clearCoatNormalUV = -1,
    bool hasClearCoat = false,
    bool hasTransmission = false,
    bool hasTextureTransforms = false,
    int emissiveUV = -1,
    int aoUV = -1,
    int normalUV = -1,
    bool hasTransmissionTexture = false,
    int transmissionUV = -1,
    bool hasSheenColorTexture = false,
    int sheenColorUV = -1,
    bool hasSheenRoughnessTexture = false,
    int sheenRoughnessUV = -1,
    bool hasVolumeThicknessTexture = false,
    int volumeThicknessUV = -1,
    bool hasSheen = false,
    bool hasIOR = false,
    bool hasVolume = false,
  });

  ///
  ///
  ///
  Future<MaterialInstance> createUnlitMaterialInstance();

  ///
  ///
  ///
  Future<MaterialInstance> getMaterialInstanceAt(
      ThermionEntity entity, int primitiveIndex);

  ///
  ///
  ///
  Future setMaterialInstanceAt(ThermionEntity entity, int primitiveIndex,
      MaterialInstance materialInstance);

  ///
  ///
  ///
  Future register(covariant SwapChain swapChain, covariant View view);

  ///
  ///
  ///
  Future unregister(covariant SwapChain swapChain, covariant View view);

  ///
  ///
  ///
  Future<Iterable<SwapChain>> getSwapChains();

  ///
  ///
  ///
  Future updateRenderOrder();

  ///
  ///
  ///
  Future render();

  ///
  ///
  ///
  Future requestFrame();

  ///
  ///
  ///
  Future registerRequestFrameHook(Future Function() hook);

  ///
  ///
  ///
  Future unregisterRequestFrameHook(Future Function() hook);

  ///
  /// Retrieves the name assigned to the given entity (usually corresponds to the glTF mesh name).
  ///
  String? getNameForEntity(ThermionEntity entity);

  ///
  /// Gets the parent entity of [entity]. Returns null if the entity has no parent.
  ///
  Future<ThermionEntity?> getParent(ThermionEntity entity);

  ///
  /// Gets the ancestor (ultimate parent) entity of [entity]. Returns null if the entity has no parent.
  ///
  Future<ThermionEntity?> getAncestor(ThermionEntity entity);

  ///
  /// Sets the parent transform of [child] to [parent].
  ///
  Future setParent(ThermionEntity child, ThermionEntity? parent,
      {bool preserveScaling});

  ///
  ///
  ///
  Future<MaterialInstance> createImageMaterialInstance();

  ///
  /// Returns pixel buffer(s) for [view] (or, if null, all views associated
  /// with [swapChain] by calling [register]).
  ///
  /// Pixel buffers will be returned in RGBA float32 format.
  ///
  Future<List<(View, Uint8List)>> capture(covariant SwapChain? swapChain,
      {covariant View? view,
      bool captureRenderTarget = false,
      PixelDataFormat pixelDataFormat = PixelDataFormat.RGBA,
      PixelDataType pixelDataType = PixelDataType.FLOAT,
      Future Function(View)? beforeRender,
      bool render = true});

  ///
  ///
  ///
  Future setClearOptions(double r, double g, double b, double a,
      {int clearStencil = 0, bool discard = false, bool clear = true});

  /// See [FilamentViewerFFI.loadGltf] for details.
  ///
  ///
  Future<ThermionAsset> loadGltfFromBuffer(Uint8List data, T animationManager,
      {int initialInstances = 1,
      bool keepData = false,
      int priority = 4,
      int layer = 0,
      bool loadResourcesAsync = false,
      String? resourceUri});

  ///
  ///
  ///
  Future<T> createColorGrading(ToneMapper mapper);

  ///
  ///
  ///
  Future<GizmoAsset> createGizmo(
      covariant View view, T animationManager, GizmoType type);

  ///
  ///
  ///
  Future<ThermionAsset> createGeometry(Geometry geometry, T animationManager,
      {List<MaterialInstance>? materialInstances, bool keepData = false});

  ///
  ///
  ///
  Future<ThermionEntity> createDirectLight(DirectLight directLight);

  ///
  ///
  ///
  Future flush();

  ///
  ///
  ///
  void onDestroy(Future Function() callback);

  ///
  ///
  ///
  Future<ThermionEntity> createEntity({bool createTransformComponent = true});

  ///
  ///
  ///
  Future setTransform(ThermionEntity entity, Matrix4 transform);

  ///
  ///
  ///
  Future<Matrix4> getWorldTransform(ThermionEntity entity);

  /// Sets the render priority for [entity].
  /// [priority] should be be between 0 and 7, with 0 meaning highest priority
  /// (rendered first) and 7 meaning lowest priority (rendered last).
  ///
  Future setPriority(ThermionEntity entity, int priority);

  /// Gets the number of primitives for [entity] (which is assumed to be
  /// have a renderable component attached)
  ///
  Future<int> getPrimitiveCount(ThermionEntity entity);

  /// Gets the bounding box for [entity] (which is assumed to be
  /// have a renderable component attached).
  ///
  Future<Aabb3> getBoundingBox(ThermionEntity entity);

  /// Builds a [Skybox] instance. This will not be attached to any scene until
  /// [setSkybox] is called.
  ///
  Future<Skybox> buildSkybox({Texture? texture = null});

  ///
  ///
  ///
  Future<bool> isRenderable(ThermionEntity entity);

  /// Create a [Texture] from the content of a KTX2 file containing
  /// BasisU-encoded data. Even though the KTX2 format does not mandate BasisU 
  /// compression, the Filament implementation uses BasisU to decode KTX2 data
  /// (which will fail if you pass an uncompressed KTX2 file).
  ///
  Future<Texture> loadKtx2(Uint8List data);
}

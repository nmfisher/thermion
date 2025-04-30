import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FilamentConfig<T, U> {
  final Backend backend;
  final T? renderCallback;
  final U? renderCallbackOwner;
  Future<Uint8List> Function(String)? resourceLoader;
  final U? platform;
  final U? sharedContext;
  final String? uberArchivePath;
  final int stereoscopicEyeCount;
  final bool disableHandleUseAfterFreeCheck;

  FilamentConfig(
      {required this.backend,
      required this.resourceLoader,
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

  final T engine;
  final T gltfAssetLoader;
  final T renderer;
  final T transformManager;
  final T lightManager;
  final T renderableManager;
  final T ubershaderMaterialProvider;

  FilamentApp(
      {required this.engine,
      required this.gltfAssetLoader,
      required this.renderer,
      required this.transformManager,
      required this.lightManager,
      required this.renderableManager,
      required this.ubershaderMaterialProvider});

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
  Future<LinearImage> decodeImage(Uint8List data);

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
      ThermionEntity entity, int index);

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
      Future Function(View)? beforeRender});

  ///
  ///
  ///
  Future setClearOptions(double r, double g, double b, double a,
      {int clearStencil = 0, bool discard = false, bool clear = true});

  ///
  ///
  ///
  Future<ThermionAsset> loadGltfFromBuffer(Uint8List data, T animationManager,
      {int numInstances = 1,
      bool keepData = false,
      int priority = 4,
      int layer = 0,
      bool loadResourcesAsync = false,
      String? relativeResourcePath});

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
  Future flush();

  ///
  ///
  ///
  void onDestroy(Future Function() callback);
}

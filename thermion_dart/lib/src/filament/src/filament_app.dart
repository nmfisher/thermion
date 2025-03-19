import 'dart:typed_data';

import 'package:thermion_dart/src/filament/src/engine.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FilamentConfig<T, U> {
  final Backend backend;
  final T? renderCallback;
  final U? renderCallbackOwner;
  final U resourceLoader;
  final U? platform;
  final U? driver;
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
      this.driver,
      this.sharedContext,
      this.stereoscopicEyeCount = 1,
      this.disableHandleUseAfterFreeCheck = false});
}

abstract class FilamentApp<T> {

  static FilamentApp? instance;

  final T engine;
  final T gltfAssetLoader;
  final T gltfResourceLoader;
  final T renderer;
  final T transformManager;
  final T lightManager;
  final T renderableManager;
  final T ubershaderMaterialProvider;

  FilamentApp(
      {required this.engine,
      required this.gltfAssetLoader,
      required this.gltfResourceLoader,
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
  Future destroySwapChain(SwapChain swapChain);

  ///
  ///
  ///
  Future destroy();

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
      TextureFormat textureFormat = TextureFormat.RGBA16F,
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
  @override
  Future<ThermionAsset> createGeometry(Geometry geometry,
      {List<MaterialInstance>? materialInstances, bool keepData = false});

  ///
  ///
  ///
  Future setRenderable(covariant View view, bool renderable);

  ///
  ///
  ///
  Future register(covariant SwapChain swapChain, covariant View view);

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
}

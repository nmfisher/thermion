import 'dart:async';
import 'dart:typed_data';

import 'package:thermion_dart/src/filament/src/engine.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/callbacks.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_material.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_render_target.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_swapchain.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_texture.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_view.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_viewer_ffi.dart';
import 'package:thermion_dart/thermion_dart.dart';

typedef RenderCallback = Pointer<NativeFunction<Void Function(Pointer<Void>)>>;

class FFIFilamentConfig extends FilamentConfig<RenderCallback, Pointer<Void>> {
  FFIFilamentConfig(
      {required super.resourceLoader,
      super.backend = Backend.DEFAULT,
      super.driver = null,
      super.platform = null,
      super.sharedContext = null,
      super.uberArchivePath = null});
}

class FFIFilamentApp extends FilamentApp<Pointer> {
  final Pointer<TEngine> engine;
  final Pointer<TGltfAssetLoader> gltfAssetLoader;
  final Pointer<TGltfResourceLoader> gltfResourceLoader;
  final Pointer<TRenderer> renderer;
  final Pointer<TTransformManager> transformManager;
  final Pointer<TLightManager> lightManager;
  final Pointer<TRenderableManager> renderableManager;
  final Pointer<TMaterialProvider> ubershaderMaterialProvider;
  final Pointer<TRenderTicker> renderTicker;
  final Pointer<TNameComponentManager> nameComponentManager;

  FFIFilamentApp(
      this.engine,
      this.gltfAssetLoader,
      this.gltfResourceLoader,
      this.renderer,
      this.transformManager,
      this.lightManager,
      this.renderableManager,
      this.ubershaderMaterialProvider,
      this.renderTicker,
      this.nameComponentManager)
      : super(
            engine: engine,
            gltfAssetLoader: gltfAssetLoader,
            gltfResourceLoader: gltfResourceLoader,
            renderer: renderer,
            transformManager: transformManager,
            lightManager: lightManager,
            renderableManager: renderableManager,
            ubershaderMaterialProvider: ubershaderMaterialProvider) {}

  static Future create({FFIFilamentConfig? config}) async {
    config ??= FFIFilamentConfig(resourceLoader: nullptr);
    if (FilamentApp.instance != null) {
      await FilamentApp.instance!.destroy();
    }

    RenderLoop_destroy();
    RenderLoop_create();

    final engine = await withPointerCallback<TEngine>((cb) =>
        Engine_createRenderThread(
            TBackend.values[config!.backend.index].index,
            config.platform ?? nullptr,
            config.sharedContext ?? nullptr,
            config.stereoscopicEyeCount,
            config.disableHandleUseAfterFreeCheck,
            cb));

    final gltfResourceLoader = await withPointerCallback<TGltfResourceLoader>(
        (cb) => GltfResourceLoader_createRenderThread(engine, cb));
    final gltfAssetLoader = await withPointerCallback<TGltfAssetLoader>(
        (cb) => GltfAssetLoader_createRenderThread(engine, nullptr, cb));
    final renderer = await withPointerCallback<TRenderer>(
        (cb) => Engine_createRendererRenderThread(engine, cb));
    final ubershaderMaterialProvider =
        GltfAssetLoader_getMaterialProvider(gltfAssetLoader);

    final transformManager = Engine_getTransformManager(engine);
    final lightManager = Engine_getLightManager(engine);
    final renderableManager = Engine_getRenderableManager(engine);

    final renderTicker = RenderTicker_create(renderer);

    final nameComponentManager = NameComponentManager_create();

    FilamentApp.instance = FFIFilamentApp(
        engine,
        gltfAssetLoader,
        gltfResourceLoader,
        renderer,
        transformManager,
        lightManager,
        renderableManager,
        ubershaderMaterialProvider,
        renderTicker,
        nameComponentManager);
  }

  final _views = <FFISwapChain, List<FFIView>>{};
  final _viewMappings = <FFIView, FFISwapChain>{};

  ///
  ///
  ///
  Future setRenderable(covariant FFIView view, bool renderable) async {
    final swapChain = _viewMappings[view]!;
    if (renderable && !_views[swapChain]!.contains(view)) {
      _views[swapChain]!.add(view);
    } else if (!renderable && _views[swapChain]!.contains(view)) {
      _views[swapChain]!.remove(view);
    }

    final views = calloc<Pointer<TView>>(255);
    for (final swapChain in _views.keys) {
      var numViews = _views[swapChain]!.length;
      for (int i = 0; i < numViews; i++) {
        views[i] = _views[swapChain]![i].view;
      }
      RenderTicker_setRenderable(
          renderTicker, swapChain.swapChain, views, numViews);
    }
    calloc.free(views);
  }

  @override
  Future<SwapChain> createHeadlessSwapChain(int width, int height,
      {bool hasStencilBuffer = false}) async {
    var flags = TSWAP_CHAIN_CONFIG_TRANSPARENT | TSWAP_CHAIN_CONFIG_READABLE;
    if (hasStencilBuffer) {
      flags |= TSWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER;
    }
    final swapChain = await withPointerCallback<TSwapChain>((cb) =>
        Engine_createHeadlessSwapChainRenderThread(
            this.engine, width, height, flags, cb));
    return FFISwapChain(swapChain);
  }

  ///
  ///
  ///
  @override
  Future<SwapChain> createSwapChain(Pointer window,
      {bool hasStencilBuffer = false}) async {
    var flags = TSWAP_CHAIN_CONFIG_TRANSPARENT | TSWAP_CHAIN_CONFIG_READABLE;
    if (hasStencilBuffer) {
      flags |= TSWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER;
    }
    final swapChain = await withPointerCallback<TSwapChain>((cb) =>
        Engine_createSwapChainRenderThread(
            this.engine, window.cast<Void>(), flags, cb));
    return FFISwapChain(swapChain);
  }

  ///
  ///
  ///
  Future destroySwapChain(SwapChain swapChain) async {
    await withVoidCallback((callback) {
      Engine_destroySwapChainRenderThread(
          engine, (swapChain as FFISwapChain).swapChain, callback);
    });
  }

  ///
  ///
  ///
  @override
  Future destroy() async {
    for (final swapChain in _views.keys) {
      for (final view in _views[swapChain]!) {
        await setRenderable(view, false);
      }
    }
    for (final swapChain in _views.keys) {
      await destroySwapChain(swapChain);
    }
    RenderLoop_destroy();
    RenderTicker_destroy(renderTicker);
    Engine_destroy(engine);
  }

  ///
  ///
  ///
  Future<RenderTarget> createRenderTarget(int width, int height,
      {covariant FFITexture? color, covariant FFITexture? depth}) async {
    final renderTarget = await withPointerCallback<TRenderTarget>((cb) {
      RenderTarget_createRenderThread(engine, width, height,
          color?.pointer ?? nullptr, depth?.pointer ?? nullptr, cb);
    });

    return FFIRenderTarget(renderTarget, this);
  }

  ///
  ///
  ///
  Future<Texture> createTexture(int width, int height,
      {int depth = 1,
      int levels = 1,
      Set<TextureUsage> flags = const {TextureUsage.TEXTURE_USAGE_SAMPLEABLE},
      TextureSamplerType textureSamplerType = TextureSamplerType.SAMPLER_2D,
      TextureFormat textureFormat = TextureFormat.RGBA16F,
      int? importedTextureHandle}) async {
    var bitmask = flags.fold(0, (a, b) => a | b.value);
    print("bitmask $bitmask");
    final texturePtr = await withPointerCallback<TTexture>((cb) {
      Texture_buildRenderThread(
          engine,
          width,
          height,
          depth,
          levels,
          bitmask,
          importedTextureHandle ?? 0,
          TTextureSamplerType.values[textureSamplerType.index],
          TTextureFormat.values[textureFormat.index],
          cb);
    });
    if (texturePtr == nullptr) {
      throw Exception("Failed to create texture");
    }
    return FFITexture(
      engine!,
      texturePtr,
    );
  }

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
      TextureCompareFunc compareFunc = TextureCompareFunc.LESS_EQUAL}) async {
    final samplerPtr = TextureSampler_create();
    TextureSampler_setMinFilter(
        samplerPtr, TSamplerMinFilter.values[minFilter.index]);
    TextureSampler_setMagFilter(
        samplerPtr, TSamplerMagFilter.values[magFilter.index]);
    TextureSampler_setWrapModeS(
        samplerPtr, TSamplerWrapMode.values[wrapS.index]);
    TextureSampler_setWrapModeT(
        samplerPtr, TSamplerWrapMode.values[wrapT.index]);
    TextureSampler_setWrapModeR(
        samplerPtr, TSamplerWrapMode.values[wrapR.index]);
    if (anisotropy > 0) {
      TextureSampler_setAnisotropy(samplerPtr, anisotropy);
    }

    TextureSampler_setCompareMode(
        samplerPtr,
        TSamplerCompareMode.values[compareMode.index],
        TSamplerCompareFunc.values[compareFunc.index]);

    return FFITextureSampler(samplerPtr);
  }

  ///
  ///
  ///
  Future<LinearImage> decodeImage(Uint8List data) async {
    final name = "image";
    var ptr = Image_decode(
      data.address,
      data.length,
      name.toNativeUtf8().cast<Char>(),
    );
    if (ptr == nullptr) {
      throw Exception("Failed to decode image");
    }
    return FFILinearImage(ptr);
  }

  ///
  /// Creates an (empty) imge with the given dimensions.
  ///
  Future<LinearImage> createImage(int width, int height, int channels) async {
    final ptr = Image_createEmpty(width, height, channels);
    return FFILinearImage(ptr);
  }

  ///
  ///
  ///
  Future<Material> createMaterial(Uint8List data) async {
    var ptr = await withPointerCallback<TMaterial>((cb) {
      Engine_buildMaterialRenderThread(engine!, data.address, data.length, cb);
    });
    return FFIMaterial(ptr, this);
  }

  ///
  ///
  ///
  Future<MaterialInstance> createUbershaderMaterialInstance(
      {bool doubleSided = false,
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
      int metallicRoughnessUV = 0,
      int baseColorUV = 0,
      bool hasClearCoatTexture = false,
      int clearCoatUV = 0,
      bool hasClearCoatRoughnessTexture = false,
      int clearCoatRoughnessUV = 0,
      bool hasClearCoatNormalTexture = false,
      int clearCoatNormalUV = 0,
      bool hasClearCoat = false,
      bool hasTransmission = false,
      bool hasTextureTransforms = false,
      int emissiveUV = 0,
      int aoUV = 0,
      int normalUV = 0,
      bool hasTransmissionTexture = false,
      int transmissionUV = 0,
      bool hasSheenColorTexture = false,
      int sheenColorUV = 0,
      bool hasSheenRoughnessTexture = false,
      int sheenRoughnessUV = 0,
      bool hasVolumeThicknessTexture = false,
      int volumeThicknessUV = 0,
      bool hasSheen = false,
      bool hasIOR = false,
      bool hasVolume = false}) async {
    final key = Struct.create<TMaterialKey>();

    key.doubleSided = doubleSided;
    key.unlit = unlit;
    key.hasVertexColors = hasVertexColors;
    key.hasBaseColorTexture = hasBaseColorTexture;
    key.hasNormalTexture = hasNormalTexture;
    key.hasOcclusionTexture = hasOcclusionTexture;
    key.hasEmissiveTexture = hasEmissiveTexture;
    key.useSpecularGlossiness = useSpecularGlossiness;
    key.alphaMode = alphaMode.index;
    key.enableDiagnostics = enableDiagnostics;
    key.unnamed.unnamed.hasMetallicRoughnessTexture =
        hasMetallicRoughnessTexture;
    key.unnamed.unnamed.metallicRoughnessUV = 0;
    key.baseColorUV = baseColorUV;
    key.hasClearCoatTexture = hasClearCoatTexture;
    key.clearCoatUV = clearCoatUV;
    key.hasClearCoatRoughnessTexture = hasClearCoatRoughnessTexture;
    key.clearCoatRoughnessUV = clearCoatRoughnessUV;
    key.hasClearCoatNormalTexture = hasClearCoatNormalTexture;
    key.clearCoatNormalUV = clearCoatNormalUV;
    key.hasClearCoat = hasClearCoat;
    key.hasTransmission = hasTransmission;
    key.hasTextureTransforms = hasTextureTransforms;
    key.emissiveUV = emissiveUV;
    key.aoUV = aoUV;
    key.normalUV = normalUV;
    key.hasTransmissionTexture = hasTransmissionTexture;
    key.transmissionUV = transmissionUV;
    key.hasSheenColorTexture = hasSheenColorTexture;
    key.sheenColorUV = sheenColorUV;
    key.hasSheenRoughnessTexture = hasSheenRoughnessTexture;
    key.sheenRoughnessUV = sheenRoughnessUV;
    key.hasVolumeThicknessTexture = hasVolumeThicknessTexture;
    key.volumeThicknessUV = volumeThicknessUV;
    key.hasSheen = hasSheen;
    key.hasIOR = hasIOR;
    key.hasVolume = hasVolume;

    final materialInstance = await withPointerCallback<TMaterialInstance>((cb) {
      MaterialProvider_createMaterialInstanceRenderThread(
          ubershaderMaterialProvider, key.address, cb);
    });
    if (materialInstance == nullptr) {
      throw Exception("Failed to create material instance");
    }

    var instance = FFIMaterialInstance(materialInstance, this);
    return instance;
  }

  ///
  ///
  ///
  Future<FFIMaterialInstance> createUnlitMaterialInstance() async {
    final instance = await createUbershaderMaterialInstance(unlit: true);
    return instance as FFIMaterialInstance;
  }

  FFIMaterial? _gridMaterial;
  Future<FFIMaterial> get gridMaterial async {
    _gridMaterial ??= FFIMaterial(Material_createGridMaterial(engine), this);
    return _gridMaterial!;
  }

  ///
  ///
  ///
  Future<MaterialInstance> getMaterialInstanceAt(
      ThermionEntity entity, int index) async {
    final instancePtr = RenderableManager_getMaterialInstanceAt(
        renderableManager, entity, index);

    final instance = FFIMaterialInstance(instancePtr, this);
    return instance;
  }

  ///
  ///
  ///
  @override
  Future render() async {
    await withVoidCallback(
        (cb) => RenderTicker_renderRenderThread(renderTicker, 0, cb));
  }

  ///
  ///
  ///
  @override
  Future register(
      covariant FFISwapChain swapChain, covariant FFIView view) async {
    _viewMappings[view] = swapChain;
    if (!_views.containsKey(swapChain)) {
      _views[swapChain] = [];
    }
    _views[swapChain]!.add(view);
  }

  final _hooks = <Future Function()>[];

  ///
  ///
  ///
  @override
  Future registerRequestFrameHook(Future Function() hook) async {
    if (!_hooks.contains(hook)) {
      _hooks.add(hook);
    }
  }

  ///
  ///
  ///
  @override
  Future unregisterRequestFrameHook(Future Function() hook) async {
    if (_hooks.contains(hook)) {
      _hooks.remove(hook);
    }
  }

  ///
  ///
  ///
  @override
  Future requestFrame() async {
    for (final hook in _hooks) {
      await hook.call();
    }
    final completer = Completer();

    final callback = NativeCallable<Void Function()>.listener(() {
      completer.complete(true);
    });

    RenderLoop_requestAnimationFrame(callback.nativeFunction.cast());

    try {
      await completer.future.timeout(Duration(seconds: 1));
    } catch (err) {
      print("WARNING - render call timed out");
    }
  }

  ///
  ///
  ///
  @override
  Future setParent(ThermionEntity child, ThermionEntity? parent,
      {bool preserveScaling = false}) async {
    TransformManager_setParent(transformManager, child,
        parent ?? FILAMENT_ENTITY_NULL, preserveScaling);
  }

  ///
  ///
  ///
  @override
  Future<ThermionEntity?> getParent(ThermionEntity child) async {
    var parent = TransformManager_getParent(transformManager, child);
    if (parent == FILAMENT_ASSET_ERROR) {
      return null;
    }
    return parent;
  }

  ///
  ///
  ///
  @override
  Future<ThermionEntity?> getAncestor(ThermionEntity child) async {
    var parent = TransformManager_getAncestor(transformManager, child);
    if (parent == FILAMENT_ASSET_ERROR) {
      return null;
    }
    return parent;
  }

  ///
  ///
  ///
  @override
  String? getNameForEntity(ThermionEntity entity) {
    final result = NameComponentManager_getName(nameComponentManager, entity);
    if (result == nullptr) {
      return null;
    }
    return result.cast<Utf8>().toDartString();
  }

  Material? _imageMaterial;

  ///
  ///
  ///
  @override
  Future<MaterialInstance> createImageMaterialInstance() async {
    _imageMaterial ??= FFIMaterial(Material_createImageMaterial(engine),
        FilamentApp.instance! as FFIFilamentApp);
    var instance =
        await _imageMaterial!.createInstance() as FFIMaterialInstance;
    return instance;
  }
}

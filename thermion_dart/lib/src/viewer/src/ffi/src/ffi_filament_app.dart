import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:thermion_dart/src/filament/src/engine.dart';
import 'package:thermion_dart/src/filament/src/scene.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/callbacks.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_asset.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_gizmo.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_material.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_render_target.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_scene.dart';
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
  final Pointer<TRenderer> renderer;
  final Pointer<TTransformManager> transformManager;
  final Pointer<TLightManager> lightManager;
  final Pointer<TRenderableManager> renderableManager;
  final Pointer<TMaterialProvider> ubershaderMaterialProvider;
  final Pointer<TRenderTicker> renderTicker;
  final Pointer<TNameComponentManager> nameComponentManager;

  final Future<Uint8List> Function(String uri) resourceLoader;

  FFIFilamentApp(
      this.engine,
      this.gltfAssetLoader,
      this.renderer,
      this.transformManager,
      this.lightManager,
      this.renderableManager,
      this.ubershaderMaterialProvider,
      this.renderTicker,
      this.nameComponentManager,
      this.resourceLoader)
      : super(
            engine: engine,
            gltfAssetLoader: gltfAssetLoader,
            renderer: renderer,
            transformManager: transformManager,
            lightManager: lightManager,
            renderableManager: renderableManager,
            ubershaderMaterialProvider: ubershaderMaterialProvider) {}

  static Future<Uint8List> _defaultResourceLoader(String path) {
    print("Loading file $path");
    return File(path).readAsBytes();
  }

  static Future create({FFIFilamentConfig? config}) async {
    config ??= FFIFilamentConfig(resourceLoader: _defaultResourceLoader);
    if (FilamentApp.instance != null) {
      await FilamentApp.instance!.destroy();
    }

    RenderThread_destroy();
    RenderThread_create();

    final engine = await withPointerCallback<TEngine>((cb) =>
        Engine_createRenderThread(
            TBackend.values[config!.backend.index].index,
            config.platform ?? nullptr,
            config.sharedContext ?? nullptr,
            config.stereoscopicEyeCount,
            config.disableHandleUseAfterFreeCheck,
            cb));

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

    RenderThread_setRenderTicker(renderTicker);

    final nameComponentManager = NameComponentManager_create();

    FilamentApp.instance = FFIFilamentApp(
        engine,
        gltfAssetLoader,
        renderer,
        transformManager,
        lightManager,
        renderableManager,
        ubershaderMaterialProvider,
        renderTicker,
        nameComponentManager,
        config.resourceLoader);
  }

  final _swapChains = <FFISwapChain, List<FFIView>>{};
  final viewsPtr = calloc<Pointer<TView>>(255);

  ///
  ///
  ///
  Future updateRenderOrder() async {
    for (final swapChain in _swapChains.keys) {
      final views = _swapChains[swapChain];
      if (views == null) {
        continue;
      }

      int numRenderable = 0;
      for (final view in views) {
        if (view.renderable) {
          viewsPtr[numRenderable] = view.view;
          numRenderable++;
        }
      }
      RenderTicker_setRenderable(
          renderTicker, swapChain.swapChain, viewsPtr, numRenderable);
    }
  }

  @override
  Future<SwapChain> createHeadlessSwapChain(int width, int height,
      {bool hasStencilBuffer = false}) async {
    var flags = TSWAP_CHAIN_CONFIG_TRANSPARENT | TSWAP_CHAIN_CONFIG_READABLE;
    if (hasStencilBuffer) {
      flags |= TSWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER;
    }
    print("swapchain flags $flags");
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
  Future<View> createView() async {
    final view = await FFIView(
        await withPointerCallback<TView>(
            (cb) => Engine_createViewRenderThread(engine, cb)),
        this);
    await view.setFrustumCullingEnabled(true);
    View_setBlendMode(view.view, TBlendMode.TRANSLUCENT);
    View_setShadowsEnabled(view.view, false);
    View_setStencilBufferEnabled(view.view, false);
    View_setAntiAliasing(view.view, false, false, false);
    View_setDitheringEnabled(view.view, false);
    View_setRenderQuality(view.view, TQualityLevel.MEDIUM);
    return view;
  }

  Future<Scene> createScene() async {
    return FFIScene(Engine_createScene(engine));
  }

  ///
  ///
  ///
  Future destroySwapChain(SwapChain swapChain) async {
    await withVoidCallback((callback) {
      Engine_destroySwapChainRenderThread(
          engine, (swapChain as FFISwapChain).swapChain, callback);
    });
    _swapChains.remove(swapChain);
  }

  ///
  ///
  ///
  @override
  Future destroy() async {
    for (final swapChain in _swapChains.keys) {
      if (_swapChains[swapChain] == null) {
        continue;
      }
      for (final view in _swapChains[swapChain]!) {
        await view.setRenderable(false);
      }
    }
    for (final swapChain in _swapChains.keys.toList()) {
      await destroySwapChain(swapChain);
    }
    await withVoidCallback((cb) async {
      Engine_destroyRenderThread(engine, cb);
    });

    RenderThread_destroy();
    RenderTicker_destroy(renderTicker);

    calloc.free(viewsPtr);
  }

  ///
  ///
  ///
  Future destroyAsset(covariant FFIAsset asset) async {
    await withVoidCallback(
        (cb) => SceneAsset_destroyRenderThread(asset.asset, cb));
  }

  ///
  ///
  ///
  Future<RenderTarget> createRenderTarget(int width, int height,
      {covariant FFITexture? color, covariant FFITexture? depth}) async {
    if (color == null) {
      color = await createTexture(width, height,
          flags: {
            TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
            TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
            TextureUsage.TEXTURE_USAGE_BLIT_SRC
          },
          textureFormat: TextureFormat.RGBA8) as FFITexture;
    }
    if (depth == null) {
      depth = await createTexture(width, height,
          flags: {
            TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
            TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT
          },
          textureFormat: TextureFormat.DEPTH32F) as FFITexture;
    }
    final renderTarget = await withPointerCallback<TRenderTarget>((cb) {
      RenderTarget_createRenderThread(
          engine, width, height, color!.pointer, depth!.pointer, cb);
    });
    if (renderTarget == nullptr) {
      throw Exception("Failed to create RenderTarget");
    }

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
      engine,
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
      Engine_buildMaterialRenderThread(engine, data.address, data.length, cb);
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
    // await withVoidCallback(
    //     (cb) => RenderTicker_renderRenderThread(renderTicker, 0, cb));
    final swapchain = _swapChains.keys.first;
    final view = _swapChains[swapchain]!.first;
    await withBoolCallback((cb) {
      Renderer_beginFrameRenderThread(renderer, swapchain.swapChain, 0, cb);
    });
    await withVoidCallback((cb) {
      Renderer_renderRenderThread(
        renderer,
        view.view,
        cb,
      );
    });

    await withVoidCallback((cb) {
      Renderer_endFrameRenderThread(renderer, cb);
    });
  }

  ///
  ///
  ///
  @override
  Future register(
      covariant FFISwapChain swapChain, covariant FFIView view) async {
    if (!_swapChains.containsKey(swapChain)) {
      _swapChains[swapChain] = [];
    }
    _swapChains[swapChain]!.add(view);
    _swapChains[swapChain]!
        .sort((a, b) => a.renderOrder.compareTo(b.renderOrder));
    await updateRenderOrder();
  }

  ///
  ///
  ///
  @override
  Future unregister(
      covariant FFISwapChain swapChain, covariant FFIView view) async {
    if (!_swapChains.containsKey(swapChain)) {
      _swapChains[swapChain] = [];
    }
    _swapChains[swapChain]!.remove(view);
    _swapChains[swapChain]!
        .sort((a, b) => a.renderOrder.compareTo(b.renderOrder));
    await updateRenderOrder();
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

    RenderThread_requestAnimationFrame(callback.nativeFunction.cast());

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
    if (_imageMaterial == null) {
      var ptr = await withPointerCallback<TMaterial>(
          (cb) => Material_createImageMaterialRenderThread(engine, cb));
      _imageMaterial =
          FFIMaterial(ptr, FilamentApp.instance! as FFIFilamentApp);
    }
    var instance =
        await _imageMaterial!.createInstance() as FFIMaterialInstance;
    return instance;
  }

  ///
  ///
  ///
  Future<List<(View, Uint8List)>> capture(covariant FFISwapChain swapChain,
      {covariant FFIView? view,
      bool captureRenderTarget = false,
      PixelDataFormat pixelDataFormat = PixelDataFormat.RGBA,
      PixelDataType pixelDataType = PixelDataType.FLOAT,
      Future Function(View)? beforeRender}) async {
    await updateRenderOrder();

    await withBoolCallback((cb) {
      Renderer_beginFrameRenderThread(renderer, swapChain.swapChain, 0, cb);
    });
    final views = <FFIView>[];
    if (view != null) {
      views.add(view);
    } else {
      views.addAll(_swapChains[swapChain]!);
    }

    final pixelBuffers = <(View, Uint8List)>[];

    for (final view in views) {
      beforeRender?.call(view);

      final viewport = await view.getViewport();
      final pixelBuffer =
          Uint8List(viewport.width * viewport.height * 4 * sizeOf<Float>());
      await withVoidCallback((cb) {
        Renderer_renderRenderThread(
          renderer,
          view.view,
          cb,
        );
      });

      if (captureRenderTarget && view.renderTarget == null) {
        throw Exception();
      }
      await withVoidCallback((cb) {
        Renderer_readPixelsRenderThread(
            renderer,
            view.view,
            view.renderTarget == null
                ? nullptr
                : view.renderTarget!.renderTarget,
            // TPixelDataFormat.PIXELDATAFORMAT_RGBA,
            // TPixelDataType.PIXELDATATYPE_UBYTE,
            pixelDataFormat.value,
            pixelDataType.value,
            pixelBuffer.address,
            pixelBuffer.length,
            cb);
      });
      pixelBuffers.add((view, pixelBuffer));
    }

    await withVoidCallback((cb) {
      Renderer_endFrameRenderThread(renderer, cb);
    });

    await withVoidCallback((cb) {
      Engine_flushAndWaitRenderThead(engine, cb);
    });
    return pixelBuffers;
  }

  ///
  ///
  ///
  Future setClearOptions(double r, double g, double b, double a,
      {int clearStencil = 0, bool discard = false, bool clear = true}) async {
    Renderer_setClearOptions(
        renderer, r, g, b, a, clearStencil, clear, discard);
  }

  ///
  ///
  ///
  Future<ThermionAsset> loadGltfFromBuffer(
      Uint8List data, Pointer animationManager,
      {int numInstances = 1,
      bool keepData = false,
      int priority = 4,
      int layer = 0,
      String? relativeResourcePath,
      bool loadResourcesAsync = false}) async {
    if (relativeResourcePath != null && !relativeResourcePath.endsWith("/")) {
      relativeResourcePath = "$relativeResourcePath/";
    }
    var gltfResourceLoader = await withPointerCallback<TGltfResourceLoader>(
        (cb) => GltfResourceLoader_createRenderThread(engine,
            relativeResourcePath?.toNativeUtf8().cast<Char>() ?? nullptr, cb));

    var filamentAsset = await withPointerCallback<TFilamentAsset>((cb) =>
        GltfAssetLoader_loadRenderThread(engine, gltfAssetLoader, data.address,
            data.length, numInstances, cb));

    if (filamentAsset == nullptr) {
      throw Exception("An error occurred loading the asset");
    }

    var resourceUris = FilamentAsset_getResourceUris(filamentAsset);
    var resourceUriCount = FilamentAsset_getResourceUriCount(filamentAsset);
    final resources = <FinalizableUint8List>[];

    for (int i = 0; i < resourceUriCount; i++) {
      final resourceUriDart = resourceUris[i].cast<Utf8>().toDartString();
      final resourceData = await resourceLoader(relativeResourcePath == null
          ? resourceUriDart
          : "$relativeResourcePath/$resourceUriDart");

      resources.add(FinalizableUint8List(resourceUris[i], resourceData));

      await withVoidCallback((cb) =>
          GltfResourceLoader_addResourceDataRenderThread(
              gltfResourceLoader,
              resourceUris[i],
              resourceData.address,
              resourceData.lengthInBytes,
              cb));
    }
    if (loadResourcesAsync) {
      // GltfResourceLoader_asyncBeginLoad(gltfResourceLoader)
      throw UnimplementedError(
          "TODO"); // need to use a NativeFinalizer to ensure the pointer is still valid until resource loader has finished
    } else {
      final result = await withBoolCallback((cb) =>
          GltfResourceLoader_loadResourcesRenderThread(
              gltfResourceLoader, filamentAsset, cb));
      if (!result) {
        throw Exception("Failed to load resources");
      }
    }

    final asset = await withPointerCallback<TSceneAsset>((cb) =>
        SceneAsset_createFromFilamentAssetRenderThread(
            engine, gltfAssetLoader, nameComponentManager, filamentAsset, cb));

    await withVoidCallback((cb) =>
        GltfResourceLoader_destroyRenderThread(engine, gltfResourceLoader, cb));
    return FFIAsset(asset, this, animationManager.cast<TAnimationManager>());
  }

  Future destroyView(covariant FFIView view) async {
    View_setColorGrading(view.view, nullptr);
    for (final cg in view.colorGrading.entries) {
      await withVoidCallback(
          (cb) => Engine_destroyColorGradingRenderThread(engine, cg.value, cb));
    }
    await withVoidCallback(
        (cb) => Engine_destroyViewRenderThread(engine, view.view, cb));
  }

  Future destroyScene(covariant FFIScene scene) async {
    await withVoidCallback(
        (cb) => Engine_destroySceneRenderThread(engine, scene.scene, cb));
  }

  Future<Pointer<TColorGrading>> createColorGrading(ToneMapper mapper) async {
    return withPointerCallback<TColorGrading>((cb) =>
        ColorGrading_createRenderThread(
            engine, TToneMapping.values[mapper.index], cb));
  }

  FFIMaterial? _gizmoMaterial;

  ///
  ///
  ///
  Future<GizmoAsset> createGizmo(covariant FFIView view,
      Pointer animationManager, GizmoType gizmoType) async {
    if (_gizmoMaterial == null) {
      final materialPtr = await withPointerCallback<TMaterial>((cb) {
        Material_createGizmoMaterialRenderThread(engine, cb);
      });
      _gizmoMaterial ??= FFIMaterial(materialPtr, this);
    }

    var gltfResourceLoader = await withPointerCallback<TGltfResourceLoader>(
        (cb) => GltfResourceLoader_createRenderThread(engine, nullptr, cb));

    final gizmo = await withPointerCallback<TGizmo>((cb) {
      Gizmo_createRenderThread(
          engine,
          gltfAssetLoader,
          gltfResourceLoader,
          nameComponentManager,
          view.view,
          _gizmoMaterial!.pointer,
          TGizmoType.values[gizmoType.index],
          cb);
    });
    if (gizmo == nullptr) {
      throw Exception("Failed to create gizmo");
    }
    final gizmoEntityCount =
        SceneAsset_getChildEntityCount(gizmo.cast<TSceneAsset>());
    final gizmoEntities = Int32List(gizmoEntityCount);
    SceneAsset_getChildEntities(
        gizmo.cast<TSceneAsset>(), gizmoEntities.address);

    return FFIGizmo(gizmo.cast<TSceneAsset>(), this,
        animationManager.cast<TAnimationManager>(),
        view: view,
        entities: gizmoEntities.toSet()
          ..add(SceneAsset_getEntity(gizmo.cast<TSceneAsset>())));
  }

  ///
  ///
  ///
  @override
  Future<ThermionAsset> createGeometry(
      Geometry geometry, Pointer animationManager,
      {List<MaterialInstance>? materialInstances,
      bool keepData = false,
      bool addToScene = true}) async {
    var assetPtr = await withPointerCallback<TSceneAsset>((callback) {
      var ptrList = Int64List(materialInstances?.length ?? 0);
      if (materialInstances != null && materialInstances.isNotEmpty) {
        ptrList.setRange(
            0,
            materialInstances.length,
            materialInstances
                .cast<FFIMaterialInstance>()
                .map((mi) => mi.pointer.address)
                .toList());
      }

      return SceneAsset_createGeometryRenderThread(
          engine,
          geometry.vertices.address,
          geometry.vertices.length,
          geometry.normals.address,
          geometry.normals.length,
          geometry.uvs.address,
          geometry.uvs.length,
          geometry.indices.address,
          geometry.indices.length,
          geometry.primitiveType.index,
          ptrList.address.cast<Pointer<TMaterialInstance>>(),
          ptrList.length,
          callback);
    });
    if (assetPtr == nullptr) {
      throw Exception("Failed to create geometry");
    }

    return FFIAsset(assetPtr, this, animationManager.cast<TAnimationManager>());
  }

  ///
  ///
  ///
  Future flush() async {
    await withVoidCallback((cb) => Engine_flushAndWaitRenderThead(engine, cb));
  }
}

class FinalizableUint8List implements Finalizable {
  final Pointer name;
  final Uint8List data;

  FinalizableUint8List(this.name, this.data);
}

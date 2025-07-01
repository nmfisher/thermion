import 'dart:async';
import 'package:thermion_dart/src/filament/src/implementation/ffi_camera.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_skybox.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_gizmo.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_swapchain.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/src/filament/src/interface/skybox.dart';
import 'package:thermion_dart/src/utils/src/matrix.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:logging/logging.dart';
import 'resource_loader.dart';

typedef RenderCallback = Pointer<NativeFunction<Void Function(Pointer<Void>)>>;

class FFIFilamentConfig extends FilamentConfig<RenderCallback, Pointer<Void>> {
  FFIFilamentConfig(
      {super.loadResource = null,
      super.backend = Backend.DEFAULT,
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

  late final Future<Uint8List> Function(String uri) _loadResource;

  static final _logger = Logger("FFIFilamentApp");

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
      Future<Uint8List> Function(String uri)? loadResource) {
    this._loadResource = loadResource ?? defaultResourceLoader;
  }

  Future<Uint8List> loadResource(String uri) {
    return _loadResource(uri);
  }

  static Future create({FFIFilamentConfig? config}) async {
    config ??= FFIFilamentConfig();

    if (FilamentApp.instance != null) {
      await FilamentApp.instance!.destroy();
    }

    RenderThread_destroy();
    RenderThread_create();

    final engine = await withPointerCallback<TEngine>((cb) =>
        Engine_createRenderThread(
            config!.backend.value,
            config.platform ?? nullptr,
            config.sharedContext ?? nullptr,
            config.stereoscopicEyeCount,
            config.disableHandleUseAfterFreeCheck,
            cb));
    final featureLevel = Engine_getSupportedFeatureLevel(engine);
    _logger.info("Created engine with feature level ${featureLevel}");
    final nameComponentManager = NameComponentManager_create();
    final gltfAssetLoader = await withPointerCallback<TGltfAssetLoader>((cb) =>
        GltfAssetLoader_createRenderThread(
            engine, nullptr, nameComponentManager, cb));
    final renderer = await withPointerCallback<TRenderer>(
        (cb) => Engine_createRendererRenderThread(engine, cb));
    final ubershaderMaterialProvider =
        GltfAssetLoader_getMaterialProvider(gltfAssetLoader);

    final transformManager = Engine_getTransformManager(engine);
    final lightManager = Engine_getLightManager(engine);
    final renderableManager = Engine_getRenderableManager(engine);

    final renderTicker = RenderTicker_create(engine, renderer);

    RenderThread_setRenderTicker(renderTicker);

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
        config.loadResource);
    _logger.info("Initialization complete");
  }

  final _swapChains = <FFISwapChain, List<FFIView>>{};
  late Pointer<PointerClass<TView>> viewsPtr =
      allocate<PointerClass>(255).cast();

  ///
  ///
  ///
  Future updateRenderOrder() async {
    _logger.info("updateRenderOrder");
    if (_swapChains.length == 0) {
      _logger.warning("No swapchains, ignoring updateRenderOrder");
    }
    for (final swapChain in _swapChains.keys) {
      final views = _swapChains[swapChain];
      if (views == null) {
        _logger.info("No views found for swapchain $swapChain");
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
          renderTicker, swapChain.getNativeHandle(), viewsPtr, numRenderable);
      _logger.info("Updated render order, $numRenderable renderable views");
    }
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
  Future<View> createView() async {
    final view = await FFIView(
        await withPointerCallback<TView>(
            (cb) => Engine_createViewRenderThread(engine, cb)),
        this);
    await view.setFrustumCullingEnabled(true);
    await view.setBloom(false, 0.0);
    await view.setBlendMode(BlendMode.transparent);
    await view.setShadowsEnabled(false);
    await view.setStencilBufferEnabled(false);
    await view.setAntiAliasing(false, false, false);
    await view.setDithering(false);
    await view.setRenderQuality(QualityLevel.MEDIUM);
    return view;
  }

  ///
  ///
  ///
  Future<Scene> createScene() async {
    return FFIScene(Engine_createScene(engine));
  }

  ///
  ///
  ///
  Future<Camera> createCamera() async {
    return FFICamera(
        await withPointerCallback<TCamera>(
            (cb) => Engine_createCameraRenderThread(engine, cb)),
        this);
  }

  ///
  ///
  ///
  Future destroySwapChain(SwapChain swapChain) async {
    _logger.info("Destroying swapchain");
    RenderTicker_removeSwapChain(renderTicker, swapChain.getNativeHandle());
    await withVoidCallback((requestId, callback) {
      Engine_destroySwapChainRenderThread(
          engine, swapChain.getNativeHandle(), requestId, callback);
    });
    _swapChains.remove(swapChain);
    _logger.info("Destroyed swapchain");
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
    await withVoidCallback((requestId, cb) async {
      Engine_destroyRenderThread(engine, requestId, cb);
    });

    RenderThread_destroy();
    RenderTicker_destroy(renderTicker);

    free(viewsPtr);
    FilamentApp.instance = null;
    for (final callback in _onDestroy) {
      await callback.call();
    }

    _onDestroy.clear();
  }

  /// If [asset] is actually an instance (i.e. was created via createInstance),
  /// its resources may not actually be destroyed until the parent asset is
  /// destroyed. It may be marked as unused, and recycled the next time
  /// createInstance is called.
  ///
  ///
  Future destroyAsset(covariant FFIAsset asset) async {
    await asset.removeAnimationComponent();
    if (!asset.isInstance) {
      for (final instance in (await asset.getInstances()).cast<FFIAsset>()) {
        await instance.removeAnimationComponent();
        await withVoidCallback((requestId, cb) =>
            SceneAsset_destroyRenderThread(instance.asset, requestId, cb));
        await instance.dispose();
      }
    }

    await withVoidCallback((requestId, cb) =>
        SceneAsset_destroyRenderThread(asset.asset, requestId, cb));
    await asset.dispose();
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
            TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT,
            TextureUsage.TEXTURE_USAGE_BLIT_SRC,
          },
          textureFormat: TextureFormat.DEPTH24_STENCIL8) as FFITexture;
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
          textureSamplerType.index,
          textureFormat.index,
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
    TextureSampler_setMinFilter(samplerPtr, minFilter.index);
    TextureSampler_setMagFilter(samplerPtr, magFilter.index);
    TextureSampler_setWrapModeS(samplerPtr, wrapS.index);
    TextureSampler_setWrapModeT(samplerPtr, wrapT.index);
    TextureSampler_setWrapModeR(samplerPtr, wrapR.index);
    if (anisotropy > 0) {
      TextureSampler_setAnisotropy(samplerPtr, anisotropy);
    }

    TextureSampler_setCompareMode(
        samplerPtr, compareMode.index, compareFunc.index);

    return FFITextureSampler(samplerPtr);
  }

  /// Decodes the image data into a native LinearImage (floating point).
  /// If [requireAlpha] is true, the decoded image will always contain an
  /// alpha channel (even if the original image did not contain one).
  ///
  Future<LinearImage> decodeImage(Uint8List data,
      {String name = "image", bool requireAlpha = false}) async {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      //stackPtr = stackSave();
    }
    var now = DateTime.now();

    var ptr = Image_decode(data.address, data.length,
        name.toNativeUtf8().cast<Char>(), requireAlpha);

    var finished = DateTime.now();
    print(
      "Image_decode (render thread) finished in ${finished.millisecondsSinceEpoch - now.millisecondsSinceEpoch}ms",
    );

    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
      data.free();
    }
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
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      //stackPtr = stackSave();
    }
    var ptr = await withPointerCallback<TMaterial>((cb) {
      Engine_buildMaterialRenderThread(engine, data.address, data.length, cb);
    });
    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
      data.free();
    }
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
      bool hasSpecularGlossiness = false,
      int specularGlossinessUV = 0,
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
    final materialInstance = await withPointerCallback<TMaterialInstance>((cb) {
      MaterialProvider_createMaterialInstanceRenderThread(
          ubershaderMaterialProvider,
          doubleSided,
          unlit,
          hasVertexColors,
          hasBaseColorTexture,
          hasNormalTexture,
          hasOcclusionTexture,
          hasEmissiveTexture,
          useSpecularGlossiness,
          alphaMode.index,
          enableDiagnostics,
          hasMetallicRoughnessTexture,
          metallicRoughnessUV,
          hasSpecularGlossiness,
          specularGlossinessUV,
          baseColorUV,
          hasClearCoatTexture,
          clearCoatUV,
          hasClearCoatRoughnessTexture,
          clearCoatRoughnessUV,
          hasClearCoatNormalTexture,
          clearCoatNormalUV,
          hasClearCoat,
          hasTransmission,
          hasTextureTransforms,
          emissiveUV,
          aoUV,
          normalUV,
          hasTransmissionTexture,
          transmissionUV,
          hasSheenColorTexture,
          sheenColorUV,
          hasSheenRoughnessTexture,
          sheenRoughnessUV,
          hasVolumeThicknessTexture,
          volumeThicknessUV,
          hasSheen,
          hasIOR,
          hasVolume,
          cb);
    });

    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
    }
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
  Future setMaterialInstanceAt(ThermionEntity entity, int index,
      MaterialInstance materialInstance) async {
    RenderableManager_setMaterialInstanceAt(renderableManager, entity, index,
        (materialInstance as FFIMaterialInstance).pointer);
  }

  ///
  ///
  ///
  @override
  Future render() async {
    final swapchain = _swapChains.keys.first;
    final view = _swapChains[swapchain]!.first;
    await withBoolCallback((cb) {
      Renderer_beginFrameRenderThread(
          renderer, swapchain.getNativeHandle(), 0.toBigInt, cb);
    });
    await withVoidCallback((requestId, cb) {
      Renderer_renderRenderThread(
        renderer,
        view.view,
        requestId,
        cb,
      );
    });
    await withVoidCallback((requestId, cb) {
      Renderer_endFrameRenderThread(renderer, requestId, cb);
    });

    await flush();
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

  ///
  ///
  ///
  Future<Iterable<SwapChain>> getSwapChains() async {
    return _swapChains.keys;
  }

  final _hooks = <Future Function()>[];

  ///
  ///
  ///
  @override
  Future registerRequestFrameHook(Future Function() hook) async {
    while (_requesting) {
      await Future.delayed(Duration(milliseconds: 1));
    }
    if (!_hooks.contains(hook)) {
      _hooks.add(hook);
    }
  }

  ///
  ///
  ///
  @override
  Future unregisterRequestFrameHook(Future Function() hook) async {
    while (_requesting) {
      await Future.delayed(Duration(milliseconds: 1));
    }
    if (_hooks.contains(hook)) {
      _hooks.remove(hook);
    }
  }

  bool _requesting = false;

  ///
  ///
  ///
  @override
  Future requestFrame() async {
    _requesting = true;
    try {
      for (final hook in _hooks) {
        await hook.call();
      }
    } catch (err) {
      _logger.severe(err);
    }
    _requesting = false;
    RenderThread_requestFrameAsync();
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
  Future<List<(View, Uint8List)>> capture(covariant FFISwapChain? swapChain,
      {covariant FFIView? view,
      bool captureRenderTarget = false,
      PixelDataFormat pixelDataFormat = PixelDataFormat.RGBA,
      PixelDataType pixelDataType = PixelDataType.FLOAT,
      Future Function(View)? beforeRender}) async {
    if (swapChain == null) {
      if (_swapChains.isEmpty) {
        throw Exception("No swapchains registered");
      }
      if (_swapChains.length > 1) {
        throw Exception(
            "When multiple swapchains have been registered, you must pass the swapchain you wish to capture.");
      }
      swapChain = _swapChains.keys.first;
    }
    await updateRenderOrder();

    final beginFrame = await withBoolCallback((cb) {
      Renderer_beginFrameRenderThread(
          renderer, swapChain!.getNativeHandle(), 0.toBigInt, cb);
    });

    final pixelBuffers = <(View, Uint8List)>[];

    final views = <FFIView>[];
    if (view != null) {
      views.add(view);
    } else {
      views.addAll(_swapChains[swapChain]!.where((v) => v.renderable));
    }

    if (beginFrame) {
      _logger.info("Capturing ${views.length} views");

      for (final view in views) {
        beforeRender?.call(view);

        final viewport = await view.getViewport();

        int numChannels = switch (pixelDataFormat) {
          PixelDataFormat.RGBA => 4,
          PixelDataFormat.RGB => 3,
          _ => throw UnsupportedError(pixelDataFormat.toString())
        };

        int channelSizeInBytes = switch (pixelDataType) {
          PixelDataType.FLOAT => sizeOf<Float>(),
          PixelDataType.UBYTE || PixelDataType.BYTE => 1,
          _ => throw UnsupportedError(pixelDataFormat.toString())
        };

        final pixelBuffer = makeUint8List(viewport.width *
            viewport.height *
            numChannels *
            channelSizeInBytes);
        await withVoidCallback((requestId, cb) {
          Renderer_renderRenderThread(
            renderer,
            view.view,
            requestId,
            cb,
          );
        });

        if (captureRenderTarget && view.renderTarget == null) {
          throw Exception();
        }
        await withVoidCallback((requestId, cb) {
          Renderer_readPixelsRenderThread(
              renderer,
              view.view,
              view.renderTarget == null
                  ? nullptr
                  : view.renderTarget!.renderTarget,
              pixelDataFormat.value,
              pixelDataType.value,
              pixelBuffer.address,
              pixelBuffer.length,
              requestId,
              cb);
        });
        pixelBuffers.add((view, pixelBuffer));
      }
    } else {
      _logger.severe("beginFrame returned false");
    }

    await withVoidCallback((requestId, cb) {
      Renderer_endFrameRenderThread(renderer, requestId, cb);
    });

    await flush();

    // on web/WebGL backend, the callback in readPixels isn't actually
    // fired until a subsequent render call (and possibly the presentation to the
    // canvas when the render thread yields).
    // We need to wait at least one frame before the pixel buffer is populated;
    // by this point, we've called setRendering(true), but this is actually
    // synchronous, so we'll add a ~2 frame delay to wait for this to be available.
    if (FILAMENT_SINGLE_THREADED) {
      await withBoolCallback((cb) => Renderer_beginFrameRenderThread(
          renderer, swapChain!.getNativeHandle(), 0.toBigInt, cb));
      for (final view in views) {
        await withVoidCallback((requestId, cb) {
          Renderer_renderRenderThread(
            renderer,
            view.view,
            requestId,
            cb,
          );
        });
      }
      await withVoidCallback((requestId, cb) {
        Renderer_endFrameRenderThread(renderer, requestId, cb);
      });
      await flush();

      await Future.delayed(Duration(milliseconds: 33));

      // now copy the pixel buffer into a GC'd Uint8List and destroy the manually
      // allocated buffer so invokers don't have to worry about taking ownership
      // of malloc memory
      return pixelBuffers.map((element) {
        final wrapped = (element.$1, Uint8List.fromList(element.$2));
        element.$2.free();
        return wrapped;
      }).toList();
    }

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
      {int initialInstances = 1,
      bool keepData = false,
      int priority = 4,
      int layer = 0,
      bool loadResourcesAsync = false,
      String? resourceUri}) async {
    final resources = <FinalizableUint8List>[];

    if (resourceUri != null && !resourceUri.endsWith("/")) {
      resourceUri = "${resourceUri}/";
    }
    try {
      late Pointer stackPtr;
      if (FILAMENT_WASM) {
        //stackPtr = stackSave();
      }

      loadResourcesAsync = FILAMENT_SINGLE_THREADED;

      var gltfResourceLoader = await withPointerCallback<TGltfResourceLoader>(
          (cb) => GltfResourceLoader_createRenderThread(engine, cb));

      var filamentAsset = await withPointerCallback<TFilamentAsset>((cb) =>
          GltfAssetLoader_loadRenderThread(engine, gltfAssetLoader,
              data.address, data.length, initialInstances, cb));

      if (filamentAsset == nullptr) {
        throw Exception("An error occurred loading the asset");
      }

      var resourceUris = FilamentAsset_getResourceUris(filamentAsset);
      var resourceUriCount = FilamentAsset_getResourceUriCount(filamentAsset);

      for (int i = 0; i < resourceUriCount; i++) {
        final resourceUriDart = resourceUris[i].cast<Utf8>().toDartString();

        final resourceData =
            await loadResource("${resourceUri ?? ""}${resourceUriDart}");

        resources.add(FinalizableUint8List(resourceUris[i], resourceData));

        await withVoidCallback((requestId, cb) =>
            GltfResourceLoader_addResourceDataRenderThread(
                gltfResourceLoader,
                resourceUris[i],
                resourceData.address,
                resourceData.lengthInBytes,
                requestId,
                cb));
      }

      if (loadResourcesAsync) {
        final result = await withBoolCallback((cb) =>
            GltfResourceLoader_asyncBeginLoadRenderThread(
                gltfResourceLoader, filamentAsset, cb));
        if (!result) {
          throw Exception("Failed to begin async loading");
        }

        GltfResourceLoader_asyncUpdateLoadRenderThread(gltfResourceLoader);

        var progress = await withFloatCallback((cb) =>
            GltfResourceLoader_asyncGetLoadProgressRenderThread(
                gltfResourceLoader, cb));
        while (progress < 1.0) {
          GltfResourceLoader_asyncUpdateLoadRenderThread(gltfResourceLoader);
          progress = await withFloatCallback((cb) =>
              GltfResourceLoader_asyncGetLoadProgressRenderThread(
                  gltfResourceLoader, cb));
        }
      } else {
        final result = await withBoolCallback((cb) =>
            GltfResourceLoader_loadResourcesRenderThread(
                gltfResourceLoader, filamentAsset, cb));
        if (!result) {
          throw Exception("Failed to load resources");
        }
      }

      final asset = await withPointerCallback<TSceneAsset>((cb) =>
          SceneAsset_createFromFilamentAssetRenderThread(engine,
              gltfAssetLoader, nameComponentManager, filamentAsset, cb));

      if (asset == nullptr) {
        throw Exception(
            "Unknown error loading glTF asset. See logs for details.");
      }

      await withVoidCallback((requestId, cb) =>
          GltfResourceLoader_destroyRenderThread(
              engine, gltfResourceLoader, requestId, cb));

      return FFIAsset(asset, this, animationManager.cast<TAnimationManager>(),
          keepData: keepData);
    } finally {
      if (FILAMENT_WASM) {
        //stackRestore(stackPtr);
        data.free();
        for (final resource in resources) {
          resource.data.free();
        }
      }
    }
  }

  Future destroyView(covariant FFIView view) async {
    View_setColorGrading(view.view, nullptr);
    for (final cg in view.colorGrading.entries) {
      await withVoidCallback((requestId, cb) =>
          Engine_destroyColorGradingRenderThread(
              engine, cg.value, requestId, cb));
    }
    await withVoidCallback((requestId, cb) =>
        Engine_destroyViewRenderThread(engine, view.view, requestId, cb));
    for (final swapchain in _swapChains.keys) {
      if (_swapChains[swapchain]!.contains(view)) {
        _swapChains[swapchain]!.remove(view);
        continue;
      }
    }
    await view.dispose();
  }

  Future destroyScene(covariant FFIScene scene) async {
    await withVoidCallback((requestId, cb) =>
        Engine_destroySceneRenderThread(engine, scene.scene, requestId, cb));
  }

  Future<Pointer<TColorGrading>> createColorGrading(ToneMapper mapper) async {
    return withPointerCallback<TColorGrading>(
        (cb) => ColorGrading_createRenderThread(engine, mapper.index, cb));
  }

  FFIMaterial? _gizmoMaterial;

  ///
  ///
  ///
  Future<GizmoAsset> createGizmo(covariant FFIView view,
      Pointer animationManager, GizmoType gizmoType) async {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      //stackPtr = stackSave();
    }

    if (_gizmoMaterial == null) {
      final materialPtr = await withPointerCallback<TMaterial>((cb) {
        Material_createGizmoMaterialRenderThread(engine, cb);
      });
      _gizmoMaterial ??= FFIMaterial(materialPtr, this);
    }

    var gltfResourceLoader = await withPointerCallback<TGltfResourceLoader>(
        (cb) => GltfResourceLoader_createRenderThread(engine, cb));

    final gizmo = await withPointerCallback<TGizmo>((cb) {
      Gizmo_createRenderThread(
          engine,
          gltfAssetLoader,
          gltfResourceLoader,
          nameComponentManager,
          view.view,
          _gizmoMaterial!.pointer,
          gizmoType.index,
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

    final gizmoAsset = FFIGizmo(gizmo.cast<TSceneAsset>(), this,
        animationManager.cast<TAnimationManager>(),
        view: view,
        entities: gizmoEntities.toSet()
          ..add(SceneAsset_getEntity(gizmo.cast<TSceneAsset>())));
    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
      gizmoEntities.free();
    }

    return gizmoAsset;
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
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      //stackPtr = stackSave();
    }

    final ptrList = IntPtrList(materialInstances?.length ?? 0);
    if (materialInstances != null) {
      ptrList.setRange(
          0,
          materialInstances.length,
          materialInstances
              .cast<FFIMaterialInstance>()
              .map((mi) => mi.pointer.address)
              .toList());
    }

    var assetPtr = await withPointerCallback<TSceneAsset>((callback) {
      var ptr = SceneAsset_createGeometryRenderThread(
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
          ptrList.address.cast(),
          ptrList.length ?? 0,
          callback);
      return ptr;
    });

    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
      ptrList.free();
      geometry.vertices.free();
      geometry.normals.free();
      geometry.uvs.free();
    }

    if (assetPtr == nullptr) {
      throw Exception("Failed to create geometry");
    }

    return FFIAsset(assetPtr, this, animationManager.cast<TAnimationManager>(),
        keepData: keepData);
  }

  ///
  ///
  ///
  Future<ThermionEntity> createDirectLight(DirectLight directLight) async {
    var entity =
        LightManager_createLight(engine, lightManager, directLight.type.index);
    if (entity == FILAMENT_ASSET_ERROR) {
      throw Exception("Failed to add light to scene");
    }

    LightManager_setColor(lightManager, entity, directLight.color);
    LightManager_setIntensity(lightManager, entity, directLight.intensity);
    LightManager_setPosition(lightManager, entity, directLight.position.x,
        directLight.position.y, directLight.position.z);
    LightManager_setDirection(lightManager, entity, directLight.direction.x,
        directLight.direction.y, directLight.direction.z);
    LightManager_setFalloff(lightManager, entity, directLight.falloffRadius);
    LightManager_setSpotLightCone(lightManager, entity,
        directLight.spotLightConeInner, directLight.spotLightConeOuter);
    // LightManager_setSunAngularRadius(lightManager, entity, directLight.spotLightConeInner, directLight.spotLightConeOuter);
    // LightManager_setSunHaloSize(lightManager, entity, directLight.spotLightConeInner, directLight.spotLightConeOuter);
    // LightManager_setSunHaloFalloff(lightManager, entity, directLight.spotLightConeInner, directLight.spotLightConeOuter);
    LightManager_setShadowCaster(lightManager, entity, directLight.castShadows);
    return entity;
  }

  ///
  ///
  ///
  Future flush() async {
    if (FILAMENT_SINGLE_THREADED) {
      await withVoidCallback(
          (requestId, cb) => Engine_executeRenderThread(engine, requestId, cb));
    } else {
      await withVoidCallback((requestId, cb) =>
          Engine_flushAndWaitRenderThread(engine, requestId, cb));
    }
  }

  final _onDestroy = <Future Function()>[];

  ///
  ///
  ///
  void onDestroy(Future Function() callback) {
    _onDestroy.add(callback);
  }

  ///
  ///
  ///
  Future<ThermionEntity> createEntity(
      {bool createTransformComponent = true}) async {
    final entity = EntityManager_createEntity(Engine_getEntityManager(engine));
    if (createTransformComponent) {
      TransformManager_createComponent(transformManager, entity);
    }
    return entity;
  }

  ///
  ///
  ///
  Future setTransform(ThermionEntity entity, Matrix4 transform) async {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }
    TransformManager_setTransform(
        transformManager, entity, matrix4ToDouble4x4(transform));
    if (FILAMENT_WASM) {
      stackRestore(stackPtr);
    }
  }

  ///
  ///
  ///
  Future<Matrix4> getWorldTransform(ThermionEntity entity) async {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }

    var transform = double4x4ToMatrix4(
        TransformManager_getWorldTransform(transformManager, entity));
    if (FILAMENT_WASM) {
      stackRestore(stackPtr);
    }
    return transform;
  }

  ///
  ///
  ///
  @override
  Future setPriority(ThermionEntity entity, int priority) async {
    RenderableManager_setPriority(renderableManager, entity, priority);
  }

  ///
  ///
  ///
  Future<int> getPrimitiveCount(ThermionEntity entity) async {
    return RenderableManager_getPrimitiveCount(renderableManager, entity);
  }

  ///
  ///
  ///
  Future<Aabb3> getBoundingBox(ThermionEntity entity) async {
    final bb = RenderableManager_getBoundingBox(renderableManager, entity);
    return Aabb3.centerAndHalfExtents(
        Vector3(bb.centerX, bb.centerY, bb.centerZ),
        Vector3(bb.halfExtentX, bb.halfExtentY, bb.halfExtentZ));
  }

  /// Builds an (empty) [Skybox] instance. This will not be attached to any scene until
  /// [setSkybox] is called.
  ///
  Future<Skybox> buildSkybox({Texture? texture = null}) async {
    final ptr = await withPointerCallback<TSkybox>((cb) {
      Engine_buildSkyboxRenderThread(
        engine,
        (texture as FFITexture?)?.pointer ?? nullptr,
        cb,
      );
    });
    return FFISkybox(ptr);
  }
}

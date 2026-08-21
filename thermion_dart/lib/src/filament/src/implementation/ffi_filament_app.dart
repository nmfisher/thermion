import 'dart:async';
import 'dart:math' as math;

import 'package:thermion_dart/src/filament/src/implementation/ffi_render_manager.dart';
import 'package:thermion_dart/src/filament/src/interface/render_manager.dart';

import '../../../bindings/bindings.dart' as bindings;

import 'package:thermion_dart/src/filament/src/implementation/ffi_animation_manager.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_camera.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_debug_registry.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_index_buffer.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_light_manager.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_renderable_manager.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_surface_orientation.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_transform_manager.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_skybox.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_textured_quad.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_vertex_buffer.dart';
import 'package:thermion_dart/src/filament/src/interface/scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_asset.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_gizmo.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_material.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_render_target.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_scene.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_swapchain.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_view.dart';
import 'package:thermion_dart/src/filament/src/interface/surface_orientation.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:logging/logging.dart';
import 'ffi_gltf_mesh_data.dart';
import 'resource_loader.dart';

class FFIFilamentConfig extends FilamentConfig {
  FFIFilamentConfig({
    super.loadResource = null,
    super.backend = Backend.DEFAULT,
    super.platform = null,
    super.sharedContext = null,
    super.uberArchivePath = null,
  });
}

class FFIFilamentApp extends FilamentApp<Pointer> {
  final Pointer<TEngine> engine;
  final Pointer<TGltfAssetLoader> gltfAssetLoader;
  Pointer<TRenderer> renderer;

  final Pointer<Void> renderThreadHandle;

  final Pointer<TMaterialProvider> ubershaderMaterialProvider;

  final Pointer<TNameComponentManager> nameComponentManager;

  late final Future<Uint8List> Function(String uri) _loadResource;
  late final FFILightManager lightManager;
  late final FFIRenderableManager renderableManager;
  late final FFITransformManager transformManager;
  late final FFIAnimationManager animationManager;
  late final RenderManager renderManager;

  static final _logger = Logger("FFIFilamentApp");

  FFIFilamentApp(
    this.engine,
    this.gltfAssetLoader,
    this.renderer,
    Pointer<TTransformManager> transformManagerPtr,
    this.ubershaderMaterialProvider,
    Pointer<TRenderManager> renderManager,
    this.renderThreadHandle,
    this.nameComponentManager,
    Future<Uint8List> Function(String uri)? loadResource,
    Pointer<TLightManager> lightManagerPointer,
    Pointer<TRenderableManager> renderableManagerPointer,
    Pointer<TAnimationManager> animationManagerPointer,
  ) {
    this._loadResource = loadResource ?? defaultResourceLoader;
    this.lightManager = FFILightManager(lightManagerPointer, this);
    this.renderableManager = FFIRenderableManager(renderableManagerPointer, this);
    this.transformManager = FFITransformManager(transformManagerPtr, this);
    this.animationManager = FFIAnimationManager(animationManagerPointer, this);
    this.renderManager = FFIRenderManager(renderManager, this);

    // A new engine starts uncapped. Scheduler stop/start within this engine
    // preserves later user changes, but a cap from an older hot-restarted
    // engine must not leak into this one.
    bindings.FrameScheduler_setTargetFps(0);
  }

  //
  int getMaxAutomaticInstances() {
    return Engine_getMaxAutomaticInstances(engine);
  }

  void setAutomaticInstancingEnabled(bool enabled) {
    Engine_setAutomaticInstancingEnabled(engine, enabled);
  }

  Future<Uint8List> loadResource(String uri) {
    return _loadResource(uri);
  }

  @override
  DebugRegistry getDebugRegistry() {
    final debugRegistryPtr = Engine_getDebugRegistry(engine);
    return FFIDebugRegistry(debugRegistryPtr);
  }

  static Future create({FFIFilamentConfig? config, String? canvasSelector, bool destroyExisting = true}) async {
    config ??= FFIFilamentConfig();

    // Multi-engine web (engine per viewer) creates additional engines while
    // an existing one is still rendering. destroyExisting: false leaves the
    // current app untouched — the caller owns it (the web plugin's per-viewer
    // bundle) and must NOT have it torn down underneath its render loop.
    if (destroyExisting && FilamentApp.instance != null) {
      await FilamentApp.instance!.destroy();
    }

    // Web multi-viewer: each engine gets its own RenderThread, which
    // transfers its own canvas element to the worker. The selector is the
    // CSS id of that viewer's canvas; native passes null and gets the
    // default thread.
    RenderThread_destroy(nullptr);
    late final Pointer<Void> renderThreadHandle;
    if (canvasSelector != null) {
      final selectorPtr = canvasSelector.toNativeUtf8().cast<Char>();
      renderThreadHandle = RenderThread_createForCanvas(selectorPtr);
      free(selectorPtr);
    } else {
      renderThreadHandle = RenderThread_create();
    }

    if (renderThreadHandle == nullptr) {
      throw Exception("Failed to create render thread");
    }

    final engine = await withPointerCallback<TEngine>(
      (cb) => Engine_createRenderThread(
        config!.backend.value,
        config.platform ?? nullptr,
        config.sharedContext ?? nullptr,
        config.stereoscopicEyeCount,
        config.disableHandleUseAfterFreeCheck,
        cb,
      ),
    ).timeout(Duration(seconds: 30));
    // 30 second timeout is just for CI purposes,
    // in a live Dart app this should return immediately.

    if (engine == nullptr) {
      throw Exception("Failed to create engine");
    }

    final featureLevel = Engine_getSupportedFeatureLevel(engine);
    _logger.info("Created engine with feature level ${featureLevel}");

    final nameComponentManager = NameComponentManager_create();

    final gltfAssetLoader = await withPointerCallback<TGltfAssetLoader>(
      (cb) => GltfAssetLoader_createRenderThread(engine, nullptr, nameComponentManager, cb),
    );

    final renderer = await withPointerCallback<TRenderer>((cb) => Engine_createRendererRenderThread(engine, cb));
    final ubershaderMaterialProvider = GltfAssetLoader_getMaterialProvider(gltfAssetLoader);

    final transformManager = Engine_getTransformManager(engine);
    final lightManager = Engine_getLightManager(engine);
    final renderableManager = Engine_getRenderableManager(engine);

    final renderManager = RenderManager_create(engine, renderer);

    // On web, rendering is driven by the RenderThread's rAF mainLoop via
    // RenderManager::tick(). Wire the two together; no-op on native.
    RenderManager_attachToRenderThread(renderManager);

    final animationManager = await withPointerCallback<TAnimationManager>(
      (cb) => AnimationManager_createRenderThread(engine, cb),
    );

    await withVoidCallback(
      (requestId, cb) => RenderManager_addAnimationManagerRenderThread(renderManager, animationManager, requestId, cb),
    );

    FilamentApp.instance = FFIFilamentApp(
      engine,
      gltfAssetLoader,
      renderer,
      transformManager,
      ubershaderMaterialProvider,
      renderManager,
      renderThreadHandle,
      nameComponentManager,
      config.loadResource,
      lightManager,
      renderableManager,
      animationManager,
    );

    _logger.info("Initialization complete");
  }

  @override
  Future<SwapChain> createHeadlessSwapChain(
    int width,
    int height, {
    bool hasStencilBuffer = false,
    bool isMacOS = false,
  }) async {
    var flags = TSWAP_CHAIN_CONFIG_TRANSPARENT | TSWAP_CHAIN_CONFIG_READABLE;

    if (hasStencilBuffer) {
      flags |= TSWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER;
    }

    if (isMacOS) {
      flags |= TSWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER;
    }

    final swapChain = await withPointerCallback<TSwapChain>(
      (cb) => Engine_createHeadlessSwapChainRenderThread(this.engine, width, height, flags, cb),
    );
    final sc = FFISwapChain(swapChain, this);
    _swapChains.add(sc);
    return sc;
  }

  //
  @override
  Future<SwapChain> createSwapChain(Pointer window, {bool hasStencilBuffer = false}) async {
    var flags = TSWAP_CHAIN_CONFIG_TRANSPARENT | TSWAP_CHAIN_CONFIG_READABLE;
    if (hasStencilBuffer) {
      flags |= TSWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER;
    }
    final swapChain = await withPointerCallback<TSwapChain>(
      (cb) => Engine_createSwapChainRenderThread(this.engine, window.cast<Void>(), flags, cb),
    );
    _logger.info("Created swapchain from window");
    final sc = FFISwapChain(swapChain, this);
    _swapChains.add(sc);
    return sc;
  }

  //
  Future<View> createView({bool createScene = false}) async {
    final view = await FFIView.create(this);
    await view.setName("unnamed_view");
    await view.setFrustumCullingEnabled(true);
    await view.setBloom(false, 0.0);
    await view.setBlendMode(BlendMode.transparent);
    await view.setShadowsEnabled(false);
    await view.setStencilBufferEnabled(false);
    await view.setAntiAliasing(false, false, false);
    await view.setDithering(false);
    await view.setRenderQuality(QualityLevel.MEDIUM);

    if (createScene) {
      final scene = await this.createScene();
      await view.setScene(scene);
    }
    return view;
  }

  //
  Future<Scene> createScene() async {
    return FFIScene(Engine_createScene(engine), this);
  }

  //
  Future<Camera> createCamera({ThermionEntity? targetEntity}) async {
    targetEntity ??= await createEntity(createTransformComponent: false);
    return FFICamera(
      await withPointerCallback<TCamera>((cb) => Engine_createCameraRenderThread(engine, targetEntity!, cb)),
      this,
    );
  }

  /// Serial chain that prevents multiple `destroySwapChain` calls
  /// from running concurrently. Each call awaits `_destroyChain`,
  /// runs detach + flush + destroy + bookkeeping, then completes the
  /// chain so the next destroy can start.
  ///
  /// Why: in multi-viewer apps, mass dispose (e.g. toggling stress-
  /// test viewer count from 8 → 1) triggers eight concurrent
  /// destroySwapChain calls. Each call's flush() drains the backend
  /// at the moment it runs — but if other concurrent destroys are
  /// queueing new commands on the backend at the same time, no
  /// individual flush guarantees the backend is empty afterwards.
  /// Filament's internal Renderer mSwapChain state can end up
  /// pointing at a SwapChain that another destroy is in the middle
  /// of freeing, tripping the `endFrame:490` precondition.
  ///
  /// Serialising destroys gives flush() a stable target: nothing
  /// else is queueing destroy work, so the flush truly drains and
  /// the synchronous engine->destroy can proceed safely.
  static Future<void> _destroyChain = Future.value();

  //
  Future destroySwapChain(SwapChain swapChain) async {
    final completer = Completer<void>();
    final prev = _destroyChain;
    _destroyChain = completer.future;
    await prev;
    try {
      _logger.info("Destroying swapchain");
      await renderManager.detachAll(swapChain);

      // Drain Filament's backend command queue before releasing the
      // SwapChain. `RenderManager::removeSwapChain` (called inside
      // detachAll) takes Thermion's render-manager mutex and finishes
      // synchronously, so no future RenderManager::render iteration
      // will touch this swap chain. But Filament has its own internal
      // command stream that processes BEGIN_FRAME / render / END_FRAME
      // on its backend thread, independently of Thermion's render
      // thread. If a frame's endFrame is still queued on that backend
      // when `engine->destroy(swapChain)` runs synchronously on our
      // thread, the SwapChain memory is freed before endFrame
      // executes — and Filament aborts at Renderer.cpp:490 with
      // "SwapChain must remain valid until endFrame is called."
      //
      // `flushAndWait()` blocks until the backend has processed every
      // command submitted up to this point. Combined with the destroy
      // serialisation above, this guarantees a quiet backend at the
      // moment we synchronously call engine->destroy.
      await flush();

      await withVoidCallback((requestId, callback) {
        Engine_destroySwapChainRenderThread(engine, swapChain.getNativeHandle(), requestId, callback);
      });

      _swapChains.remove(swapChain);
      _logger.info("Destroyed swapchain");
    } finally {
      completer.complete();
    }
  }

  // Destroys the specified entity. You must ensure that the entity has already
  // been detached (e.g. if renderable, it has been removed from any scenes,
  // that any camera or animation component has already been removed, etc).
  Future destroyEntity(ThermionEntity entity) async {
    if (renderableManager.hasComponent(entity)) {
      await withVoidCallback(
        (requestId, cb) =>
            RenderableManager_destroyEntityRenderThread(renderableManager.getNativeHandle(), entity, requestId, cb),
      );
    }
    if (transformManager.hasComponent(entity)) {
      await transformManager.removeComponent(entity);
    }
    await withVoidCallback(
      (requestId, cb) =>
          EntityManager_destroyEntityRenderThread(Engine_getEntityManager(engine), entity, requestId, cb),
    );
  }

  //
  @override
  Future destroy() async {
    for (final callback in _onBeforeDestroy) {
      await callback.call();
    }
    _onBeforeDestroy.clear();
    await drainRequestFrameHooks();

    for (final swapChain in _swapChains.toList()) {
      await renderManager.detachAll(swapChain);
      await destroySwapChain(swapChain);
    }

    FilamentApp.instance = null;
    // Detach the RenderManager from the worker pthread BEFORE deleting it.
    // The worker's mainLoop/iter() reads `mRenderManager` to drive ticks; once
    // we delete the RenderManager that pointer dangles, and the next iter()
    // crashes inside tick() — which is silent in release builds and leaves
    // the worker pthread effectively dead but with its mimalloc arena still
    // owned, so every subsequent FilamentApp.create() spawns a fresh worker
    // on top of the leaked one.
    RenderManager_detachFromRenderThread(renderManager.getNativeHandle());
    renderManager.destroy();

    // Filament's contract is: tear down everything created on top of the
    // Engine before destroying the Engine itself. Order matters — the
    // AssetLoader holds Engine-bound Materials (via its internally-created
    // ubershader MaterialProvider), the AnimationManager wraps gltfio
    // animators bound to the Engine, and NameComponentManager is standalone.
    await withVoidCallback(
      (requestId, cb) => AnimationManager_destroyRenderThread((animationManager).animationManager, requestId, cb),
    );
    await withVoidCallback((requestId, cb) => GltfAssetLoader_destroyRenderThread(gltfAssetLoader, requestId, cb));
    NameComponentManager_destroy(nameComponentManager);

    await withVoidCallback((requestId, cb) => Engine_destroyRendererRenderThread(engine, renderer, requestId, cb));
    await withVoidCallback((requestId, cb) async {
      Engine_destroyRenderThread(engine, requestId, cb);
    });

    RenderThread_destroy(renderThreadHandle);
    for (final callback in _onDestroy) {
      await callback.call();
    }

    _onDestroy.clear();
  }

  // If [asset] is actually an instance (i.e. was created via createInstance),
  // its resources may not actually be destroyed until the parent asset is
  // destroyed. It may be marked as unused, and recycled the next time
  // createInstance is called.
  Future destroyAsset(covariant FFIAsset asset) async {
    await asset.removeAnimationComponent();
    if (!asset.isInstance) {
      for (final instance in (await asset.getInstances()).cast<FFIAsset>()) {
        await instance.removeAnimationComponent();
        await withVoidCallback((requestId, cb) => SceneAsset_destroyRenderThread(instance.asset, requestId, cb));
        await instance.dispose();
      }
    }

    await withVoidCallback((requestId, cb) => SceneAsset_destroyRenderThread(asset.asset, requestId, cb));
    await asset.dispose();
  }

  //
  Future<RenderTarget> createRenderTarget(int width, int height, {Texture? color, Texture? depth}) async {
    _logger.finest("Creating ${width}x${height} render target");
    if (color == null) {
      _logger.finest("No color texture provided");
      color =
          await createTexture(
                width,
                height,
                flags: {
                  TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
                  TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
                  TextureUsage.TEXTURE_USAGE_BLIT_SRC,
                },
                textureFormat: TextureFormat.RGBA8,
              )
              as FFITexture;
      _logger.finest("Created ${width}x${height} color texture (TextureFormat.RGBA8)");
    }
    if (depth == null) {
      _logger.finest("No depth texture provided");
      depth =
          await createTexture(
                width,
                height,
                flags: {
                  TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
                  TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT,
                  TextureUsage.TEXTURE_USAGE_BLIT_SRC,
                },
                textureFormat: TextureFormat.DEPTH32F,
              )
              as FFITexture;
      _logger.finest("Created ${width}x${height} depth texture (TextureFormat.DEPTH32F)");
    }
    final renderTarget = await withPointerCallback<TRenderTarget>((cb) {
      RenderTarget_createRenderThread(engine, color!.getNativeHandle(), depth!.getNativeHandle(), cb);
    });
    if (renderTarget == nullptr) {
      throw Exception("Failed to create RenderTarget");
    }

    return FFIRenderTarget(renderTarget, this);
  }

  //
  Future<Texture> createTexture(
    int width,
    int height, {
    int depth = 1,
    int levels = 1,
    Set<TextureUsage> flags = const {TextureUsage.TEXTURE_USAGE_SAMPLEABLE, TextureUsage.TEXTURE_USAGE_UPLOADABLE},
    TextureSamplerType textureSamplerType = TextureSamplerType.SAMPLER_2D,
    TextureFormat textureFormat = TextureFormat.RGBA16F,
    int? importedTextureHandle,
  }) async {
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
        cb,
      );
    });
    if (texturePtr == nullptr) {
      throw Exception("Failed to create texture");
    }
    return FFITexture(engine, texturePtr, this);
  }

  Future<void> setExternalImage(Texture texture, int externalImagePtr) async {
    final ffiTexture = texture as FFITexture;
    await withVoidCallback((requestId, cb) {
      Texture_setExternalImageRenderThread(
        engine,
        ffiTexture.pointer,
        Pointer<Void>.fromAddress(externalImagePtr),
        requestId,
        cb,
      );
    });
  }

  //
  Future<TextureSampler> createTextureSampler({
    TextureMinFilter minFilter = TextureMinFilter.LINEAR,
    TextureMagFilter magFilter = TextureMagFilter.LINEAR,
    TextureWrapMode wrapS = TextureWrapMode.CLAMP_TO_EDGE,
    TextureWrapMode wrapT = TextureWrapMode.CLAMP_TO_EDGE,
    TextureWrapMode wrapR = TextureWrapMode.CLAMP_TO_EDGE,
    double anisotropy = 0.0,
    TextureCompareMode compareMode = TextureCompareMode.NONE,
    TextureCompareFunc compareFunc = TextureCompareFunc.LESS_EQUAL,
  }) async {
    final samplerPtr = TextureSampler_create();
    TextureSampler_setMinFilter(samplerPtr, minFilter.index);
    TextureSampler_setMagFilter(samplerPtr, magFilter.index);
    TextureSampler_setWrapModeS(samplerPtr, wrapS.index);
    TextureSampler_setWrapModeT(samplerPtr, wrapT.index);
    TextureSampler_setWrapModeR(samplerPtr, wrapR.index);
    if (anisotropy > 0) {
      TextureSampler_setAnisotropy(samplerPtr, anisotropy);
    }

    TextureSampler_setCompareMode(samplerPtr, compareMode.index, compareFunc.index);

    return FFITextureSampler(samplerPtr);
  }

  // Decodes the image data into a native LinearImage (floating point).
  // If [requireAlpha] is true, the decoded image will always contain an
  // alpha channel (even if the original image did not contain one).
  //
  Future<LinearImage> decodeImage(Uint8List data, {String name = "image", bool requireAlpha = false}) async {
    var now = DateTime.now();
    final namePtr = name.toNativeUtf8().cast<Char>();
    var ptr = Image_decode(data.address, data.length, namePtr, requireAlpha);
    free(namePtr);

    var finished = DateTime.now();
    final elapsed = finished.millisecondsSinceEpoch - now.millisecondsSinceEpoch;
    print("Image_decode (render thread) finished in $elapsed ms");

    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
      data.free();
    }
    if (ptr == nullptr) {
      throw Exception("Failed to decode image");
    }
    return FFILinearImage(ptr);
  }

  //
  // Creates an (empty) imge with the given dimensions.
  //
  Future<LinearImage> createImage(int width, int height, int channels) async {
    final ptr = Image_createEmpty(width, height, channels);
    return FFILinearImage(ptr);
  }

  @override
  Future<Material> createGizmoMaterial() async {
    _gizmoMaterial ??= FFIMaterial(
      await withPointerCallback<TMaterial>((cb) {
        Material_createGizmoMaterialRenderThread(engine, cb);
      }),
      this,
    );
    return _gizmoMaterial!;
  }

  FFIMaterial? _gizmoMaterial;

  FFIMaterial? _boneOverlayMaterial;

  @override
  Future<Material> createBoneOverlayMaterial() async {
    _boneOverlayMaterial ??= FFIMaterial(
      await withPointerCallback<TMaterial>((cb) {
        Material_createBoneOverlayMaterialRenderThread(engine, cb);
      }),
      this,
    );
    return _boneOverlayMaterial!;
  }

  //
  Future<Material> createMaterial(Uint8List data) async {
    var ptr = await withPointerCallback<TMaterial>((cb) {
      Engine_buildMaterialRenderThread(engine, data.address, data.length, cb);
    });
    if (FILAMENT_WASM) {
      data.free();
    }
    return FFIMaterial(ptr, this);
  }

  //
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
    bool hasVolume = false,
  }) async {
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
        cb,
      );
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

  //
  Future<MaterialInstance> createUnlitMaterialInstance() async {
    return createUbershaderMaterialInstance(unlit: true, hasVertexColors: false);
  }

  @override
  Future<WireframeMaterialInstance> createWireframeMaterialInstance() async {
    final material = FFIMaterial(
      await withPointerCallback<TMaterial>((cb) {
        Material_createWireframeMaterialRenderThread(engine, cb);
      }),
      this,
    );
    final mi = await material.createInstance();
    return WireframeMaterialInstance(mi);
  }

  //
  Future<MaterialInstance> getMaterialInstanceAt(ThermionEntity entity, int index) async {
    final instance = await renderableManager.getMaterialInstanceAt(entity, index);
    if (instance == null) {
      throw Exception("No material instance at index $index");
    }
    return instance;
  }

  //
  Future setMaterialInstanceAt(ThermionEntity entity, int index, MaterialInstance materialInstance) async {
    await renderableManager.setMaterialInstanceAt(entity, index, materialInstance);
  }

  final _swapChains = <SwapChain>[];

  //
  Future<Iterable<SwapChain>> getSwapChains() async {
    // Return a snapshot, not the live list. Returning the live list lets
    // mutations from concurrent createSwapChain / destroySwapChain calls
    // leak back to callers — which is exactly what happened in
    // thermion_flutter's Android `createTextureAndBindToView`:
    //
    //   final swapChains = await FilamentApp.instance!.getSwapChains();
    //   final swapChain  = await FilamentApp.instance!.createSwapChain(...);
    //   if (swapChains.isNotEmpty) {
    //     await FilamentApp.instance!.destroySwapChain(swapChains.first);
    //   }
    //
    // The intent was "snapshot existing chains, create the new one,
    // tear down the old one", but `swapChains` aliased `_swapChains`,
    // so after `createSwapChain` appended, `swapChains.first` was the
    // *new* swap chain. The plugin then destroyed it and attached the
    // view to a freed pointer — the next render hit Filament's
    // "SwapChain must remain valid until endFrame is called" assert
    // and the process aborted on every viewer mount on Android.
    //
    // Returning an unmodifiable snapshot fixes this at the API layer
    // and makes the function safe regardless of how callers are
    // structured.
    return List<SwapChain>.unmodifiable(_swapChains);
  }

  final _hooks = <Future Function()>[];

  //
  @override
  Future registerRequestFrameHook(Future Function() hook) async {
    while (_processingRenderHooks) {
      await Future.delayed(Duration(milliseconds: 1));
    }
    if (!_hooks.contains(hook)) {
      _hooks.add(hook);
    }
  }

  //
  @override
  Future unregisterRequestFrameHook(Future Function() hook) async {
    while (_processingRenderHooks) {
      await Future.delayed(Duration(milliseconds: 1));
    }
    if (_hooks.contains(hook)) {
      _hooks.remove(hook);
    }
  }

  bool _processingRenderHooks = false;

  /// Waits for any request-frame hook that is already running.
  Future<void> drainRequestFrameHooks() async {
    while (_processingRenderHooks) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  //
  @override
  Future render() async {
    _processingRenderHooks = true;
    try {
      for (final hook in _hooks) {
        await hook.call();
      }
    } catch (err) {
      _logger.severe(err);
    }
    _processingRenderHooks = false;

    await renderManager.render();
  }

  int _targetFramerate = 0;

  /// The process-wide render-loop cap requested through [setTargetFramerate].
  /// A value of zero means unlimited. Used by the web rAF scheduler; native
  /// platforms keep the authoritative value in FrameSchedulerApi.cpp.
  int get targetFramerate => _targetFramerate;

  //
  @override
  void setTargetFramerate(int fps) {
    _targetFramerate = fps > 0 ? fps : 0;
    // Native platforms pace both display-link dispatch and Linux's
    // Flutter-synced request-render path. Web reads [targetFramerate] from its
    // requestAnimationFrame loop.
    bindings.FrameScheduler_setTargetFps(_targetFramerate);
  }

  //
  @override
  Future setParent(ThermionEntity child, ThermionEntity? parent, {bool preserveScaling = false}) async {
    transformManager.setParent(child, parent ?? FILAMENT_ENTITY_NULL, preserveScaling: preserveScaling);
  }

  //
  @override
  Future<ThermionEntity?> getParent(ThermionEntity child) async {
    var parent = transformManager.getParent(child);
    if (parent == FILAMENT_ASSET_ERROR) {
      return null;
    }
    return parent;
  }

  //
  @override
  Future<ThermionEntity?> getAncestor(ThermionEntity child) async {
    var parent = transformManager.getAncestor(child);
    if (parent == FILAMENT_ASSET_ERROR) {
      return null;
    }
    return parent;
  }

  //
  @override
  String? getNameForEntity(ThermionEntity entity) {
    final result = NameComponentManager_getName(nameComponentManager, entity);
    if (result == nullptr) {
      return null;
    }
    return result.cast<Utf8>().toDartString();
  }

  Material? _imageMaterial;

  //
  Future<List<(View, Uint8List)>> capture(
    SwapChain? swapChain, {
    View? view,
    bool captureRenderTarget = false,
    PixelDataFormat pixelDataFormat = PixelDataFormat.RGBA,
    PixelDataType pixelDataType = PixelDataType.FLOAT,
    Future Function(View)? beforeRender,
    bool render = true,
  }) async {
    // Web: the worker rAF loop (RenderManager::tick) drives begin/render/end on
    // the *shared* Renderer. If it fires between our beginFrame() and the
    // swapchain readPixels() below, it ends the frame and clears the active
    // SwapChain, tripping Filament's "readPixels() ... must be called after
    // beginFrame() and before endFrame()" precondition. Pause ticking across
    // the critical section and resume it in the finally.
    final pauseTicking = FILAMENT_SINGLE_THREADED;
    if (pauseTicking) {
      RenderManager_setPaused(renderManager.getNativeHandle(), true);
      await Future.delayed(Duration(milliseconds: 17)); // TODO - replace this
    }

    if (swapChain == null) {
      if (_swapChains.isEmpty) {
        throw Exception("No swapchains registered");
      }
      if (_swapChains.length > 1) {
        throw Exception(
          """When multiple swapchains have been registered, """
          """you must pass the swapchain you wish to capture.""",
        );
      }
      swapChain = _swapChains.first;
    }
    var beginFrame = false;
    const MAX_BEGIN_FRAME_RETRIES = 3;

    for (int i = 0; i < MAX_BEGIN_FRAME_RETRIES; i++) {
      beginFrame = await withBoolCallback((cb) {
        Renderer_beginFrameRenderThread(renderer, swapChain!.getNativeHandle(), 0.toBigInt, cb);
      });
      if (beginFrame) {
        break;
      }
    }

    if (!beginFrame) {
      if (pauseTicking) {
        RenderManager_setPaused(renderManager.getNativeHandle(), false);
      }
      throw Exception("Failed to begin frame");
    }

    final pixelBuffers = <(View, Uint8List)>[];

    final views = <View>[];
    if (view != null) {
      views.add(view);
      _logger.finest("Using provided view");
    } else {
      views.addAll(await renderManager.getAttachedViews(swapChain));
    }

    for (final view in views) {
      final vp = await view.getViewport();
      if (vp.width == 0 || vp.height == 0) {
        throw Exception(
          """Invalid viewport : ${vp.width}x${vp.height} """
          """for ${view.getNativeHandle()}""",
        );
      }
    }

    _logger.finest("Starting capture for ${views.length} views");

    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      stackPtr = stackSave();
    }

    // Per-view "was this read as UBYTE for a FLOAT request?" flags. The
    // downgrade-on-web rule depends on the framebuffer being read from
    // (RGBA8 swapchain/RT → must use UBYTE; FLOAT RT → must use FLOAT),
    // so we compute it per-view and inflate back to FLOAT in the return.
    final inflateFromUByte = <bool>[];

    for (var viewIndex = 0; viewIndex < views.length; viewIndex++) {
      final view = views[viewIndex];
      final renderTarget = await view.getRenderTarget();
      bool hasRenderTarget = renderTarget != null;
      _logger.finest(
        """Capturing view ${viewIndex} (renderTarget: """
        """${hasRenderTarget ? 'yes' : 'no'})""",
      );

      // WebGL/ANGLE constrains the format/type combo for readPixels by the
      // bound framebuffer's color format:
      //   - RGBA8 (swapchain / RGBA8 RT)  → only UBYTE is allowed
      //   - FLOAT RT (RGBA16F / RGBA32F)  → only FLOAT is allowed
      // Read FLOAT requests from RGBA8 as UBYTE and inflate in the return so
      // callers still get the FLOAT buffer they asked for. Keep FLOAT when
      // the RT itself is FLOAT, otherwise WebGL throws INVALID_OPERATION.
      var rtIsFloat = false;
      if (renderTarget != null) {
        final colorTex = await renderTarget.getColorTexture();
        rtIsFloat = _isFloatTextureFormat(await colorTex.getFormat());
      }
      final readAsUByteForFloat = FILAMENT_SINGLE_THREADED && pixelDataType == PixelDataType.FLOAT && !rtIsFloat;
      final readType = readAsUByteForFloat ? PixelDataType.UBYTE : pixelDataType;
      inflateFromUByte.add(readAsUByteForFloat);

      beforeRender?.call(view);

      final viewport = await view.getViewport();

      int numChannels = switch (pixelDataFormat) {
        PixelDataFormat.RGBA => 4,
        PixelDataFormat.RGB => 3,
        PixelDataFormat.R => 1,
        _ => throw UnsupportedError(pixelDataFormat.toString()),
      };

      int channelSizeInBytes = switch (readType) {
        PixelDataType.FLOAT => sizeOf<Float>(),
        PixelDataType.UBYTE || PixelDataType.BYTE => 1,
        _ => throw UnsupportedError(readType.toString()),
      };

      if (viewport.width <= 0 || viewport.height <= 0) {
        throw Exception(
          "Invalid viewport dimensions: "
          "${viewport.width}x${viewport.height}",
        );
      }

      final numBytes = viewport.width * viewport.height * numChannels * channelSizeInBytes;
      final pixelBuffer = makeUint8List(numBytes);

      if (render) {
        await withVoidCallback((requestId, cb) {
          Renderer_renderRenderThread(renderer, view.getNativeHandle(), requestId, cb);
        });
      }

      if (captureRenderTarget && renderTarget == null) {
        _logger.warning(
          """captureRenderTarget is true but the specified view has no"""
          """ render target. Falling back to swapchain capture""",
        );
      }

      await withVoidCallback((requestId, cb) {
        Renderer_readPixelsRenderThread(
          renderer,
          viewport.width,
          viewport.height,
          0,
          0,
          renderTarget == null ? nullptr : renderTarget.getNativeHandle(),
          pixelDataFormat.value,
          readType.value,
          pixelBuffer.address,
          pixelBuffer.length,
          requestId,
          cb,
        );
      });
      pixelBuffers.add((view, pixelBuffer));
    }

    await withVoidCallback((requestId, cb) {
      Renderer_endFrameRenderThread(renderer, requestId, cb);
    });

    await flush();

    // on web/WebGL backend, the callback in readPixels isn't actually
    // fired until a subsequent render call (and possibly the presentation to
    // the canvas when the render thread yields).
    // We need to wait at least one frame before the pixel buffer is populated;
    // by this point, we've called setRendering(true), but this is actually
    // synchronous, so we'll add a ~2 frame delay to wait for this to be
    // available.
    if (FILAMENT_SINGLE_THREADED) {
      await withBoolCallback(
        (cb) => Renderer_beginFrameRenderThread(renderer, swapChain!.getNativeHandle(), 0.toBigInt, cb),
      );
      for (final view in views) {
        await withVoidCallback((requestId, cb) {
          Renderer_renderRenderThread(renderer, view.getNativeHandle(), requestId, cb);
        });
      }
      await withVoidCallback((requestId, cb) {
        Renderer_endFrameRenderThread(renderer, requestId, cb);
      });
      await flush();

      await Future.delayed(Duration(milliseconds: 33));

      // now copy the pixel buffer into a GC'd Uint8List and destroy the
      // manually allocated buffer so invokers don't have to worry about taking
      // ownership of malloc memory
      final result = <(View, Uint8List)>[];
      for (var i = 0; i < pixelBuffers.length; i++) {
        final (view, raw) = pixelBuffers[i];
        final Uint8List out;
        if (inflateFromUByte[i]) {
          // Inflate the 8-bit readback to the float buffer callers expect:
          // one float32 in [0,1] per source byte.
          final floats = Float32List(raw.length);
          for (var j = 0; j < raw.length; j++) {
            floats[j] = raw[j] / 255.0;
          }
          out = floats.buffer.asUint8List();
        } else {
          out = Uint8List.fromList(raw);
        }
        raw.free();
        result.add((view, out));
      }

      if (FILAMENT_WASM) {
        stackRestore(stackPtr);
      }
      return result;
    }

    if (pauseTicking) {
      RenderManager_setPaused(renderManager.getNativeHandle(), false);
    }

    return pixelBuffers;
  }

  //
  Future setClearOptions(
    double r,
    double g,
    double b,
    double a, {
    int clearStencil = 0,
    bool discard = false,
    bool clear = true,
  }) async {
    Renderer_setClearOptions(renderer, r, g, b, a, clearStencil, clear, discard);
  }

  //
  Future<ThermionAsset> loadGltfFromBuffer(
    Uint8List data, {
    int initialInstances = 1,
    bool releaseSourceData = false,
    bool loadResourcesAsync = false,
    bool rebuildVertices = false,
    String? resourceUri,
  }) async {
    if (initialInstances <= 0) {
      throw Exception("initialInstances must be at least 1");
    }
    _logger.info(
      "Loading glTF from buffer (${data.lengthInBytes} bytes)"
      " with resourceUri ${resourceUri}",
    );
    final resources = <FinalizableUint8List>[];

    if (resourceUri != null && !resourceUri.endsWith("/")) {
      resourceUri = "${resourceUri}/";
    }

    try {
      if (FILAMENT_SINGLE_THREADED) {
        loadResourcesAsync = true;
      }

      var gltfResourceLoader = await withPointerCallback<TGltfResourceLoader>(
        (cb) => GltfResourceLoader_createRenderThread(engine, cb),
      );

      var filamentAsset = await withPointerCallback<TFilamentAsset>(
        (cb) =>
            GltfAssetLoader_loadRenderThread(engine, gltfAssetLoader, data.address, data.length, initialInstances, cb),
      );

      if (filamentAsset == nullptr) {
        throw Exception("An error occurred loading the asset");
      }

      var resourceUris = FilamentAsset_getResourceUris(filamentAsset);
      var resourceUriCount = FilamentAsset_getResourceUriCount(filamentAsset);

      for (int i = 0; i < resourceUriCount; i++) {
        final resourceUriDart = resourceUris[i].cast<Utf8>().toDartString();

        // glTF URIs are percent-encoded (e.g. "City%20Atlas.png"), decode
        // for the filesystem so the OS file API finds the real filename.
        var resolvedResourceUri = "${resourceUri ?? ""}${Uri.decodeFull(resourceUriDart)}";

        final resourceData = await loadResource(resolvedResourceUri);

        _logger.info(
          """Adding ${resourceData.lengthInBytes} bytes """
          """for resource ${resourceUriDart} """
          """(resolved to $resolvedResourceUri)""",
        );

        resources.add(FinalizableUint8List(resourceUris[i], resourceData));

        await withVoidCallback(
          (requestId, cb) => GltfResourceLoader_addResourceDataRenderThread(
            gltfResourceLoader,
            resourceUris[i],
            resourceData.address,
            resourceData.lengthInBytes,
            requestId,
            cb,
          ),
        );
      }

      if (loadResourcesAsync) {
        final result = await withBoolCallback(
          (cb) => GltfResourceLoader_asyncBeginLoadRenderThread(gltfResourceLoader, filamentAsset, cb),
        );
        if (!result) {
          throw Exception("Failed to begin async loading");
        }

        GltfResourceLoader_asyncUpdateLoadRenderThread(gltfResourceLoader);

        var progress = await withFloatCallback(
          (cb) => GltfResourceLoader_asyncGetLoadProgressRenderThread(gltfResourceLoader, cb),
        );
        while (progress < 1.0) {
          GltfResourceLoader_asyncUpdateLoadRenderThread(gltfResourceLoader);
          progress = await withFloatCallback(
            (cb) => GltfResourceLoader_asyncGetLoadProgressRenderThread(gltfResourceLoader, cb),
          );
        }
      } else {
        _logger.info("Loading glTF resources synchronously");
        final result = await withBoolCallback(
          (cb) => GltfResourceLoader_loadResourcesRenderThread(gltfResourceLoader, filamentAsset, cb),
        );

        if (!result) {
          throw Exception("Failed to load resources");
        }
      }

      _logger.info("glTF resources loaded");

      final asset = await withPointerCallback<TSceneAsset>(
        (cb) => SceneAsset_createFromFilamentAssetRenderThread(
          engine,
          gltfAssetLoader,
          nameComponentManager,
          filamentAsset,
          rebuildVertices,
          cb,
        ),
      );

      if (asset == nullptr) {
        throw Exception("Unknown error loading glTF asset. See logs for details.");
      }

      await withVoidCallback(
        (requestId, cb) => GltfResourceLoader_destroyRenderThread(engine, gltfResourceLoader, requestId, cb),
      );

      final ffiAsset = FFIAsset(asset, app: this);
      if (releaseSourceData) {
        await ffiAsset.releaseSourceData();
      }
      return ffiAsset;
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

  Future destroyView(View view) async {
    await renderManager.detach(view);
    await (view as FFIView).destroy();
  }

  Future destroyScene(covariant FFIScene scene) async {
    await withVoidCallback((requestId, cb) => Engine_destroySceneRenderThread(engine, scene.scene, requestId, cb));
  }

  //
  Future<GizmoAsset> createGizmo(View view, GizmoType gizmoType) async {
    return FFIGizmo.create(this, view, gizmoType);
  }

  //
  @override
  Future<ThermionAsset> createGeometry(
    Geometry geometry, {
    List<MaterialInstance>? materialInstances,
    bool addToScene = true,
  }) async {
    // Build vertex buffer
    final vertexBufferBuilder = FFIVertexBufferBuilder(engine);
    vertexBufferBuilder.vertexCount(geometry.vertices.length ~/ 3);

    // Calculate buffer count - always include UV0 and COLOR like the native C++
    // code
    int bufferCount = 1; // Always have positions
    Float32List? tangentQuaternions;

    if (geometry.normals.length > 0) {
      bufferCount++;
      // Generate tangent space quaternions using SurfaceOrientationBuilder
      final orientationBuilder = FFISurfaceOrientationBuilder();
      orientationBuilder.vertexCount(geometry.vertices.length ~/ 3);
      orientationBuilder.positions(geometry.vertices);
      orientationBuilder.normals(geometry.normals);

      // Add UVs if available for better tangent generation
      if (geometry.uvs.isNotEmpty) {
        orientationBuilder.uvs(geometry.uvs);
      }

      // Set triangle indices
      orientationBuilder.triangleCount(geometry.indices.length ~/ 3);
      if (geometry.indexType == IndexType.UINT) {
        orientationBuilder.trianglesUint32(
          makeUint32List(geometry.indices.length)..setRange(0, geometry.indices.length, geometry.indices),
        );
      } else {
        orientationBuilder.trianglesUint16(
          makeUint16List(geometry.indices.length)..setRange(0, geometry.indices.length, geometry.indices),
        );
      }

      // Build the surface orientation
      final surfaceOrientation = await orientationBuilder.build();

      // Extract quaternions in FLOAT4 format
      tangentQuaternions =
          await surfaceOrientation.getQuats(QuaternionFormat.FLOAT4, geometry.vertices.length ~/ 3) as Float32List;

      await surfaceOrientation.destroy();
    }

    bufferCount++; // Always include UV0
    bufferCount++; // Always include UV1 (ubershader requires two UV sets)
    bufferCount++; // Always include COLOR

    if (geometry.hasAttribute0) {
      bufferCount++;
    }
    vertexBufferBuilder.bufferCount(bufferCount);

    // Position attribute (always present at buffer 0)
    vertexBufferBuilder.attribute(VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3);

    // Track current buffer index
    int currentBufferIndex = 1;

    // Tangents attribute (if normals were provided)
    if (tangentQuaternions != null) {
      vertexBufferBuilder.attribute(VertexAttribute.TANGENTS, currentBufferIndex, VertexAttributeType.FLOAT4);
      currentBufferIndex++;
    }

    // UV0 attribute (always present like the native C++ code)
    vertexBufferBuilder.attribute(VertexAttribute.UV0, currentBufferIndex, VertexAttributeType.FLOAT2);
    currentBufferIndex++;

    // UV1 attribute (ubershader requires two UV sets)
    vertexBufferBuilder.attribute(VertexAttribute.UV1, currentBufferIndex, VertexAttributeType.FLOAT2);
    currentBufferIndex++;

    // COLOR attribute (always present like the native C++ code)
    vertexBufferBuilder.attribute(VertexAttribute.COLOR, currentBufferIndex, VertexAttributeType.FLOAT4);
    currentBufferIndex++;

    if (geometry.hasAttribute0) {
      vertexBufferBuilder.attribute(VertexAttribute.CUSTOM0, currentBufferIndex, VertexAttributeType.FLOAT4);
    }

    final vertexBuffer = await vertexBufferBuilder.build() as FFIVertexBuffer;

    // Set vertex data - Position always at buffer 0
    await vertexBuffer.setBufferAt(0, geometry.vertices);

    // Reset buffer index for data population
    currentBufferIndex = 1;

    // Set tangent quaternion data (generated from normals)
    if (tangentQuaternions != null) {
      await vertexBuffer.setBufferAt(currentBufferIndex, tangentQuaternions);
      currentBufferIndex++;
    }

    // Set UV0 data (always present, use zeros if not provided)
    if (geometry.uvs.length > 0) {
      await vertexBuffer.setBufferAt(currentBufferIndex, geometry.uvs);
    }
    currentBufferIndex++;

    // Set UV1 data (always present for ubershader compatibility)
    if (geometry.uvs1.length > 0) {
      await vertexBuffer.setBufferAt(currentBufferIndex, geometry.uvs1);
    }
    currentBufferIndex++;

    if (geometry.colors.length > 0) {
      await vertexBuffer.setBufferAt(currentBufferIndex, geometry.colors);
    }
    currentBufferIndex++;

    if (geometry.hasAttribute0) {
      await vertexBuffer.setBufferAt(currentBufferIndex, geometry.attribute0);
    }

    // Build index buffer
    final indexBufferBuilder = FFIIndexBufferBuilder(engine);
    indexBufferBuilder.indexCount(geometry.indices.length);

    indexBufferBuilder.bufferType(geometry.indexType);

    final indexBuffer = await indexBufferBuilder.build() as FFIIndexBuffer;
    final indexTypedData = switch (geometry.indexType) {
      IndexType.UINT => makeUint32List(geometry.indices.length)..setRange(0, geometry.indices.length, geometry.indices),
      IndexType.USHORT => makeUint16List(
        geometry.indices.length,
      )..setRange(0, geometry.indices.length, geometry.indices),
    };
    await indexBuffer.setBuffer(indexTypedData);

    // Calculate bounding box from vertices
    double minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity, maxZ = double.negativeInfinity;

    for (int i = 0; i < geometry.vertices.length; i += 3) {
      final x = geometry.vertices[i];
      final y = geometry.vertices[i + 1];
      final z = geometry.vertices[i + 2];

      minX = math.min(minX, x);
      minY = math.min(minY, y);
      minZ = math.min(minZ, z);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
      maxZ = math.max(maxZ, z);
    }

    final centerX = (minX + maxX) / 2.0;
    final centerY = (minY + maxY) / 2.0;
    final centerZ = (minZ + maxZ) / 2.0;
    final halfExtentX = (maxX - minX) / 2.0;
    final halfExtentY = (maxY - minY) / 2.0;
    final halfExtentZ = (maxZ - minZ) / 2.0;

    // Convert Aabb3 to C struct format
    final cAabb = bindings.StructAllocator.create<bindings.Aabb3>();

    cAabb.centerX = centerX;
    cAabb.centerY = centerY;
    cAabb.centerZ = centerZ;
    cAabb.halfExtentX = halfExtentX;
    cAabb.halfExtentY = halfExtentY;
    cAabb.halfExtentZ = halfExtentZ;

    // Prepare material instance pointers
    final ptrList = makeIntPtrList(materialInstances?.length ?? 0);
    if (materialInstances != null) {
      ptrList.setRange(
        0,
        materialInstances.length,
        materialInstances.cast<FFIMaterialInstance>().map((mi) => mi.pointer.address).toList(),
      );
    }

    // Create the scene asset from buffers
    var assetPtr = await withPointerCallback<TSceneAsset>((callback) {
      var ptr = SceneAsset_createFromBuffersRenderThread(
        engine,
        vertexBuffer.getNativeHandle(),
        indexBuffer.getNativeHandle(),
        ptrList.address.cast(),
        ptrList.length,
        geometry.primitiveType.index,
        cAabb,
        callback,
      );
      return ptr;
    });

    geometry.dispose();

    ptrList.free();
    tangentQuaternions?.free();

    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
    }

    if (assetPtr == nullptr) {
      throw Exception("Failed to create geometry");
    }

    return FFIAsset(assetPtr, app: this);
  }

  //
  Future<ThermionEntity> createDirectLight(DirectLight directLight) async {
    var entity = lightManager.createLight(directLight.type);

    // Set color using either color temperature or RGB values
    if (directLight.colorTemperature != null) {
      lightManager.setColorTemperature(entity, directLight.colorTemperature!);
    } else {
      lightManager.setColor(entity, directLight.color.r, directLight.color.g, directLight.color.b);
    }

    lightManager.setIntensity(entity, directLight.intensity);
    lightManager.setPosition(entity, directLight.position.x, directLight.position.y, directLight.position.z);
    lightManager.setDirection(entity, directLight.direction.x, directLight.direction.y, directLight.direction.z);
    lightManager.setFalloff(entity, directLight.falloffRadius);
    lightManager.setSpotLightCone(entity, directLight.spotLightConeInner, directLight.spotLightConeOuter);

    // Note: Sun-specific properties (angular radius, halo size, halo falloff)
    // are not currently exposed in the Dart LightManager interface
    await lightManager.setShadowCaster(entity, directLight.castShadows);

    return entity;
  }

  //
  Future flush() async {
    if (FILAMENT_SINGLE_THREADED) {
      await withVoidCallback((requestId, cb) => Engine_executeRenderThread(engine, requestId, cb));
    } else {
      await withVoidCallback((requestId, cb) => Engine_flushAndWaitRenderThread(engine, requestId, cb));
    }
  }

  final _onBeforeDestroy = <Future Function()>[];
  final _onDestroy = <Future Function()>[];

  //
  @override
  void onBeforeDestroy(Future Function() callback) {
    _onBeforeDestroy.add(callback);
  }

  //
  @override
  void onDestroy(Future Function() callback) {
    _onDestroy.add(callback);
  }

  //
  Future<ThermionEntity> createEntity({bool createTransformComponent = true}) async {
    final entity = await withIntCallback(
      (cb) => EntityManager_createEntityRenderThread(Engine_getEntityManager(engine), cb),
    );
    if (createTransformComponent) {
      await transformManager.createComponent(entity);
    }
    return entity;
  }

  //
  Future setTransform(ThermionEntity entity, Matrix4 transform) async {
    transformManager.setTransform(entity, transform);
  }

  //
  Future<Matrix4> getLocalTransform(ThermionEntity entity) async {
    return transformManager.getLocalTransform(entity);
  }

  //
  Future<Matrix4> getWorldTransform(ThermionEntity entity) async {
    return transformManager.getWorldTransform(entity);
  }

  //
  @override
  Future setPriority(ThermionEntity entity, int priority) async {
    await renderableManager.setPriority(entity, priority);
  }

  //
  Future<int> getPrimitiveCount(ThermionEntity entity) async {
    return renderableManager.getPrimitiveCount(entity);
  }

  //
  Future<Aabb3> getBoundingBox(ThermionEntity entity) async {
    return renderableManager.getBoundingBox(entity);
  }

  // Builds an (empty) [Skybox] instance. This will not be attached to any scene until
  // [setSkybox] is called.
  //
  Future<Skybox> buildSkybox({Texture? texture = null, bool showSun = false, double? intensity}) async {
    final ptr = await withPointerCallback<TSkybox>((cb) {
      Engine_buildSkyboxRenderThread(engine, (texture as FFITexture?)?.pointer ?? nullptr, showSun, intensity ?? -1.0, cb);
    });
    return FFISkybox(ptr, this);
  }

  // Creates a [Skybox] with a solid color. This will not be attached to any
  // scene until [setSkybox] is called.
  //
  // This is useful for clearing render targets with a specific color
  // (including fully transparent for overlay passes).
  Future<Skybox> createColoredSkybox({
    required double r,
    required double g,
    required double b,
    required double a,
    bool showSun = false,
    double? intensity,
  }) async {
    final ptr = await withPointerCallback<TSkybox>((cb) {
      Engine_buildColoredSkyboxRenderThread(engine, r, g, b, a, showSun, intensity ?? -1.0, cb);
    });
    return FFISkybox(ptr, this);
  }

  //
  Future<bool> isRenderable(ThermionEntity entity) async {
    return renderableManager.isRenderable(entity);
  }

  //
  Future<Texture> loadKtx2(Uint8List data) async {
    _logger.info("Loading KTX2 from ${data.length} bytes");
    // Ktx2Reader internally calls Texture::Builder().build, which on web must
    // happen on the engine's render thread; routing through the *RenderThread
    // variant avoids the abort.
    final texturePtr = await withPointerCallback<TTexture>(
      (cb) => Ktx2Reader_createTextureRenderThread(engine, data.address, data.length, cb),
    );
    if (texturePtr == nullptr) {
      throw Exception("Failed to load KTX2 texture");
    }
    return FFITexture(engine, texturePtr, this);
  }

  @override
  Future<TexturedQuad> createTexturedQuad() async {
    if (_imageMaterial == null) {
      var ptr = await withPointerCallback<TMaterial>((cb) => Material_createImageMaterialRenderThread(engine, cb));
      _imageMaterial = FFIMaterial(ptr, this);
    }
    var mi = await _imageMaterial!.createInstance() as FFIMaterialInstance;

    var quad = await createGeometry(GeometryUtils.fullscreenQuad());
    await mi.setParameterInt("isCubeMap", 0);
    await mi.setParameterInt("showImage", 0);
    var transform = Matrix4.identity();

    await mi.setParameterMat4("transform", transform);

    await quad.setMaterialInstanceAt(mi);
    return FFITexturedQuad(asset: quad, mi: mi, app: this);
  }

  //
  Future<GltfMeshData> parseGltf(Uint8List data, {String? meshName}) {
    return FFIGltfMeshData.parse(data, meshName: meshName);
  }
}

bool _isFloatTextureFormat(TextureFormat f) {
  switch (f) {
    case TextureFormat.R16F:
    case TextureFormat.RG16F:
    case TextureFormat.RGB16F:
    case TextureFormat.RGBA16F:
    case TextureFormat.R32F:
    case TextureFormat.RG32F:
    case TextureFormat.RGB32F:
    case TextureFormat.RGBA32F:
    case TextureFormat.R11F_G11F_B10F:
    case TextureFormat.RGB9_E5:
      return true;
    default:
      return false;
  }
}

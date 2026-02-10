import 'dart:async';
import 'dart:math' as math;
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
import 'package:thermion_dart/src/filament/src/interface/skybox.dart';
import 'package:thermion_dart/src/filament/src/interface/surface_orientation.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:logging/logging.dart';
import 'ffi_gltf_mesh_data.dart';
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
  final Pointer<TRenderManager> renderManager;
  final Pointer<Void> renderThreadHandle;

  final Pointer<TMaterialProvider> ubershaderMaterialProvider;

  final Pointer<TNameComponentManager> nameComponentManager;

  late final Future<Uint8List> Function(String uri) _loadResource;
  late final FFILightManager lightManager;
  late final FFIRenderableManager renderableManager;
  late final FFITransformManager transformManager;
  late final FFIAnimationManager animationManager;

  static final _logger = Logger("FFIFilamentApp");

  FFIFilamentApp(
      this.engine,
      this.gltfAssetLoader,
      this.renderer,
      Pointer<TTransformManager> transformManagerPtr,
      this.ubershaderMaterialProvider,
      this.renderManager,
      this.renderThreadHandle,
      this.nameComponentManager,
      Future<Uint8List> Function(String uri)? loadResource,
      Pointer<TLightManager> lightManagerPointer,
      Pointer<TRenderableManager> renderableManagerPointer,
      Pointer<TAnimationManager> animationManagerPointer) {
    this._loadResource = loadResource ?? defaultResourceLoader;
    this.lightManager = FFILightManager(lightManagerPointer, this);
    this.renderableManager =
        FFIRenderableManager(renderableManagerPointer, this);
    this.transformManager = FFITransformManager(transformManagerPtr, this);
    this.animationManager = FFIAnimationManager(animationManagerPointer, this);
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

  static Future create({FFIFilamentConfig? config}) async {
    config ??= FFIFilamentConfig();

    if (FilamentApp.instance != null) {
      await FilamentApp.instance!.destroy();
    }

    RenderThread_destroy();
    final renderThreadHandle = RenderThread_create();

    final engine = await withPointerCallback<TEngine>((cb) =>
        Engine_createRenderThread(
            config!.backend.value,
            config.platform ?? nullptr,
            config.sharedContext ?? nullptr,
            config.stereoscopicEyeCount,
            config.disableHandleUseAfterFreeCheck,
            cb)).timeout(Duration(seconds: 30)); // 30 second timeout is just for CI purposes, this should return  
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

    final renderManager = RenderManager_create(engine, renderer);

    final animationManager = await withPointerCallback<TAnimationManager>(
      (cb) => AnimationManager_createRenderThread(engine, cb),
    );

    await withVoidCallback((requestId, cb) =>
        RenderManager_addAnimationManagerRenderThread(
            renderManager, animationManager, requestId, cb));

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
        animationManager);

    _logger.info("Initialization complete");
  }

  // Updates the native render manager with the current values for all views/swap
  // chains passed to [setRenderOrder].
  //
  // Automatically sets the correct render order for views with a highlight
  // overlay, being:
  // 1. Silhouette views (render highlighted entities to texture)
  // 2. Main views (normal scene rendering)
  // 3. Overlay views (edge detection fullscreen quad, composites on top)
  //
  Future updateRenderOrder() async {
    final swapChains = _swapChains.keys.toList();

    final handles = [];

    for (int i = 0; i < swapChains.length; i++) {
      final swapChain = swapChains[i];
      var views = _swapChains[swapChain];
      final viewNames = [];

      if (views == null) {
        _logger.info("No views found for swapchain $swapChain");
        continue;
      }

      views = views.where((item) => item.$1 != -1).toList();

      // First pass: silhouette views (render to texture)
      for (final item in views) {
        final view = item.$2;

        final overlayManager = await view.getHighlightOverlay();
        if (overlayManager != null) {
          handles.add(overlayManager.silhouetteView.getNativeHandle());
          viewNames.add(await overlayManager.silhouetteView.getName());
          _logger.info("Added silhouette view to render list");
        }
      }

      // Second pass: main views
      for (final item in views) {
        final view = item.$2;
        handles.add(view.getNativeHandle());
        viewNames.add(await view.getName());
      }

      // Third pass: overlay views (composite on top)
      for (final item in views) {
        final view = item.$2;
        final overlayManager = await view.getHighlightOverlay();

        if (overlayManager != null) {
          handles.add(overlayManager.overlayView.getNativeHandle());
          viewNames.add(await overlayManager.overlayView.getName());
          _logger.info("Added overlay view to render list");
        }
      }

      final pointers = allocate<PointerClass>(handles.length);
      for (int i = 0; i < handles.length; i++) {
        pointers[i] = handles[i];
      }

      await withVoidCallback((requestId, cb) =>
          RenderManager_setRenderableRenderThread(
              renderManager,
              swapChain.getNativeHandle(),
              pointers.cast(),
              handles.length,
              requestId,
              cb));

      free(pointers);

      _logger.info(
          "${handles.length} renderable views for swapchain $i (${swapChain.getNativeHandle()}) : $viewNames");
    }

    _logger.info("Updated render order for ${swapChains.length} swapchains");
  }

  @override
  Future<SwapChain> createHeadlessSwapChain(int width, int height,
      {bool hasStencilBuffer = false, bool isMacOS = false}) async {
    var flags = TSWAP_CHAIN_CONFIG_TRANSPARENT | TSWAP_CHAIN_CONFIG_READABLE;

    if (hasStencilBuffer) {
      flags |= TSWAP_CHAIN_CONFIG_HAS_STENCIL_BUFFER;
    }

    if (isMacOS) {
      flags |= TSWAP_CHAIN_CONFIG_APPLE_CVPIXELBUFFER;
    }

    final swapChain = await withPointerCallback<TSwapChain>((cb) =>
        Engine_createHeadlessSwapChainRenderThread(
            this.engine, width, height, flags, cb));
    return FFISwapChain(swapChain);
  }

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
    _logger.info("Created swapchain from window");
    return FFISwapChain(swapChain);
  }

  ///
  Future<View> createView({bool createScene = false}) async {
    final view = await FFIView.create();
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

  ///
  Future<Scene> createScene() async {
    return FFIScene(Engine_createScene(engine));
  }

  ///
  Future<Camera> createCamera({ThermionEntity? targetEntity}) async {
    targetEntity ??= await createEntity(createTransformComponent: false);
    return FFICamera(await withPointerCallback<TCamera>(
        (cb) => Engine_createCameraRenderThread(engine, targetEntity!, cb)));
  }

  ///
  Future destroySwapChain(SwapChain swapChain) async {
    _logger.info("Destroying swapchain");
    await withVoidCallback((requestId, cb) =>
        RenderManager_removeSwapChainRenderThread(
            renderManager, swapChain.getNativeHandle(), requestId, cb));
    await withVoidCallback((requestId, callback) {
      Engine_destroySwapChainRenderThread(
          engine, swapChain.getNativeHandle(), requestId, callback);
    });

    _swapChains.remove(swapChain);
    _logger.info("Destroyed swapchain");
  }

  // Destroys the specified entity. You must ensure that the entity has already
  // been detached (e.g. if renderable, it has been removed from any scenes,
  // that any camera or animation component has already been removed, etc).
  Future destroyEntity(ThermionEntity entity) async {
    if (renderableManager.hasComponent(entity)) {
      await withVoidCallback((requestId, cb) =>
          RenderableManager_destroyEntityRenderThread(
              renderableManager.getNativeHandle(), entity, requestId, cb));
    }
    if (transformManager.hasComponent(entity)) {
      await transformManager.removeComponent(entity);
    }
    await withVoidCallback((requestId, cb) =>
        EntityManager_destroyEntityRenderThread(
            Engine_getEntityManager(engine), entity, requestId, cb));
  }

  ///
  @override
  Future destroy() async {
    final swapChains = _swapChains.keys.toList();
    for (final swapChain in swapChains) {
      if (_swapChains[swapChain] == null) {
        continue;
      }
      for (final item in _swapChains[swapChain]!) {
        final view = item.$2;
        await setRenderOrder(swapChain, view, renderOrder: -1);
      }
    }
    for (final swapChain in _swapChains.keys.toList()) {
      await destroySwapChain(swapChain);
    }
    await withVoidCallback((requestId, cb) async {
      Engine_destroyRenderThread(engine, requestId, cb);
    });

    RenderThread_destroy();
    RenderManager_destroy(renderManager);

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
  Future<RenderTarget> createRenderTarget(int width, int height,
      {Texture? color, Texture? depth}) async {
    _logger.finest("Creating ${width}x${height} render target");
    if (color == null) {
      _logger.finest("No color texture provided");
      color = await createTexture(width, height,
          flags: {
            TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
            TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
            TextureUsage.TEXTURE_USAGE_BLIT_SRC
          },
          textureFormat: TextureFormat.RGBA8) as FFITexture;
      _logger.finest(
          "Created ${width}x${height} color texture (TextureFormat.RGBA8)");
    }
    if (depth == null) {
      _logger.finest("No depth texture provided");
      depth = await createTexture(width, height,
          flags: {
            TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
            TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT,
            TextureUsage.TEXTURE_USAGE_BLIT_SRC,
          },
          textureFormat: TextureFormat.DEPTH32F) as FFITexture;
      _logger.finest(
          "Created ${width}x${height} depth texture (TextureFormat.DEPTH32F)");
    }
    final renderTarget = await withPointerCallback<TRenderTarget>((cb) {
      RenderTarget_createRenderThread(engine, 
          color!.getNativeHandle(), depth!.getNativeHandle(), cb);
    });
    if (renderTarget == nullptr) {
      throw Exception("Failed to create RenderTarget");
    }

    return FFIRenderTarget(renderTarget);
  }

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

  Future<void> setExternalImage(Texture texture, int externalImagePtr) async {
    final ffiTexture = texture as FFITexture;
    await withVoidCallback((requestId, cb) {
      Texture_setExternalImageRenderThread(
          engine,
          ffiTexture.pointer,
          Pointer<Void>.fromAddress(externalImagePtr),
          requestId,
          cb);
    });
  }

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
    final namePtr = name.toNativeUtf8().cast<Char>();
    var ptr = Image_decode(data.address, data.length, namePtr, requireAlpha);
    free(namePtr);

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
    return FFIMaterial(ptr);
  }

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

    var instance = FFIMaterialInstance(materialInstance);
    return instance;
  }

  ///
  Future<MaterialInstance> createUnlitMaterialInstance() async {
    return createUbershaderMaterialInstance(
        unlit: true, hasVertexColors: false);
  }

  ///
  Future<MaterialInstance> getMaterialInstanceAt(
      ThermionEntity entity, int index) async {
    final instance =
        await renderableManager.getMaterialInstanceAt(entity, index);
    if (instance == null) {
      throw Exception("No material instance at index $index");
    }
    return instance;
  }

  ///
  Future setMaterialInstanceAt(ThermionEntity entity, int index,
      MaterialInstance materialInstance) async {
    await renderableManager.setMaterialInstanceAt(
        entity, index, materialInstance);
  }

  int _renderOrder = 0;
  int get renderOrder => _renderOrder;

  final _swapChains = <SwapChain, List<(int, View)>>{};

  ///
  @override
  Future setRenderOrder(SwapChain swapChain, View view,
      {int renderOrder = 0}) async {
    if (!_swapChains.containsKey(swapChain)) {
      _swapChains[swapChain] = [];
    }

    _swapChains[swapChain]!.removeWhere((v) => v.$2 == view);
    _swapChains[swapChain]!.add((renderOrder, view));
    _swapChains[swapChain]!.sort((a, b) => a.$1.compareTo(b.$1));
    await updateRenderOrder();
  }

  @override
  Future<SwapChain<dynamic>?> getSwapChain(View<dynamic> view) async {
    for (final swapChain in _swapChains.keys) {
      if (_swapChains[swapChain] == null) {
        continue;
      }
      for (final item in _swapChains[swapChain]!) {
        if (item.$2 == view) {
          return swapChain;
        }
      }
    }
    return null;
  }

  ///
  Future<Iterable<SwapChain>> getSwapChains() async {
    return _swapChains.keys;
  }

  final _hooks = <Future Function()>[];

  ///
  @override
  Future registerRequestFrameHook(Future Function() hook) async {
    while (_processingRenderHooks) {
      await Future.delayed(Duration(milliseconds: 1));
    }
    if (!_hooks.contains(hook)) {
      _hooks.add(hook);
    }
  }

  ///
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

    final frameTimeInNanos = DateTime.now().microsecondsSinceEpoch * 1000;

    await withVoidCallback((requestId, cb) {
      RenderManager_renderRenderThread(
          renderManager, frameTimeInNanos.toBigInt, requestId, cb);
    });
  }

  ///
  @override
  Future setParent(ThermionEntity child, ThermionEntity? parent,
      {bool preserveScaling = false}) async {
    transformManager.setParent(child, parent ?? FILAMENT_ENTITY_NULL,
        preserveScaling: preserveScaling);
  }

  ///
  @override
  Future<ThermionEntity?> getParent(ThermionEntity child) async {
    var parent = transformManager.getParent(child);
    if (parent == FILAMENT_ASSET_ERROR) {
      return null;
    }
    return parent;
  }

  ///
  @override
  Future<ThermionEntity?> getAncestor(ThermionEntity child) async {
    var parent = transformManager.getAncestor(child);
    if (parent == FILAMENT_ASSET_ERROR) {
      return null;
    }
    return parent;
  }

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
  Future<List<(View, Uint8List)>> capture(SwapChain? swapChain,
      {View? view,
      bool captureRenderTarget = false,
      PixelDataFormat pixelDataFormat = PixelDataFormat.RGBA,
      PixelDataType pixelDataType = PixelDataType.FLOAT,
      Future Function(View)? beforeRender,
      bool render = true}) async {
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

    final views = <View>[];
    if (view != null) {
      views.add(view);
      _logger.finest("Using provided view");
    } else {
      final mainViews = _swapChains[swapChain]!.map((item) => item.$2);

      for (final item in mainViews) {
        final view = item;
        final overlayManager = await view.getHighlightOverlay();
        if (overlayManager != null) {
          views.add(overlayManager.silhouetteView);
        }
      }

      views.addAll(mainViews);

      for (final view in mainViews) {
        final overlayManager = await view.getHighlightOverlay();

        if (overlayManager != null) {
          views.add(overlayManager.overlayView);
        }
      }

      _logger.finest(
          "Added ${views.length} views (from ${_swapChains.length} swapchains)");
    }

    for (final view in views) {
      final vp = await view.getViewport();
      if (vp.width == 0 || vp.height == 0) {
        throw Exception(
            "Invalid viewport : ${vp.width}x${vp.height} for ${view.getNativeHandle()}");
      }
    }

    if (beginFrame) {
      _logger.finest("Starting capture for ${views.length} views");

      for (var viewIndex = 0; viewIndex < views.length; viewIndex++) {
        final view = views[viewIndex];
        _logger.finest(
            "Capturing view ${viewIndex} (renderTarget: ${(await view.getRenderTarget()) != null ? 'yes' : 'no'}) views");

        beforeRender?.call(view);

        final viewport = await view.getViewport();

        int numChannels = switch (pixelDataFormat) {
          PixelDataFormat.RGBA => 4,
          PixelDataFormat.RGB => 3,
          PixelDataFormat.R => 1,
          _ => throw UnsupportedError(pixelDataFormat.toString())
        };

        int channelSizeInBytes = switch (pixelDataType) {
          PixelDataType.FLOAT => sizeOf<Float>(),
          PixelDataType.UBYTE || PixelDataType.BYTE => 1,
          _ => throw UnsupportedError(pixelDataFormat.toString())
        };

        if (viewport.width <= 0 || viewport.height <= 0) {
          throw Exception(
              """Invalid viewport dimensions"""
              """ : ${viewport.width}x${viewport.height}""");
        }

        final numBytes =
            viewport.width * viewport.height * numChannels * channelSizeInBytes;
        final pixelBuffer = makeUint8List(numBytes);

        if (render) {
          await withVoidCallback((requestId, cb) {
            Renderer_renderRenderThread(
              renderer,
              view.getNativeHandle(),
              requestId,
              cb,
            );
          });
        }

        final renderTarget = await view.getRenderTarget();

        if (captureRenderTarget && renderTarget == null) {
          _logger.warning(
              """captureRenderTarget is true but the specified view has no"""
              """ render target. Falling back to swapchain capture""");
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
            view.getNativeHandle(),
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
  Future setClearOptions(double r, double g, double b, double a,
      {int clearStencil = 0, bool discard = false, bool clear = true}) async {
    Renderer_setClearOptions(
        renderer, r, g, b, a, clearStencil, clear, discard);
  }

  ///
  Future<ThermionAsset> loadGltfFromBuffer(Uint8List data,
      {int initialInstances = 1,
      bool keepData = false,
      int priority = 4,
      int layer = 0,
      bool loadResourcesAsync = false,
      String? resourceUri}) async {
    _logger.info(
        "Loading glTF from buffer (${data.lengthInBytes} bytes) with resourceUri ${resourceUri}");
    final resources = <FinalizableUint8List>[];

    if (resourceUri != null && !resourceUri.endsWith("/")) {
      resourceUri = "${resourceUri}/";
    }

    try {
      late Pointer stackPtr;
      if (FILAMENT_WASM) {
        //stackPtr = stackSave();
      }

      if (FILAMENT_SINGLE_THREADED) {
        loadResourcesAsync = true;
      }

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
        final resolvedResourceUri = "${resourceUri ?? ""}${resourceUriDart}";

        final resourceData = await loadResource(resolvedResourceUri);

        _logger.info(
            "Adding ${resourceData.lengthInBytes} bytes for resource ${resourceUriDart} (resolved to $resolvedResourceUri)");

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
        _logger.info("Loading glTF resources synchronously");
        final result = await withBoolCallback((cb) =>
            GltfResourceLoader_loadResourcesRenderThread(
                gltfResourceLoader, filamentAsset, cb));

        if (!result) {
          throw Exception("Failed to load resources");
        }
      }

      _logger.info("glTF resources loaded");

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

      return FFIAsset(asset, keepData: keepData);
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
    for (final swapchain in _swapChains.keys) {
      _swapChains[swapchain]?.removeWhere((item) => item.$2 == view);
    }
    await (view as FFIView).destroy();
  }

  Future destroyScene(covariant FFIScene scene) async {
    await withVoidCallback((requestId, cb) =>
        Engine_destroySceneRenderThread(engine, scene.scene, requestId, cb));
  }

  Future<Pointer<TColorGrading>> createColorGrading(ToneMapper mapper) async {
    return withPointerCallback<TColorGrading>((cb) =>
        ColorGrading_createRenderThread(engine, mapper.getNativeHandle(), cb));
  }

  FFIMaterial? _gizmoMaterial;

  ///
  Future<GizmoAsset> createGizmo(
      covariant FFIView view, GizmoType gizmoType) async {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      //stackPtr = stackSave();
    }

    if (_gizmoMaterial == null) {
      final materialPtr = await withPointerCallback<TMaterial>((cb) {
        Material_createGizmoMaterialRenderThread(engine, cb);
      });
      _gizmoMaterial ??= FFIMaterial(materialPtr);
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

    final gizmoAsset = FFIGizmo(gizmo.cast<TSceneAsset>(),
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
  @override
  Future<ThermionAsset> createGeometry(Geometry geometry,
      {List<MaterialInstance>? materialInstances,
      bool keepData = false,
      bool addToScene = true}) async {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      //stackPtr = stackSave();
    }

    // Build vertex buffer
    final vertexBufferBuilder = FFIVertexBufferBuilder(engine);
    vertexBufferBuilder.vertexCount(geometry.vertices.length ~/ 3);

    // Calculate buffer count - always include UV0 and COLOR like the native C++ code
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
            makeUint32List(geometry.indices.length)
              ..setRange(0, geometry.indices.length, geometry.indices));
      } else {
        orientationBuilder.trianglesUint16(
            makeUint16List(geometry.indices.length)
              ..setRange(0, geometry.indices.length, geometry.indices));
      }

      // Build the surface orientation
      final surfaceOrientation = await orientationBuilder.build();

      // Extract quaternions in FLOAT4 format
      tangentQuaternions = await surfaceOrientation.getQuats(
        QuaternionFormat.FLOAT4,
        geometry.vertices.length ~/ 3,
      ) as Float32List;

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
    vertexBufferBuilder.attribute(
        VertexAttribute.POSITION, 0, VertexAttributeType.FLOAT3);

    // Track current buffer index
    int currentBufferIndex = 1;

    // Tangents attribute (if normals were provided)
    if (tangentQuaternions != null) {
      vertexBufferBuilder.attribute(VertexAttribute.TANGENTS,
          currentBufferIndex, VertexAttributeType.FLOAT4);
      currentBufferIndex++;
    }

    // UV0 attribute (always present like the native C++ code)
    vertexBufferBuilder.attribute(
        VertexAttribute.UV0, currentBufferIndex, VertexAttributeType.FLOAT2);
    currentBufferIndex++;

    // UV1 attribute (ubershader requires two UV sets)
    vertexBufferBuilder.attribute(
        VertexAttribute.UV1, currentBufferIndex, VertexAttributeType.FLOAT2);
    currentBufferIndex++;

    // COLOR attribute (always present like the native C++ code)
    vertexBufferBuilder.attribute(
        VertexAttribute.COLOR, currentBufferIndex, VertexAttributeType.FLOAT4);
    currentBufferIndex++;

    if (geometry.hasAttribute0) {
      vertexBufferBuilder.attribute(VertexAttribute.CUSTOM0, currentBufferIndex,
          VertexAttributeType.FLOAT4);
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
      IndexType.UINT => makeUint32List(geometry.indices.length)
        ..setRange(0, geometry.indices.length, geometry.indices),
      IndexType.USHORT => makeUint16List(geometry.indices.length)
        ..setRange(0, geometry.indices.length, geometry.indices),
    };
    await indexBuffer.setBuffer(indexTypedData);

    // Calculate bounding box from vertices
    double minX = double.infinity,
        minY = double.infinity,
        minZ = double.infinity;
    double maxX = double.negativeInfinity,
        maxY = double.negativeInfinity,
        maxZ = double.negativeInfinity;

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
          materialInstances
              .cast<FFIMaterialInstance>()
              .map((mi) => mi.pointer.address)
              .toList());
    }

    // Create the scene asset from buffers
    var assetPtr = await withPointerCallback<TSceneAsset>((callback) {
      var ptr = SceneAsset_createFromBuffersRenderThread(
          engine,
          vertexBuffer.getNativeHandle(),
          indexBuffer.getNativeHandle(),
          ptrList.address.cast(),
          ptrList.length ?? 0,
          geometry.primitiveType.index,
          cAabb,
          callback);
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

    return FFIAsset(assetPtr, keepData: keepData);
  }

  ///
  Future<ThermionEntity> createDirectLight(DirectLight directLight) async {
    var entity = lightManager.createLight(directLight.type);

    // Set color using either color temperature or RGB values
    if (directLight.colorTemperature != null) {
      lightManager.setColorTemperature(entity, directLight.colorTemperature!);
    } else {
      lightManager.setColor(entity, directLight.color.r, directLight.color.g,
          directLight.color.b);
    }

    lightManager.setIntensity(entity, directLight.intensity);
    lightManager.setPosition(entity, directLight.position.x,
        directLight.position.y, directLight.position.z);
    lightManager.setDirection(entity, directLight.direction.x,
        directLight.direction.y, directLight.direction.z);
    lightManager.setFalloff(entity, directLight.falloffRadius);
    lightManager.setSpotLightCone(
        entity, directLight.spotLightConeInner, directLight.spotLightConeOuter);

    // Note: Sun-specific properties (angular radius, halo size, halo falloff)
    // are not currently exposed in the Dart LightManager interface
    lightManager.setShadowCaster(entity, directLight.castShadows);

    return entity;
  }

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
  void onDestroy(Future Function() callback) {
    _onDestroy.add(callback);
  }

  ///
  Future<ThermionEntity> createEntity(
      {bool createTransformComponent = true}) async {
    final entity = await withIntCallback((cb) => EntityManager_createEntityRenderThread(Engine_getEntityManager(engine), cb));
    if (createTransformComponent) {
      await transformManager.createComponent(entity);
    }
    return entity;
  }

  ///
  Future setTransform(ThermionEntity entity, Matrix4 transform) async {
    transformManager.setTransform(entity, transform);
  }

  ///
  Future<Matrix4> getLocalTransform(ThermionEntity entity) async {
    return transformManager.getLocalTransform(entity);
  }

  ///
  Future<Matrix4> getWorldTransform(ThermionEntity entity) async {
    return transformManager.getWorldTransform(entity);
  }

  ///
  @override
  Future setPriority(ThermionEntity entity, int priority) async {
    await renderableManager.setPriority(entity, priority);
  }

  ///
  Future<int> getPrimitiveCount(ThermionEntity entity) async {
    return renderableManager.getPrimitiveCount(entity);
  }

  ///
  Future<Aabb3> getBoundingBox(ThermionEntity entity) async {
    return renderableManager.getBoundingBox(entity);
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

  /// Creates a [Skybox] with a solid color. This will not be attached to any
  /// scene until [setSkybox] is called.
  ///
  /// This is useful for clearing render targets with a specific color
  /// (including fully transparent for overlay passes).
  Future<Skybox> createColoredSkybox({
    required double r,
    required double g,
    required double b,
    required double a,
  }) async {
    final ptr = await withPointerCallback<TSkybox>((cb) {
      Engine_buildColoredSkyboxRenderThread(engine, r, g, b, a, cb);
    });
    return FFISkybox(ptr);
  }

  ///
  Future<bool> isRenderable(ThermionEntity entity) async {
    return renderableManager.isRenderable(entity);
  }

  ///
  Future<Texture> loadKtx2(Uint8List data) async {
    _logger.info("Loading KTX2 from ${data.length} bytes");
    var texturePtr =
        Ktx2Reader_createTexture(engine, data.address, data.length);
    if (texturePtr == nullptr) {
      throw Exception("Failed to load KTX2 texture");
    }
    return FFITexture(engine, texturePtr);
  }

  @override
  Future<TexturedQuad> createTexturedQuad() async {

    if (_imageMaterial == null) {
      var ptr = await withPointerCallback<TMaterial>(
          (cb) => Material_createImageMaterialRenderThread(engine, cb));
      _imageMaterial = FFIMaterial(ptr);
    }
    var mi =
        await _imageMaterial!.createInstance() as FFIMaterialInstance;
    
    var quad = await createGeometry(GeometryHelper.fullscreenQuad());
    await mi.setParameterInt("isCubeMap", 0);
    await mi.setParameterInt("showImage", 0);
    var transform = Matrix4.identity();

    await mi.setParameterMat4("transform", transform);

    await quad.setMaterialInstanceAt(mi);
    return FFITexturedQuad(asset: quad, mi: mi);
  }

  //
  Future<GltfMeshData> parseGltf(Uint8List data, {String? meshName}) {
    return FFIGltfMeshData.parse(data, meshName: meshName);
  }
}

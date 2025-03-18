import 'package:thermion_dart/src/viewer/src/ffi/src/callbacks.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_render_target.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_swapchain.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/ffi_texture.dart';
import 'package:thermion_dart/src/viewer/src/filament/filament.dart';
import 'package:thermion_dart/thermion_dart.dart';

typedef RenderCallback = Pointer<NativeFunction<Void Function(Pointer<Void>)>>;

class FFIFilamentConfig extends FilamentConfig<RenderCallback, Pointer<Void>> {
  FFIFilamentConfig(
      {required super.backend,
      required super.resourceLoader,
      required super.uberArchivePath});
}

class FFIFilamentApp extends FilamentApp<Pointer> {
  static FFIFilamentApp? _instance;

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
            ubershaderMaterialProvider: ubershaderMaterialProvider);

  Future<FFIFilamentApp> create(FFIFilamentConfig config) async {
    if (_instance == null) {
      RenderLoop_destroy();
      RenderLoop_create();

      final engine = await withPointerCallback<TEngine>((cb) =>
          Engine_createRenderThread(
              TBackend.values[config.backend.index].index,
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
          await withPointerCallback<TMaterialProvider>(
              (cb) => GltfAssetLoader_getMaterialProvider(gltfAssetLoader));

      final transformManager = Engine_getTransformManager(engine);
      final lightManager = Engine_getLightManager(engine);
      final renderableManager = Engine_getRenderableManager(engine);

      final renderTicker = await withPointerCallback<TRenderTicker>(
          (cb) => RenderTicker_create(renderer));

      final nameComponentManager = NameComponentManager_create();

      _instance = FFIFilamentApp(
          engine,
          gltfAssetLoader,
          gltfResourceLoader,
          renderer,
          transformManager,
          lightManager,
          renderableManager,
          ubershaderMaterialProvider,
          renderTicker, nameComponentManager);
    }
    return _instance!;
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

  @override
  Future destroy() {
    throw UnimplementedError();
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

    // ///
  // ///
  // ///
  // Future<RenderTarget> createRenderTarget(int width, int height,
  //     {covariant FFITexture? color, covariant FFITexture? depth}) async {
  //   final renderTarget = await withPointerCallback<TRenderTarget>((cb) {
  //     RenderTarget_createRenderThread(app.engine, width, height,
  //         color?.pointer ?? nullptr, depth?.pointer ?? nullptr, cb);
  //   });

  //   return FFIRenderTarget(renderTarget, app);
  // }
}

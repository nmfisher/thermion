import 'package:thermion_dart/src/viewer/src/shared_types/engine.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FilamentConfig<T, U> {
  final Backend backend;
  final T? renderCallback;
  final U? renderCallbackOwner;
  final U resourceLoader;
  final U? platform;
  final U? driver;
  final U? sharedContext;
  final String uberArchivePath;
  final int stereoscopicEyeCount;
  final bool disableHandleUseAfterFreeCheck;

  FilamentConfig(
      {required this.backend,
      required this.resourceLoader,
      required this.uberArchivePath,
      this.renderCallback,
      this.renderCallbackOwner,
      this.platform,
      this.driver,
      this.sharedContext,
      this.stereoscopicEyeCount = 1,
      this.disableHandleUseAfterFreeCheck = false});
}

abstract class FilamentApp<T> {
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
      required this.ubershaderMaterialProvider
      });

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
  Future<RenderTarget> createRenderTarget(
      int width, int height, { covariant Texture? color, covariant Texture? depth });

}

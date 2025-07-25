import 'dart:async';

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:thermion_dart/thermion_dart.dart';

import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:logging/logging.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';

///
/// An implementation of [ThermionFlutterPlatform] that uses
/// a Flutter platform channel to create a native rendering context, resource
/// loader and rendering surfaces.
///
class ThermionFlutterMethodChannelPlatform extends ThermionFlutterPlatform {
  final channel = const MethodChannel("dev.thermion.flutter/event");

  late final _logger = Logger(this.runtimeType.toString());

  static SwapChain? _swapChain;

  SwapChain? getActiveSwapchain() {
    return _swapChain;
  }

  ThermionFlutterMethodChannelPlatform._();

  static ThermionFlutterMethodChannelPlatform? instance;

  static void registerWith() {
    instance ??= ThermionFlutterMethodChannelPlatform._();
    ThermionFlutterPlatform.instance = instance!;
  }

  static Future<Uint8List> loadAsset(String path) async {
    if (path.startsWith("file://")) {
      return File(path.replaceAll("file://", "")).readAsBytesSync();
    }
    if (path.startsWith("asset://")) {
      path = path.replaceAll("asset://", "");
    }
    var asset = await rootBundle.load(path);
    return asset.buffer.asUint8List(asset.offsetInBytes);
  }

  Future<ThermionViewer> createViewer({bool destroySwapchain = true}) async {
    var driverPlatform = await channel.invokeMethod("getDriverPlatform");

    var platformPtr = driverPlatform == null
        ? nullptr
        : VoidPointerClass.fromAddress(driverPlatform);

    var sharedContext = await channel.invokeMethod("getSharedContext");

    var sharedContextPtr = sharedContext == null
        ? nullptr
        : VoidPointerClass.fromAddress(sharedContext);

    late Backend backend;
    if (options.backend != null) {
      switch (options.backend) {
        case Backend.VULKAN:
          if (!Platform.isWindows) {
            throw Exception("Vulkan only supported on Windows");
          }
        case Backend.METAL:
          if (!Platform.isIOS || !Platform.isMacOS) {
            throw Exception("Metal only supported on iOS/macOS");
          }
        case Backend.OPENGL:
          if (!Platform.isAndroid) {
            throw Exception("OpenGL only supported on Android");
          }
        default:
          throw Exception("Unsupported backend");
      }
      backend = options.backend!;
    } else {
      if (Platform.isWindows) {
        backend = Backend.VULKAN;
      } else if (Platform.isMacOS || Platform.isIOS) {
        backend = Backend.METAL;
      } else if (Platform.isAndroid) {
        backend = Backend.OPENGL;
      } else {
        throw Exception("Unsupported platform");
      }
    }

    final config = FFIFilamentConfig(
      backend: backend,
      loadResource: loadAsset,
      platform: platformPtr,
      sharedContext: sharedContextPtr,
      uberArchivePath: options.uberarchivePath,
    );

    if (FilamentApp.instance == null) {
      await FFIFilamentApp.create(config: config);
      FilamentApp.instance!.onDestroy(() async {
        if (Platform.isWindows) {
          await channel.invokeMethod("destroyContext");
        }
        _swapChain = null;
      });
    }

    final viewer = ThermionViewerFFI();

    await viewer.initialized;

    // this implementation renders directly into a texture/render target
    // for some reason we still need to create a (headless) swapchain, but the
    // actual dimensions don't matter
    // TODO - see if we can use `renderStandaloneView` in FilamentViewer to
    // avoid this
    if (Platform.isMacOS || Platform.isIOS) {
      if(destroySwapchain && _swapChain != null) {
        await FilamentApp.instance!.destroySwapChain(_swapChain!);
        _swapChain = null;
      }

      _swapChain ??= await FilamentApp.instance!
          .createHeadlessSwapChain(1, 1, hasStencilBuffer: true);
      await FilamentApp.instance!.register(_swapChain!, viewer.view);
      await viewer.view.setRenderable(true);
    }

    return viewer;
  }

  Future<PlatformTextureDescriptor> createTextureDescriptor(
    int width,
    int height,
  ) async {
    if (width == 0 || height == 0) {
      throw Exception(
        "Invalid dimensions for texture descriptor : ${width}x${height}",
      );
    }
    var result = await channel.invokeMethod("createTexture", [
      width,
      height,
      0,
      0,
    ]);
    if (result == null || (result[0] == -1)) {
      throw Exception("Failed to create texture");
    }
    final flutterId = result[0] as int;
    final hardwareId = result[1] as int;
    var window = result[2] as int?; // usually 0 for nullptr

    return PlatformTextureDescriptor(
      flutterId,
      hardwareId,
      window,
      width,
      height,
    );
  }

  @override
  Future destroyTextureDescriptor(PlatformTextureDescriptor descriptor) async {
    await channel.invokeMethod("destroyTexture", descriptor.flutterTextureId);
  }

  ///
  ///
  ///
  Future<PlatformTextureDescriptor?> createTextureAndBindToView(
    View view,
    int width,
    int height,
  ) async {
    var descriptor = await createTextureDescriptor(width, height);

    if (Platform.isWindows) {
      if (_swapChain != null) {
        await FilamentApp.instance!.unregister(_swapChain!, view);
        await FilamentApp.instance!.destroySwapChain(_swapChain!);
      }

      _swapChain = await FilamentApp.instance!.createHeadlessSwapChain(
          descriptor.width, descriptor.height,
          hasStencilBuffer: true);

      _logger.info(
        "Created headless swapchain ${descriptor.width}x${descriptor.height}",
      );

      await FilamentApp.instance!.register(_swapChain!, view);
    } else if (Platform.isAndroid) {
      if (_swapChain != null) {
        await FilamentApp.instance!.unregister(_swapChain!, view);
        await FilamentApp.instance!.destroySwapChain(_swapChain!);
      }
      _swapChain = await FilamentApp.instance!.createSwapChain(
        Pointer<Void>.fromAddress(descriptor.windowHandle!),
      );
      await FilamentApp.instance!.register(_swapChain!, view);
    } else {
      final color = await FilamentApp.instance!.createTexture(
        descriptor.width,
        descriptor.height,
        importedTextureHandle: descriptor.hardwareId,
        flags: {
          TextureUsage.TEXTURE_USAGE_BLIT_SRC,
          TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
          TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
        },
        textureFormat: options.renderTargetColorTextureFormat,
        textureSamplerType: TextureSamplerType.SAMPLER_2D,
      );
      final depth = await FilamentApp.instance!.createTexture(
        descriptor.width,
        descriptor.height,
        flags: {
          TextureUsage.TEXTURE_USAGE_BLIT_SRC,
          TextureUsage.TEXTURE_USAGE_DEPTH_ATTACHMENT,
          TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
          TextureUsage.TEXTURE_USAGE_STENCIL_ATTACHMENT
        },
        textureFormat:
            options.renderTargetDepthTextureFormat,
        textureSamplerType: TextureSamplerType.SAMPLER_2D,
      );

      var renderTarget = await FilamentApp.instance!.createRenderTarget(
        descriptor.width,
        descriptor.height,
        color: color,
        depth: depth,
      );

      await view.setRenderTarget(renderTarget);
    }

    return descriptor;
  }

  @override
  Future markTextureFrameAvailable(PlatformTextureDescriptor texture) async {
    if (!Platform.isAndroid) {
      await channel.invokeMethod(
        "markTextureFrameAvailable",
        texture.flutterTextureId,
      );
    }
  }

  @override
  Future<PlatformTextureDescriptor> resizeTexture(
    PlatformTextureDescriptor texture,
    View view,
    int width,
    int height,
  ) async {
    var newTexture = await createTextureAndBindToView(view, width, height);
    if (newTexture == null) {
      throw Exception();
    }

    await destroyTextureDescriptor(texture);

    return newTexture;
  }
}

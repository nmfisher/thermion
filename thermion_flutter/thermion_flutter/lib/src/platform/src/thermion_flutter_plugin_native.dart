import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:thermion_flutter/src/platform/src/darwin_platform_texture_descriptor.dart';
import 'package:thermion_flutter/src/platform/src/method_channel_platform_texture_descriptor.dart';
import '../../../thermion_flutter.dart';

// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

import 'platform_texture_descriptor.dart';

///
/// Handles all platform-specific initialization to create a backing rendering
/// surface in a Flutter application and lifecycle listeners to pause rendering
/// when the app is inactive or in the background.
///
class ThermionFlutterPluginImpl extends ThermionFlutterPlugin {
  final channel = const MethodChannel("dev.thermion.flutter/event");

  late final _logger = Logger(this.runtimeType.toString());

  static ThermionFlutterPluginImpl get instance =>
      ThermionFlutterPlugin.instance as ThermionFlutterPluginImpl;

  static SwapChain? _swapChain;

  SwapChain? getActiveSwapchain() {
    return _swapChain;
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

  @override
  Future<SwapChain> initialize({bool destroySwapchain = true}) async {
    var driverPlatform;
    Pointer<Void> platformPtr = nullptr;
    var sharedContext;
    Pointer<Void> sharedContextPtr = nullptr;
    if (!Platform.isMacOS && !Platform.isIOS) {
      driverPlatform = await channel.invokeMethod("getDriverPlatform");
      platformPtr = driverPlatform == null
          ? nullptr
          : VoidPointerClass.fromAddress(driverPlatform);

      sharedContext = await channel.invokeMethod("getSharedContext");

      sharedContextPtr = sharedContext == null
          ? nullptr
          : VoidPointerClass.fromAddress(sharedContext);
    }

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

    // on MacOS/iOS, even though we render directly into a render target,
    // for some reason we still need to create a headless swapchain (though the
    // dimensions don't seem to matter).
    // TODO - see if we can use `renderStandaloneView` in FilamentViewer to
    // avoid this
    if (Platform.isMacOS || Platform.isIOS) {
      if (destroySwapchain && _swapChain != null) {
        await FilamentApp.instance!.destroySwapChain(_swapChain!);
        _swapChain = null;
      }

      _swapChain ??= await FilamentApp.instance!
          .createHeadlessSwapChain(1, 1, hasStencilBuffer: true);
    }
    return _swapChain!;
  }

  /// Create a rendering surface and binds to the given [View]. This is internal;
  /// unless you are [thermion_*] package developer, don't
  /// call this yourself. May not be supported on all platforms.
  Future<PlatformTextureDescriptor?> createTextureAndBindToView(
    View view,
    int width,
    int height,
  ) async {
    if (width == 0 || height == 0) {
      throw Exception(
        "Invalid dimensions for texture descriptor : ${width}x${height}",
      );
    }

    late PlatformTextureDescriptor descriptor;
    if (Platform.isMacOS || Platform.isIOS) {
      descriptor = DarwinPlatformTextureDescriptorImpl.allocate(width, height);
    } else {
      descriptor = await MethodChannelPlatformTextureDescriptor.allocate(
          channel, width, height);
    }

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
        textureFormat: TextureFormat.RGBA32F,
        // options.renderTargetColorTextureFormat,
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
        textureFormat: TextureFormat.DEPTH32F,
        //options.renderTargetDepthTextureFormat,
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

    texture.destroy();

    return newTexture;
  }
}

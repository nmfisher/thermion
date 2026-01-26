import 'dart:async';
import 'dart:io';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:thermion_flutter/src/platform/src/darwin_platform_texture_descriptor.dart';
import 'package:thermion_flutter/src/platform/src/method_channel_platform_texture_descriptor.dart';
import '../../../thermion_flutter.dart';
import 'platform_texture_descriptor.dart';
// ignore: implementation_imports
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';

// Handles all platform-specific initialization to create a backing rendering
// surface in a Flutter application and lifecycle listeners to pause rendering
// when the app is inactive or in the background.
class ThermionFlutterPluginImpl extends ThermionFlutterPlugin {
  final channel = const MethodChannel("dev.thermion.flutter/event");

  static final _logger = Logger("ThermionFlutterPluginImpl");

  static ThermionFlutterPluginImpl get instance =>
      ThermionFlutterPlugin.instance as ThermionFlutterPluginImpl;

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

  static final _descriptors = <PlatformTextureDescriptor>[];
  static final _destroyed = <PlatformTextureDescriptor>[];

  static void _flutterBeginFrame(Duration timestamp) async {
    await FilamentApp.instance?.render();

    for (final descriptor in _descriptors) {
      if (!descriptor.destroyed) {
        descriptor.markTextureFrameAvailable();
        descriptor.onBeginFrame?.call(timestamp);
      }
    }
    for (final descriptor in _destroyed) {
      _descriptors.remove(descriptor);
      _logger.info(
          "Removed descriptor (hardware ID ${descriptor.hardwareId}, flutter ID ${descriptor.flutterTextureId}");
    }
    _destroyed.clear();
    SchedulerBinding.instance.scheduleFrame();
  }

  @override
  Future<SwapChain?> initialize({bool destroySwapchain = true}) async {
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
    if (options.nativeOptions.backend != null) {
      switch (options.nativeOptions.backend) {
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
      backend = options.nativeOptions.backend!;
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
      });
    }

    SwapChain? swapChain;

    // on MacOS/iOS, even though we render directly into a render target,
    // for some reason we still need to create a headless swapchain (though the
    // dimensions don't seem to matter).
    // TODO - see if we can use `renderStandaloneView` in FilamentViewer to
    // avoid this
    if (Platform.isMacOS || Platform.isIOS || Platform.isWindows) {
      swapChain ??= await FilamentApp.instance!
          .createHeadlessSwapChain(1, 1, hasStencilBuffer: true);
    }

    SchedulerBinding.instance.addPersistentFrameCallback(_flutterBeginFrame);

    return swapChain;
  }

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

    if (Platform.isAndroid) {
      final swapChain = await FilamentApp.instance!.createSwapChain(
        Pointer<Void>.fromAddress(descriptor.windowHandle!),
      );

      final existingSwapChain = await FilamentApp.instance!.getSwapChain(view);
      
      await FilamentApp.instance!.register(swapChain, view);
      
      if (existingSwapChain != null) {
        await FilamentApp.instance!.unregister(existingSwapChain, view);
        await FilamentApp.instance!.destroySwapChain(existingSwapChain);
      }
    } else {
      final swapChains = await FilamentApp.instance!.getSwapChains();
      final color = await FilamentApp.instance!.createTexture(
        descriptor.width,
        descriptor.height,
        importedTextureHandle: descriptor.hardwareId,
        flags: {
          TextureUsage.TEXTURE_USAGE_BLIT_SRC,
          TextureUsage.TEXTURE_USAGE_COLOR_ATTACHMENT,
          TextureUsage.TEXTURE_USAGE_SAMPLEABLE,
        },
        textureFormat: options.nativeOptions.renderTargetColorTextureFormat,
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
        textureFormat: options.nativeOptions.renderTargetDepthTextureFormat,
        textureSamplerType: TextureSamplerType.SAMPLER_2D,
      );

      final existingRenderTarget = await view.getRenderTarget();

      var renderTarget = await FilamentApp.instance!.createRenderTarget(
        descriptor.width,
        descriptor.height,
        color: color,
        depth: depth,
      );

      await view.setRenderTarget(renderTarget);

      if (existingRenderTarget != null) {
        final color = await existingRenderTarget.getColorTexture();
        final depth = await existingRenderTarget.getDepthTexture();
        await color.destroy();
        await depth.destroy();
        await existingRenderTarget.destroy();
      }
      await FilamentApp.instance!.register(swapChains.first, view);

    }

    await view.setViewport(width, height);

    _descriptors.add(descriptor);

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

    _descriptors.remove(texture);

    texture.destroy();

    return newTexture;
  }
}

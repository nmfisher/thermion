import 'dart:async';
import 'dart:ffi';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/thermion_dart.dart' as t;
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:logging/logging.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_window.dart';

///
/// An abstract implementation of [ThermionFlutterPlatform] that uses
/// Flutter platform channels to create a rendering context,
/// resource loaders, and surface/render target(s).
///
class ThermionFlutterMethodChannelPlatform extends ThermionFlutterPlatform {
  final channel = const MethodChannel("dev.thermion.flutter/event");
  final _logger = Logger("ThermionFlutterMethodChannelPlatform");

  static SwapChain? _swapChain;

  ThermionFlutterMethodChannelPlatform._();

  static ThermionFlutterMethodChannelPlatform? instance;

  static void registerWith() {
    instance ??= ThermionFlutterMethodChannelPlatform._();
    ThermionFlutterPlatform.instance = instance!;
  }

  t.ThermionViewerFFI? viewer;

  Future<ThermionViewer> createViewer({ThermionFlutterOptions? options}) async {
    if (viewer != null) {
      throw Exception(
          "Only one ThermionViewer can be created at any given time; ensure you have called [dispose] on the previous instance before constructing a new instance.");
    }

    var resourceLoader = Pointer<Void>.fromAddress(
        await channel.invokeMethod("getResourceLoaderWrapper"));

    if (resourceLoader == nullptr) {
      throw Exception("Failed to get resource loader");
    }

    var driverPlatform = await channel.invokeMethod("getDriverPlatform");
    var driverPtr = driverPlatform == null
        ? nullptr
        : Pointer<Void>.fromAddress(driverPlatform);

    var sharedContext = await channel.invokeMethod("getSharedContext");

    var sharedContextPtr = sharedContext == null
        ? nullptr
        : Pointer<Void>.fromAddress(sharedContext);

    viewer = ThermionViewerFFI(
        resourceLoader: resourceLoader,
        driver: driverPtr,
        sharedContext: sharedContextPtr,
        uberArchivePath: options?.uberarchivePath);
    await viewer!.initialized;

    viewer!.onDispose(() async {
      _swapChain = null;
      this.viewer = null;
    });

    if (_swapChain != null) {
      throw Exception("Only a single swapchain can be created");
    }

    // this implementation renders directly into a texture/render target
    // for some reason we still need to create a (headless) swapchain, but the
    // actual dimensions don't matter
    // TODO - see if we can use `renderStandaloneView` in FilamentViewer to
    // avoid this
    if (Platform.isMacOS || Platform.isIOS) {
      _swapChain = await viewer!.createHeadlessSwapChain(1, 1);
    }

    return viewer!;
  }

  Future<PlatformTextureDescriptor> createTextureDescriptor(
      int width, int height) async {
    var result =
        await channel.invokeMethod("createTexture", [width, height, 0, 0]);
    if (result == null || (result[0] == -1)) {
      throw Exception("Failed to create texture");
    }
    final flutterId = result[0] as int;
    final hardwareId = result[1] as int;
    var window = result[2] as int?; // usually 0 for nullptr

    return PlatformTextureDescriptor(flutterId, hardwareId, window, width, height);
      
  }

  @override
  Future destroyTextureDescriptor(PlatformTextureDescriptor descriptor) async {
    await channel.invokeMethod("destroyTexture", descriptor.flutterTextureId);
  }

  ///
  ///
  ///
  Future<PlatformTextureDescriptor?> createTextureAndBindToView(
      t.View view, int width, int height) async {
    var descriptor = await createTextureDescriptor(width, height);
    

    if (Platform.isWindows) {
      if (_swapChain != null) {
        await view.setRenderable(false, _swapChain!);
        await viewer!.destroySwapChain(_swapChain!);
      }

      _swapChain =
          await viewer!.createHeadlessSwapChain(descriptor.width, descriptor.height);
    } else if (Platform.isAndroid) {
      if (_swapChain != null) {
        await view.setRenderable(false, _swapChain!);
        await viewer!.destroySwapChain(_swapChain!);
      }
      _swapChain = await viewer!.createSwapChain(descriptor.windowHandle!);
    } else {
      var renderTarget = await viewer!.createRenderTarget(
          descriptor.width, descriptor.height, descriptor.hardwareId);

      await view.setRenderTarget(renderTarget!);
    }
    await view.setRenderable(true, _swapChain!);

    return descriptor;
  }

  @override
  Future markTextureFrameAvailable(PlatformTextureDescriptor texture) async {
    await channel.invokeMethod("markTextureFrameAvailable", texture.flutterTextureId);
  }

  @override
  Future<PlatformTextureDescriptor> resizeTexture(PlatformTextureDescriptor texture,
      t.View view, int width, int height) async {
    var newTexture = await createTextureAndBindToView(view, width, height);
    if (newTexture == null) {
      throw Exception();
    }

    await destroyTextureDescriptor(texture);

    return newTexture;
  }
}

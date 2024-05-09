import 'dart:async';
import 'dart:ffi';

import 'package:dart_filament/dart_filament.dart';
import 'package:flutter/services.dart';

import 'package:flutter_filament/filament/flutter_filament_texture.dart';

///
/// A subclass of [FilamentViewer] that uses Flutter platform channels
/// to create rendering contexts, callbacks and surfaces (either backing texture(s).
///
class FlutterFilamentPlugin extends FilamentViewer {
  final MethodChannel _channel;

  FlutterFilamentPlugin._(this._channel,
      {super.renderCallback,
      super.renderCallbackOwner,
      required super.resourceLoader,
      super.driver,
      super.sharedContext,
      super.uberArchivePath});

  static Future<FlutterFilamentPlugin> create({String? uberArchivePath}) async {
    var channel = const MethodChannel("app.polyvox.filament/event");
    var resourceLoader = Pointer<ResourceLoaderWrapper>.fromAddress(
        await channel.invokeMethod("getResourceLoaderWrapper"));

    if (resourceLoader == nullptr) {
      throw Exception("Failed to get resource loader");
    }

    var renderCallbackResult = await channel.invokeMethod("getRenderCallback");
    var renderCallback =
        Pointer<NativeFunction<Void Function(Pointer<Void>)>>.fromAddress(
            renderCallbackResult[0]);
    var renderCallbackOwner =
        Pointer<Void>.fromAddress(renderCallbackResult[1]);

    var driverPlatform = await channel.invokeMethod("getDriverPlatform");
    var driverPtr = driverPlatform == null
        ? nullptr
        : Pointer<Void>.fromAddress(driverPlatform);

    var sharedContext = await channel.invokeMethod("getSharedContext");

    var sharedContextPtr = sharedContext == null
        ? nullptr
        : Pointer<Void>.fromAddress(sharedContext);

    var plugin = FlutterFilamentPlugin._(channel,
        renderCallback: renderCallback,
        renderCallbackOwner: renderCallbackOwner,
        resourceLoader: resourceLoader,
        driver: driverPtr,
        sharedContext: sharedContextPtr,
        uberArchivePath: uberArchivePath);
    await plugin.initialized;
    return plugin;
  }

  Future<FlutterFilamentTexture?> createTexture(
      int width, int height, int offsetLeft, int offsetRight) async {
    var result = await _channel
        .invokeMethod("createTexture", [width, height, offsetLeft, offsetLeft]);

    if (result == null || result[0] == -1) {
      throw Exception("Failed to create texture");
    }
    viewportDimensions = (width.toDouble(), height.toDouble());
    var texture =
        FlutterFilamentTexture(result[0], result[1], width, height, result[2]);

    await createSwapChain(width.toDouble(), height.toDouble(),
        surface: texture.surface);

    if (texture.hardwareTextureId != null) {
      var renderTarget = await createRenderTarget(
          width.toDouble(), height.toDouble(), texture.hardwareTextureId!);
    }
    await updateViewportAndCameraProjection(
        width.toDouble(), height.toDouble());
    this.render();
    return texture;
  }

  Future destroyTexture(FlutterFilamentTexture texture) async {
    await _channel.invokeMethod("destroyTexture", texture.flutterTextureId);
  }

  @override
  Future<FlutterFilamentTexture?> resizeTexture(FlutterFilamentTexture texture,
      int width, int height, int offsetLeft, int offsetRight) async {
    if ((width - viewportDimensions.$1).abs() < 0.001 ||
        (height - viewportDimensions.$2).abs() < 0.001) {
      return texture;
    }
    bool wasRendering = rendering;
    await setRendering(false);
    await destroySwapChain();
    await destroyTexture(texture);

    var newTexture =
        await createTexture(width, height, offsetLeft, offsetRight);
    if (newTexture == null || newTexture.flutterTextureId == -1) {
      throw Exception("Failed to create texture");
    }
    await createSwapChain(width.toDouble(), height.toDouble(),
        surface: newTexture.surface!);

    if (newTexture!.hardwareTextureId != null) {
      await createRenderTarget(
          width.toDouble(), height.toDouble(), newTexture!.hardwareTextureId!);
    }
    await updateViewportAndCameraProjection(
        width.toDouble(), height.toDouble());
    viewportDimensions = (width.toDouble(), height.toDouble());
    if (wasRendering) {
      await setRendering(true);
    }
    return newTexture;
    // await _channel.invokeMethod("resizeTexture",
    //     [texture.flutterTextureId, width, height, offsetLeft, offsetRight]);
  }
}

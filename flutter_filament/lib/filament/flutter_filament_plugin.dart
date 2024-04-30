import 'dart:async';
import 'dart:ffi';

import 'package:dart_filament/dart_filament.dart';
import 'package:flutter/services.dart';

import 'package:flutter_filament/filament/flutter_filament_texture.dart';

///
/// A subclass of [FilamentViewer] that uses Flutter platform channels
/// to create rendering contexts, callbacks and surfaces (either backing texture(s).
///
///
class FlutterFilamentPlugin extends FilamentViewer {
  final MethodChannel _channel;

  FlutterFilamentPlugin._(this._channel,
      {super.renderCallback,
      super.renderCallbackOwner,
      super.surface,
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

    var window = await channel.invokeMethod("getWindow");
    var windowPtr =
        window == null ? nullptr : Pointer<Void>.fromAddress(window);

    return FlutterFilamentPlugin._(channel,
        renderCallback: renderCallback,
        renderCallbackOwner: renderCallbackOwner,
        surface: windowPtr,
        resourceLoader: resourceLoader,
        driver: driverPtr,
        sharedContext: sharedContextPtr,
        uberArchivePath: uberArchivePath);
  }

  Future<FlutterFilamentTexture?> createTexture(
      int width, int height, int offsetLeft, int offsetRight) async {
    var result = await _channel
        .invokeMethod("createTexture", [width, height, offsetLeft, offsetLeft]);
    if (result == null) {
      return null;
    }
    viewportDimensions = (width.toDouble(), height.toDouble());
    var texture = FlutterFilamentTexture(result[0], result[1], width, height);
    await createSwapChain(width.toDouble(), height.toDouble());

    var renderTarget = await createRenderTarget(
        width.toDouble(), height.toDouble(), texture.hardwareTextureId);
    return texture;
  }

  Future destroyTexture(FlutterFilamentTexture texture) async {
    await _channel.invokeMethod("destroyTexture", texture.flutterTextureId);
  }

  @override
  Future resizeTexture(FlutterFilamentTexture texture, int width, int height,
      int offsetLeft, int offsetRight) async {
    await destroySwapChain();
    await destroyTexture(texture);
    await createSwapChain(width.toDouble(), height.toDouble());

    var newTexture =
        await createTexture(width, height, offsetLeft, offsetRight);
    await createRenderTarget(
        width.toDouble(), height.toDouble(), newTexture!.hardwareTextureId);
    await updateViewportAndCameraProjection(
        width.toDouble(), height.toDouble());
    viewportDimensions = (width.toDouble(), height.toDouble());
    return newTexture;
    // await _channel.invokeMethod("resizeTexture",
    //     [texture.flutterTextureId, width, height, offsetLeft, offsetRight]);
  }
}

import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:ffi';
import 'package:dart_filament/dart_filament.dart';
import 'package:flutter_filament_platform_interface/flutter_filament_platform_interface.dart';
import 'package:flutter_filament_platform_interface/flutter_filament_texture.dart';

///
/// A subclass of [FilamentViewer] that uses Flutter platform channels
/// to create rendering contexts, callbacks and surfaces (either backing texture(s).
///
class FlutterFilamentFFI extends FlutterFilamentPlatform {
  final _channel = const MethodChannel("app.polyvox.filament/event");

  late final FilamentViewer viewer;

  static void registerWith() {
    FlutterFilamentPlatform.instance = FlutterFilamentFFI();
  }

  Future initialize({String? uberArchivePath}) async {
    var resourceLoader = Pointer<Void>.fromAddress(
        await _channel.invokeMethod("getResourceLoaderWrapper"));

    if (resourceLoader == nullptr) {
      throw Exception("Failed to get resource loader");
    }

    var renderCallbackResult = await _channel.invokeMethod("getRenderCallback");
    var renderCallback =
        Pointer<NativeFunction<Void Function(Pointer<Void>)>>.fromAddress(
            renderCallbackResult[0]);
    var renderCallbackOwner =
        Pointer<Void>.fromAddress(renderCallbackResult[1]);

    var driverPlatform = await _channel.invokeMethod("getDriverPlatform");
    var driverPtr = driverPlatform == null
        ? nullptr
        : Pointer<Void>.fromAddress(driverPlatform);

    var sharedContext = await _channel.invokeMethod("getSharedContext");

    var sharedContextPtr = sharedContext == null
        ? nullptr
        : Pointer<Void>.fromAddress(sharedContext);

    viewer = FilamentViewer(
        resourceLoader: resourceLoader,
        renderCallback: renderCallback,
        renderCallbackOwner: renderCallbackOwner,
        driver: driverPtr,
        sharedContext: sharedContextPtr,
        uberArchivePath: uberArchivePath);
  }

  Future<FlutterFilamentTexture?> createTexture(
      int width, int height, int offsetLeft, int offsetRight) async {
    var result = await _channel
        .invokeMethod("createTexture", [width, height, offsetLeft, offsetLeft]);

    if (result == null || result[0] == -1) {
      throw Exception("Failed to create texture");
    }
    viewer.viewportDimensions = (width.toDouble(), height.toDouble());
    var texture =
        FlutterFilamentTexture(result[0], result[1], width, height, result[2]);

    await viewer.createSwapChain(width.toDouble(), height.toDouble(),
        surface: texture.surfaceAddress == null
            ? nullptr
            : Pointer<Void>.fromAddress(texture.surfaceAddress!));

    if (texture.hardwareTextureId != null) {
      var renderTarget = await viewer.createRenderTarget(
          width.toDouble(), height.toDouble(), texture.hardwareTextureId!);
    }
    await viewer.updateViewportAndCameraProjection(
        width.toDouble(), height.toDouble());
    viewer.render();
    return texture;
  }

  Future destroyTexture(FlutterFilamentTexture texture) async {
    await _channel.invokeMethod("destroyTexture", texture.flutterTextureId);
  }

  bool _resizing = false;

  @override
  Future<FlutterFilamentTexture?> resizeTexture(FlutterFilamentTexture texture,
      int width, int height, int offsetLeft, int offsetRight) async {
    if (_resizing) {
      throw Exception("Resize underway");
    }

    if ((width - viewer.viewportDimensions.$1).abs() < 0.001 ||
        (height - viewer.viewportDimensions.$2).abs() < 0.001) {
      return texture;
    }
    _resizing = true;
    bool wasRendering = viewer.rendering;
    await viewer.setRendering(false);
    await viewer.destroySwapChain();
    print("Destoryign texture");
    await destroyTexture(texture);
    print("DEstrooyed!");

    var result = await _channel
        .invokeMethod("createTexture", [width, height, offsetLeft, offsetLeft]);

    if (result == null || result[0] == -1) {
      throw Exception("Failed to create texture");
    }
    viewer.viewportDimensions = (width.toDouble(), height.toDouble());
    var newTexture =
        FlutterFilamentTexture(result[0], result[1], width, height, result[2]);

    await viewer.createSwapChain(width.toDouble(), height.toDouble(),
        surface: newTexture.surfaceAddress == null
            ? nullptr
            : Pointer<Void>.fromAddress(newTexture.surfaceAddress!));

    if (newTexture.hardwareTextureId != null) {
      var renderTarget = await viewer.createRenderTarget(
          width.toDouble(), height.toDouble(), newTexture.hardwareTextureId!);
    }
    await viewer.updateViewportAndCameraProjection(
        width.toDouble(), height.toDouble());

    viewer.viewportDimensions = (width.toDouble(), height.toDouble());
    if (wasRendering) {
      await viewer.setRendering(true);
    }
    _resizing = false;
    return newTexture;
    // await _channel.invokeMethod("resizeTexture",
    //     [texture.flutterTextureId, width, height, offsetLeft, offsetRight]);
  }

  @override
  void dispose() {
    // TODO: implement dispose
  }
}

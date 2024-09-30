import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:ffi';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/viewer/src/ffi/thermion_viewer_ffi.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:logging/logging.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';

///
/// An abstract implementation of [ThermionFlutterPlatform] that uses
/// Flutter platform channels to create a rendering context,
/// resource loaders, and surface/render target(s).
///
abstract class ThermionFlutterMethodChannelInterface
    extends ThermionFlutterPlatform {
  final _channel = const MethodChannel("dev.thermion.flutter/event");
  final _logger = Logger("ThermionFlutterMethodChannelInterface");

  ThermionViewerFFI? viewer;
  SwapChain? _swapChain;

  Future<ThermionViewer> createViewer({ThermionFlutterOptions? options}) async {
    if (viewer != null) {
      throw Exception(
          "Only one viewer can be created over the lifetime of an application");
    }

    var resourceLoader = Pointer<Void>.fromAddress(
        await _channel.invokeMethod("getResourceLoaderWrapper"));

    if (resourceLoader == nullptr) {
      throw Exception("Failed to get resource loader");
    }

    // var renderCallbackResult = await _channel.invokeMethod("getRenderCallback");
    var renderCallback = nullptr;
    //     Pointer<NativeFunction<Void Function(Pointer<Void>)>>.fromAddress(
    //         renderCallbackResult[0]);
    var renderCallbackOwner = nullptr;
    //     Pointer<Void>.fromAddress(renderCallbackResult[1]);

    var driverPlatform = await _channel.invokeMethod("getDriverPlatform");
    var driverPtr = driverPlatform == null
        ? nullptr
        : Pointer<Void>.fromAddress(driverPlatform);

    var sharedContext = await _channel.invokeMethod("getSharedContext");

    var sharedContextPtr = sharedContext == null
        ? nullptr
        : Pointer<Void>.fromAddress(sharedContext);

    viewer = ThermionViewerFFI(
        resourceLoader: resourceLoader,
        renderCallback: renderCallback,
        renderCallbackOwner: renderCallbackOwner,
        driver: driverPtr,
        sharedContext: sharedContextPtr,
        uberArchivePath: options?.uberarchivePath);
    await viewer!.initialized;

    return viewer!;
  }
}

abstract class MethodChannelFlutterTexture extends ThermionFlutterTexture {
  final MethodChannel channel;

  MethodChannelFlutterTexture(this.channel);

  Future destroy() async {
    await channel.invokeMethod("destroyTexture", hardwareId);
  }

  @override
  int get flutterId;

  @override
  int get hardwareId;

  @override
  int get height;

  @override
  int get width;

  Future markFrameAvailable() async {
    await channel.invokeMethod("markTextureFrameAvailable", this.flutterId);
  }
}

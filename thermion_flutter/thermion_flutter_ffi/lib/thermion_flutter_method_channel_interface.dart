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
  final channel = const MethodChannel("dev.thermion.flutter/event");
  final _logger = Logger("ThermionFlutterMethodChannelInterface");

  ThermionViewerFFI? viewer;

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
      this.viewer = null;
    });

    return viewer!;
  }
}

abstract class MethodChannelFlutterTexture extends ThermionFlutterTexture {
  final MethodChannel channel;

  MethodChannelFlutterTexture(this.channel);

  @override
  int get flutterId;

  @override
  int get hardwareId;

  @override
  int get height;

  @override
  int get width;
}

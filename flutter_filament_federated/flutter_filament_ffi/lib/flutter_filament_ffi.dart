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

  final _textures = <FlutterFilamentTexture>{};

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
    await viewer.initialized;
  }

  bool _creatingTexture = false;

  Future _waitForTextureCreationToComplete() async {
    var iter = 0;

    while (_creatingTexture) {
      await Future.delayed(Duration(milliseconds: 50));
      iter++;
      if (iter > 10) {
        throw Exception(
            "Previous call to createTexture failed to complete within 500ms");
      }
    }
  }

  ///
  /// Create a backing surface for rendering.
  /// This is called by [FilamentWidget]; don't call this yourself.
  ///
  /// The name here is slightly misleading because we only create
  /// a texture render target on macOS and iOS; on Android, we render into
  /// a native window derived from a Surface, and on Windows we render into
  /// a HWND.
  ///
  /// Currently, this only supports a single "texture" (aka rendering surface)
  /// at any given time. If a [FilamentWidget] is disposed, it will call
  /// [destroyTexture]; if it is resized, it will call [resizeTexture].
  ///
  /// In future, we probably want to be able to create multiple distinct
  /// textures/render targets. This would make it possible to have multiple
  /// Flutter Texture widgets, each with its own Filament View attached.
  /// The current design doesn't accommodate this (for example, it seems we can
  /// only create a single native window from a Surface at any one time).
  ///
  Future<FlutterFilamentTexture?> createTexture(
      int width, int height, int offsetLeft, int offsetRight) async {
    // when a FilamentWidget is inserted, disposed then immediately reinserted
    // into the widget hierarchy (e.g. rebuilding due to setState(() {}) being called in an ancestor widget)
    // the first call to createTexture may not have completed before the second.
    // add a loop here to wait (max 500ms) for the first call to complete
    await _waitForTextureCreationToComplete();

    // note that when [FilamentWidget] is disposed, we don't destroy the
    // texture; instead, we keep it around in case a subsequent call requests
    // a texture of the same size.

    if (_textures.length > 1) {
      throw Exception("Multiple textures not yet supported");
    } else if (_textures.length == 1 &&
        _textures.first.height == height &&
        _textures.first.width == width) {
      return _textures.first;
    }

    _creatingTexture = true;

    var result = await _channel
        .invokeMethod("createTexture", [width, height, offsetLeft, offsetLeft]);

    if (result == null || result[0] == -1) {
      throw Exception("Failed to create texture");
    }
    final flutterTextureId = result[0] as int;
    final hardwareTextureId = result[1] as int?;
    final surfaceAddress = result[2] as int?;

    print(
        "Created texture with flutter texture id ${flutterTextureId}, hardwareTextureId $hardwareTextureId and surfaceAddress $surfaceAddress");

    viewer.viewportDimensions = (width.toDouble(), height.toDouble());
    var texture = FlutterFilamentTexture(
        flutterTextureId, hardwareTextureId, width, height, surfaceAddress);

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
    _creatingTexture = false;
    _textures.add(texture);
    return texture;
  }

  ///
  /// Called by [FilamentWidget] to destroy a texture. Don't call this yourself.
  ///
  Future destroyTexture(FlutterFilamentTexture texture) async {
    await _channel.invokeMethod("destroyTexture", texture.flutterTextureId);
    _textures.remove(texture);
  }

  bool _resizing = false;

  ///
  /// Called by [FilamentWidget] to resize a texture. Don't call this yourself.
  ///
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
    await destroyTexture(texture);

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
    _textures.add(newTexture);
    _resizing = false;
    return newTexture;
  }

  @override
  void dispose() {
    // TODO: implement dispose
  }
}

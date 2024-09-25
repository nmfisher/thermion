import 'dart:async';
import 'package:flutter/services.dart';
import 'dart:ffi';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/thermion_dart/viewer/ffi/thermion_viewer_ffi.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';
import 'package:logging/logging.dart';

///
/// An implementation of [ThermionFlutterPlatform] that uses a Flutter platform
/// channel to create a rendering context, resource loaders, and
/// render target(s).
///
class ThermionFlutterFFI extends ThermionFlutterPlatform {
  final _channel = const MethodChannel("dev.thermion.flutter/event");
  final _logger = Logger("ThermionFlutterFFI");

  ThermionViewerFFI? _viewer;

  ThermionFlutterFFI._() {}

  static void registerWith() {
    ThermionFlutterPlatform.instance = ThermionFlutterFFI._();
  }

  final _textures = <ThermionFlutterTexture>{};

  Future<ThermionViewer> createViewerWithOptions(
      ThermionFlutterOptions options) async {
    return createViewer(uberarchivePath: options.uberarchivePath);
  }

  Future<ThermionViewer> createViewer({String? uberarchivePath}) async {
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

    _viewer = ThermionViewerFFI(
        resourceLoader: resourceLoader,
        renderCallback: renderCallback,
        renderCallbackOwner: renderCallbackOwner,
        driver: driverPtr,
        sharedContext: sharedContextPtr,
        uberArchivePath: uberarchivePath);
    await _viewer!.initialized;
    return _viewer!;
  }

  bool _creatingTexture = false;
  bool _destroyingTexture = false;

  Future _waitForTextureCreationToComplete() async {
    var iter = 0;

    while (_creatingTexture || _destroyingTexture) {
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
  /// This is called by [ThermionWidget]; don't call this yourself.
  ///
  /// The name here is slightly misleading because we only create
  /// a texture render target on macOS and iOS; on Android, we render into
  /// a native window derived from a Surface, and on Windows we render into
  /// a HWND.
  ///
  /// Currently, this only supports a single "texture" (aka rendering surface)
  /// at any given time. If a [ThermionWidget] is disposed, it will call
  /// [destroyTexture]; if it is resized, it will call [resizeTexture].
  ///
  /// In future, we probably want to be able to create multiple distinct
  /// textures/render targets. This would make it possible to have multiple
  /// Flutter Texture widgets, each with its own Filament View attached.
  /// The current design doesn't accommodate this (for example, it seems we can
  /// only create a single native window from a Surface at any one time).
  ///
  Future<ThermionFlutterTexture?> createTexture(double width, double height,
      double offsetLeft, double offsetRight, double pixelRatio) async {
    final physicalWidth = (width * pixelRatio).ceil();
    final physicalHeight = (height * pixelRatio).ceil();
    // when a ThermionWidget is inserted, disposed then immediately reinserted
    // into the widget hierarchy (e.g. rebuilding due to setState(() {}) being called in an ancestor widget)
    // the first call to createTexture may not have completed before the second.
    // add a loop here to wait (max 500ms) for the first call to complete
    await _waitForTextureCreationToComplete();

    // note that when [ThermionWidget] is disposed, we don't destroy the
    // texture; instead, we keep it around in case a subsequent call requests
    // a texture of the same size.

    if (_textures.length > 1) {
      throw Exception("Multiple textures not yet supported");
    } else if (_textures.length == 1) {
      if (_textures.first.height == physicalHeight &&
          _textures.first.width == physicalWidth) {
        return _textures.first;
      } else {
        await _viewer!.setRendering(false);
        await _viewer!.destroySwapChain();
        await destroyTexture(_textures.first);
        _textures.clear();
      }
    }

    _creatingTexture = true;

    var result = await _channel.invokeMethod("createTexture",
        [physicalWidth, physicalHeight, offsetLeft, offsetLeft]);

    if (result == null || (result[0] == -1)) {
      throw Exception("Failed to create texture");
    }
    final flutterTextureId = result[0] as int?;
    final hardwareTextureId = result[1] as int?;
    final surfaceAddress = result[2] as int?;

    _logger.info(
        "Created texture with flutter texture id ${flutterTextureId}, hardwareTextureId $hardwareTextureId and surfaceAddress $surfaceAddress");

    _viewer?.viewportDimensions =
        (physicalWidth.toDouble(), physicalHeight.toDouble());

    final texture = ThermionFlutterTexture(flutterTextureId, hardwareTextureId,
        physicalWidth, physicalHeight, surfaceAddress);

    await _viewer?.createSwapChain(
        physicalWidth.toDouble(), physicalHeight.toDouble(),
        surface: texture.surfaceAddress == null
            ? nullptr
            : Pointer<Void>.fromAddress(texture.surfaceAddress!));

    if (texture.hardwareTextureId != null) {
      // ignore: unused_local_variable
      var renderTarget = await _viewer?.createRenderTarget(
          physicalWidth.toDouble(),
          physicalHeight.toDouble(),
          texture.hardwareTextureId!);
    }

    await _viewer?.updateViewportAndCameraProjection(
        physicalWidth.toDouble(), physicalHeight.toDouble());
    _viewer?.render();
    _creatingTexture = false;

    _textures.add(texture);

    return texture;
  }

  ///
  /// Destroy a texture and clean up the texture cache (if applicable).
  ///
  Future destroyTexture(ThermionFlutterTexture texture) async {
    if (_creatingTexture || _destroyingTexture) {
      throw Exception(
          "Cannot destroy texture while concurrent call to createTexture/destroyTexture has not completed");
    }
    _destroyingTexture = true;
    _textures.remove(texture);
    await _channel.invokeMethod("destroyTexture", texture.flutterTextureId);
    _destroyingTexture = false;
  }

  bool _resizing = false;

  ///
  /// Called by [ThermionWidget] to resize a texture. Don't call this yourself.
  ///
  @override
  Future<ThermionFlutterTexture?> resizeTexture(
      ThermionFlutterTexture texture,
      int width,
      int height,
      int offsetLeft,
      int offsetTop,
      double pixelRatio) async {
    if (_resizing) {
      throw Exception("Resize underway");
    }

    width = (width * pixelRatio).ceil();
    height = (height * pixelRatio).ceil();

    if ((width - _viewer!.viewportDimensions.$1).abs() < 0.001 ||
        (height - _viewer!.viewportDimensions.$2).abs() < 0.001) {
      return texture;
    }
    _resizing = true;
    bool wasRendering = _viewer!.rendering;
    await _viewer!.setRendering(false);
    await _viewer!.destroySwapChain();
    await destroyTexture(texture);

    var result = await _channel
        .invokeMethod("createTexture", [width, height, offsetLeft, offsetLeft]);

    if (result == null || result[0] == -1) {
      throw Exception("Failed to create texture");
    }
    _viewer!.viewportDimensions = (width.toDouble(), height.toDouble());
    var newTexture =
        ThermionFlutterTexture(result[0], result[1], width, height, result[2]);

    await _viewer!.createSwapChain(width.toDouble(), height.toDouble(),
        surface: newTexture.surfaceAddress == null
            ? nullptr
            : Pointer<Void>.fromAddress(newTexture.surfaceAddress!));

    if (newTexture.hardwareTextureId != null) {
      // ignore: unused_local_variable
      var renderTarget = await _viewer!.createRenderTarget(
          width.toDouble(), height.toDouble(), newTexture.hardwareTextureId!);
    }
    await _viewer!
        .updateViewportAndCameraProjection(width.toDouble(), height.toDouble());

    _viewer!.viewportDimensions = (width.toDouble(), height.toDouble());
    if (wasRendering) {
      await _viewer!.setRendering(true);
    }
    _textures.add(newTexture);
    _resizing = false;
    return newTexture;
  }
}

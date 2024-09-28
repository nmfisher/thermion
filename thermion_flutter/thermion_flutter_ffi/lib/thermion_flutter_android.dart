import 'dart:async';
import 'package:flutter/services.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/viewer/src/ffi/thermion_viewer_ffi.dart';
import 'package:thermion_flutter_ffi/thermion_flutter_method_channel_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';
import 'package:logging/logging.dart';

///
/// An implementation of [ThermionFlutterPlatform] that uses
/// Flutter platform channels to create a rendering context,
/// resource loaders, and surface/render target(s).
///
class ThermionFlutterAndroid
    extends ThermionFlutterMethodChannelInterface {
  final _channel = const MethodChannel("dev.thermion.flutter/event");
  final _logger = Logger("ThermionFlutterFFI");

  ThermionViewerFFI? _viewer;

  ThermionFlutterAndroid._() {}

  RenderTarget? _renderTarget;
  SwapChain? _swapChain;

  static void registerWith() {
    ThermionFlutterPlatform.instance = ThermionFlutterAndroid._();
  }

  final _textures = <ThermionFlutterTexture>{};

  bool _creatingTexture = false;
  bool _destroyingTexture = false;

  bool _resizing = false;

  ///
  /// Create a rendering surface.
  ///
  /// This is internal; unless you are [thermion_*] package developer, don't
  /// call this yourself.
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
  Future<ThermionFlutterTexture?> createTexture(int width, int height) async {
    throw Exception("TODO");
    // note that when [ThermionWidget] is disposed, we don't destroy the
    // texture; instead, we keep it around in case a subsequent call requests
    // a texture of the same size.

    // if (_textures.length > 1) {
    //   throw Exception("Multiple textures not yet supported");
    // } else if (_textures.length == 1) {
    //   if (_textures.first.height == physicalHeight &&
    //       _textures.first.width == physicalWidth) {
    //     return _textures.first;
    //   } else {
    //     await _viewer!.setRendering(false);
    //     await _swapChain?.destroy();
    //     await destroyTexture(_textures.first);
    //     _textures.clear();
    //   }
    // }

    // _creatingTexture = true;

    // var result = await _channel.invokeMethod("createTexture",
    //     [physicalWidth, physicalHeight, offsetLeft, offsetLeft]);

    // if (result == null || (result[0] == -1)) {
    //   throw Exception("Failed to create texture");
    // }
    // final flutterTextureId = result[0] as int?;
    // final hardwareTextureId = result[1] as int?;
    // final surfaceAddress = result[2] as int?;

    // _logger.info(
    //     "Created texture with flutter texture id ${flutterTextureId}, hardwareTextureId $hardwareTextureId and surfaceAddress $surfaceAddress");

    // final texture = ThermionFlutterTexture(flutterTextureId, hardwareTextureId,
    //     physicalWidth, physicalHeight, surfaceAddress);

    // await _viewer?.createSwapChain(physicalWidth, physicalHeight,
    //     surface: texture.surfaceAddress == null
    //         ? nullptr
    //         : Pointer<Void>.fromAddress(texture.surfaceAddress!));

    // if (texture.hardwareTextureId != null) {
    //   if (_renderTarget != null) {
    //     await _renderTarget!.destroy();
    //   }
    //   // ignore: unused_local_variable
    //   _renderTarget = await _viewer?.createRenderTarget(
    //       physicalWidth, physicalHeight, texture.hardwareTextureId!);
    // }

    // await _viewer?.updateViewportAndCameraProjection(
    //     physicalWidth.toDouble(), physicalHeight.toDouble());
    // _creatingTexture = false;
    // _textures.add(texture);
    // return texture;
  }

  ///
  /// Called by [ThermionWidget] to resize a texture. Don't call this yourself.
  ///
  @override
  Future resizeWindow(
    int width,
    int height,
    int offsetLeft,
    int offsetTop,
  ) async {
    throw Exception("Not supported on iOS");
  }
}

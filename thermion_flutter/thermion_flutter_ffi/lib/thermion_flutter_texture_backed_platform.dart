import 'dart:async';
import 'dart:io';

import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/thermion_dart.dart' as t;
import 'package:thermion_flutter_ffi/thermion_flutter_method_channel_interface.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';
import 'package:logging/logging.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_texture.dart';

import 'platform_texture.dart';

///
/// An implementation of [ThermionFlutterPlatform] that uses
/// Flutter platform channels to create a rendering context,
/// resource loaders, and surface/render target(s).
///
class ThermionFlutterTextureBackedPlatform
    extends ThermionFlutterMethodChannelInterface {
  final _logger = Logger("ThermionFlutterTextureBackedPlatform");

  static SwapChain? _swapChain;

  ThermionFlutterTextureBackedPlatform._();

  static ThermionFlutterTextureBackedPlatform? instance;

  static void registerWith() {
    instance ??= ThermionFlutterTextureBackedPlatform._();
    ThermionFlutterPlatform.instance = instance!;
  }

  @override
  Future<ThermionViewer> createViewer({ThermionFlutterOptions? options}) async {
    var viewer = await super.createViewer(options: options);
    if (_swapChain != null) {
      throw Exception("Only a single swapchain can be created");
    }

    // this implementation renders directly into a texture/render target
    // we still need to create a (headless) swapchain, but the actual dimensions
    // don't matter
    if (Platform.isMacOS || Platform.isIOS) {
      _swapChain = await viewer.createHeadlessSwapChain(1, 1);
    }
    return viewer;
  }

  // On desktop platforms, textures are always created
  Future<ThermionFlutterTexture?> createTexture(t.View view, int width, int height) async {
    var texture = FlutterPlatformTexture(channel, viewer!, view, (Platform.isMacOS || Platform.isIOS)? _swapChain : null);
    await texture.resize(width, height, 0, 0);
    return texture;
  }

  // On MacOS, we currently use textures/render targets, so there's no window to resize
  @override
  Future<ThermionFlutterTexture?> resizeWindow(
      int width, int height, int offsetTop, int offsetRight) {
    throw UnimplementedError();
  }
}


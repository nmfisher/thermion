import 'dart:async';

import 'package:thermion_dart/thermion_dart.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'thermion_flutter_texture.dart';

class ThermionFlutterOptions {
  final String? uberarchivePath;
  final Backend? backend;

  const ThermionFlutterOptions(
      {this.uberarchivePath = null, this.backend = null});
}

class ThermionFlutterWebOptions extends ThermionFlutterOptions {
  
  final bool createCanvas;
  final bool importCanvasAsWidget;

  const ThermionFlutterWebOptions(
      {this.importCanvasAsWidget = false,
      this.createCanvas = true,
      String? uberarchivePath})
      : super(uberarchivePath: uberarchivePath);


}

abstract class ThermionFlutterPlatform extends PlatformInterface {
  ThermionFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static late final ThermionFlutterPlatform _instance;
  static ThermionFlutterPlatform get instance => _instance;

  ///
  ///
  ///
  ThermionFlutterOptions? _options;
  ThermionFlutterOptions get options {
    _options ??= const ThermionFlutterOptions();
    return _options!;
  }
  
  ///
  ///
  ///
  void setOptions(covariant ThermionFlutterOptions options) {
    if (_options != null) {
      throw Exception(
          "Options can only be set once for the entire app lifecycle.");
    }
    _options = options;
  }

  ///
  ///
  ///
  static set instance(ThermionFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  ///
  ///
  ///
  Future<ThermionViewer> createViewer() {
    throw UnimplementedError();
  }

  ///
  /// Creates a raw rendering surface.
  ///
  /// This is internal; unless you are [thermion_*] package developer, don't
  /// call this yourself. May not be supported on all platforms.
  ///
  Future<PlatformTextureDescriptor> createTextureDescriptor(
      int width, int height) {
    throw UnimplementedError();
  }

  ///
  /// Destroys a raw rendering surface.
  ///
  Future destroyTextureDescriptor(PlatformTextureDescriptor descriptor) {
    throw UnimplementedError();
  }

  ///
  /// Create a rendering surface and binds to the given [View]
  ///
  /// This is internal; unless you are [thermion_*] package developer, don't
  /// call this yourself. May not be supported on all platforms.
  ///
  Future<PlatformTextureDescriptor?> createTextureAndBindToView(
      View view, int width, int height) {
    throw UnimplementedError();
  }

  ///
  ///
  ///
  ///
  Future<PlatformTextureDescriptor?> resizeTexture(
      PlatformTextureDescriptor texture, View view, int width, int height) {
    throw UnimplementedError();
  }

  ///
  ///
  ///
  Future markTextureFrameAvailable(PlatformTextureDescriptor texture) {
    throw UnimplementedError();
  }
}

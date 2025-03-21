import 'dart:async';

import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_dart/src/filament/filament.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'thermion_flutter_texture.dart';

class ThermionFlutterOptions {
  final String? uberarchivePath;
  final Backend? backend;

  const ThermionFlutterOptions({this.uberarchivePath = null, this.backend = null});
}

abstract class ThermionFlutterPlatform extends PlatformInterface {
  ThermionFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static late final ThermionFlutterPlatform _instance;
  static ThermionFlutterPlatform get instance => _instance;

  static set instance(ThermionFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  ///
  ///
  ///
  Future<ThermionViewer> createViewer(
      {covariant ThermionFlutterOptions? options});

  ///
  /// Creates a raw rendering surface.
  ///
  /// This is internal; unless you are [thermion_*] package developer, don't
  /// call this yourself. May not be supported on all platforms.
  ///
  Future<PlatformTextureDescriptor> createTextureDescriptor(
      int width, int height);

  ///
  /// Destroys a raw rendering surface.
  ///
  Future destroyTextureDescriptor(PlatformTextureDescriptor descriptor);

  ///
  /// Create a rendering surface and binds to the given [View]
  ///
  /// This is internal; unless you are [thermion_*] package developer, don't
  /// call this yourself. May not be supported on all platforms.
  ///
  Future<PlatformTextureDescriptor?> createTextureAndBindToView(
      View view, int width, int height);

  ///
  ///
  ///
  ///
  Future<PlatformTextureDescriptor?> resizeTexture(
      PlatformTextureDescriptor texture, View view, int width, int height);

  ///
  ///
  ///
  Future markTextureFrameAvailable(PlatformTextureDescriptor texture);
}

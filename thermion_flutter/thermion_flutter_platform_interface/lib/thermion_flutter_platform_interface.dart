import 'dart:async';

import 'package:thermion_dart/thermion_dart.dart' as t;
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'thermion_flutter_texture.dart';

class ThermionFlutterOptions {
  final String? uberarchivePath;

  ThermionFlutterOptions({this.uberarchivePath});
  const ThermionFlutterOptions.empty() : uberarchivePath = null;
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
  /// Create a rendering surface.
  ///
  /// This is internal; unless you are [thermion_*] package developer, don't
  /// call this yourself. May not be supported on all platforms.
  ///
  Future<ThermionFlutterTexture?> createTexture(
      t.View view, int width, int height);

  ///
  ///
  ///
  Future resizeWindow(int width, int height, int offsetTop, int offsetRight);
}

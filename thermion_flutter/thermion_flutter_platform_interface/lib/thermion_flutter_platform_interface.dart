import 'dart:async';

import 'package:thermion_dart/thermion_dart/thermion_viewer.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'thermion_flutter_texture.dart';

abstract class ThermionFlutterOptions {
  final String? uberarchivePath;

  ThermionFlutterOptions({this.uberarchivePath});
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

  Future<ThermionViewer> createViewerWithOptions(
      covariant ThermionFlutterOptions options);

  @deprecated
  Future<ThermionViewer> createViewer({String? uberarchivePath});

  Future<ThermionFlutterTexture?> createTexture(double width, double height,
      double offsetLeft, double offsetTop, double pixelRatio);

  Future destroyTexture(ThermionFlutterTexture texture);

  Future<ThermionFlutterTexture?> resizeTexture(ThermionFlutterTexture texture,
      int width, int height, int offsetTop, int offsetRight, double pixelRatio);
}

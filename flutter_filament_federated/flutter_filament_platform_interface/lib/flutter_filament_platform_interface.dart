import 'dart:async';

import 'package:dart_filament/dart_filament/abstract_filament_viewer.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'flutter_filament_texture.dart';

abstract class FlutterFilamentPlatform extends PlatformInterface {
  FlutterFilamentPlatform() : super(token: _token);

  static final Object _token = Object();

  static late FlutterFilamentPlatform _instance;

  static FlutterFilamentPlatform get instance => _instance;

  static set instance(FlutterFilamentPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  AbstractFilamentViewer get viewer;

  Future initialize({String? uberArchivePath});

  Future<FlutterFilamentTexture?> createTexture(
      int width, int height, int offsetLeft, int offsetRight);

  Future destroyTexture(FlutterFilamentTexture texture);

  @override
  Future<FlutterFilamentTexture?> resizeTexture(FlutterFilamentTexture texture,
      int width, int height, int offsetLeft, int offsetRight);

  void dispose();
}

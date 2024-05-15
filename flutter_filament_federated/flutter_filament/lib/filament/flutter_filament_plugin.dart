import 'dart:async';
import 'package:dart_filament/dart_filament/abstract_filament_viewer.dart';
import 'package:flutter_filament_platform_interface/flutter_filament_platform_interface.dart';
import 'package:flutter_filament_platform_interface/flutter_filament_texture.dart';

///
/// A Flutter-only interface for creating an [AbstractFilamentViewer] .
///
class FlutterFilamentPlugin {
  AbstractFilamentViewer get viewer => FlutterFilamentPlatform.instance.viewer;

  final _initialized = Completer<bool>();
  Future<bool> get initialized => _initialized.future;

  Future initialize({String? uberArchivePath}) async {
    if (_initialized.isCompleted) {
      throw Exception("Instance already initialized");
    }
    await FlutterFilamentPlatform.instance
        .initialize(uberArchivePath: uberArchivePath);
    print("instance init completed");
    _initialized.complete(true);
    print("completed compelter");
    await viewer.initialized;
    print("viewer init complete");
  }

  Future<FlutterFilamentTexture?> createTexture(
      int width, int height, int offsetLeft, int offsetRight) async {
    return FlutterFilamentPlatform.instance
        .createTexture(width, height, offsetLeft, offsetRight);
  }

  Future destroyTexture(FlutterFilamentTexture texture) async {
    return FlutterFilamentPlatform.instance.destroyTexture(texture);
  }

  @override
  Future<FlutterFilamentTexture?> resizeTexture(FlutterFilamentTexture texture,
      int width, int height, int offsetLeft, int offsetRight) async {
    return FlutterFilamentPlatform.instance
        .resizeTexture(texture, width, height, offsetLeft, offsetRight);
  }

  void dispose() {
    FlutterFilamentPlatform.instance.dispose();
  }
}

import 'package:flutter/widgets.dart';
import 'package:polyvox_filament/view/filament_view.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

typedef FilamentViewCreatedCallback = void Function(int id);

abstract class FilamentViewPlatform extends PlatformInterface {
  FilamentViewPlatform() : super(token: _token);

  static final Object _token = Object();
  static final FilamentViewPlatform _instance = FilamentView();

  static FilamentViewPlatform get instance => _instance;

  Widget buildView(
    int creationId,
    FilamentViewCreatedCallback onFilamentViewCreated,
  ) {
    throw UnimplementedError('buildView() has not been implemented.');
  }
}

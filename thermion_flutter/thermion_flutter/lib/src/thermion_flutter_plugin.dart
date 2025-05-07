import 'dart:async';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';

///
/// Handles all platform-specific initialization to create a backing rendering
/// surface in a Flutter application and lifecycle listeners to pause rendering
/// when the app is inactive or in the background.
/// Call [createViewer] to create an instance of [ThermionViewer].
///
class ThermionFlutterPlugin {
  ThermionFlutterPlugin._();

  static Future<ThermionViewer> createViewer() {
    return ThermionFlutterPlatform.instance.createViewer();
  }

}

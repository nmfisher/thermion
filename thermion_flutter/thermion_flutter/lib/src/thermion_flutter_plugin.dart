import 'dart:async';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';

///
/// Handles all platform-specific initialization to create a backing rendering
/// surface in a Flutter application and lifecycle listeners to pause rendering
/// when the app is inactive or in the background.
/// Call [createViewerWithOptions] to create an instance of [ThermionViewer].
///
class ThermionFlutterPlugin {

  ThermionFlutterPlugin._();

  static bool _initializing = false;

  static ThermionViewer? _viewer;

  static Future<ThermionViewer> createViewer(
      {ThermionFlutterOptions options =
          const ThermionFlutterOptions.empty()}) async {
    
    if (_initializing) {
      throw Exception("Existing call to createViewer has not completed.");
    }
    _initializing = true;

    _viewer =
        await ThermionFlutterPlatform.instance.createViewer(options: options);

    _viewer!.onDispose(() async {
      _viewer = null;
    });
    _initializing = false;
    return _viewer!;
  }

}

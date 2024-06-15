
// import 'package:polyvox_engine/app/app.dart';
// import 'package:polyvox_engine/app/states/states.dart';
// import 'package:polyvox_engine/services/asr_service.dart';
// import 'package:polyvox_web/error_handler.dart';
// import 'package:polyvox_web/services/web_asr_service.dart';
// import 'package:polyvox_web/services/web_asset_repository.dart';
// import 'package:polyvox_web/services/web_audio_service.dart';
// import 'package:polyvox_web/services/web_auth_service.dart';
// import 'package:polyvox_web/services/web_data_provider.dart';
// import 'package:polyvox_web/services/web_purchase_service.dart';
// import 'package:polyvox_web/services/web_scoring_service.dart';
// import 'package:polyvox_web/web_canvas.dart';
import 'package:thermion_dart/thermion_dart/abstract_filament_viewer.dart';
import 'package:thermion_dart/thermion_dart/compatibility/web/compatibility.dart';
import 'package:thermion_dart/thermion_dart/filament_viewer_impl.dart';
import 'package:thermion_dart/thermion_dart/compatibility/web/interop/thermion_dart_js_export_type.dart';
import 'package:thermion_dart/thermion_dart/compatibility/web/interop/thermion_dart_js_extension_type.dart';
import 'package:web/web.dart';

void main(List<String> arguments) async {
  var viewer = await WebViewer.initialize();

  ThermionDartJSExportViewer.initializeBindings(viewer);

  print("Set wrapper, running!");

  while (true) {
    await Future.delayed(Duration(milliseconds: 16));
  }
  print("Finisehd!");
}

class WebViewer {
  static Future<AbstractFilamentViewer> initialize() async {
    var fc = FooChar();
    final canvas = document.getElementById("canvas") as HTMLCanvasElement;
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    var resourceLoader = thermion_dart_web_get_resource_loader_wrapper();

    var viewer = FilamentViewer(resourceLoader: resourceLoader);

    await viewer.initialized;
    var width = window.innerWidth;
    var height = window.innerHeight;
    await viewer.createSwapChain(width.toDouble(), height.toDouble());
    await viewer.updateViewportAndCameraProjection(
        width.toDouble(), height.toDouble());
    return viewer;
  }
}

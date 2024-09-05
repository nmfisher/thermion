import 'package:thermion_flutter_platform_interface/thermion_flutter_platform_interface.dart';

class ThermionFlutterWebOptions extends ThermionFlutterOptions {
  bool createCanvas;
  bool importCanvasAsWidget;
 
  ThermionFlutterWebOptions({this.importCanvasAsWidget = false, this.createCanvas = true, String? uberarchivePath}) : super(uberarchivePath:uberarchivePath);
}

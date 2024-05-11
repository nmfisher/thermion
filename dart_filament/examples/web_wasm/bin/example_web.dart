import 'package:dart_filament/dart_filament/compatibility/compatibility.dart';
import 'package:dart_filament/dart_filament/filament_viewer_impl.dart';

void main(List<String> arguments) async {
  var fc = FooChar();
  print("Started!");

  var resourceLoader = flutter_filament_web_get_resource_loader_wrapper();
  print("Got resource loader!");

  var viewer = FilamentViewer(resourceLoader: resourceLoader);
    print("created viewer!");

  await viewer.initialized;

  while (true) {
    await Future.delayed(Duration(milliseconds: 16));
  }
  print("Finisehd!");
}

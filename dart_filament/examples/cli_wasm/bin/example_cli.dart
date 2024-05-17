import 'package:dart_filament/dart_filament/compatibility/compatibility.dart';
import 'package:dart_filament/dart_filament.dart';

void main(List<String> args) async {
  print("MAIN");

  // final resourceLoader = calloc<Char>(1);

  // var loadToOut = NativeCallable<
  //     Void Function(Pointer<Char>,
  //         Pointer<ResourceBuffer>)>.listener(DartResourceLoader.loadResource);
  // print("LOADED");
  // resourceLoader.ref.loadToOut = loadToOut.nativeFunction;
  // var freeResource = NativeCallable<Void Function(ResourceBuffer)>.listener(
  //     DartResourceLoader.freeResource);
  // resourceLoader.ref.freeResource = freeResource.nativeFunction;
  final resourceLoader = flutter_filament_web_get_resource_loader_wrapper();
  var viewer = FilamentViewer(resourceLoader: resourceLoader.cast<Void>());
  print("Created viewer, waiting for initialization");
  viewer.initialized.then((_) async {
    print("Initialied");
    var entity = await viewer.loadGlb(
        "/Users/nickfisher/Documents/polyvox/apps/packages/flutter_filament/flutter_filament_federated/flutter_filament/example/assets/shapes/shapes.glb");
    print("Loaded glb");
    var entities = await viewer.getChildEntities(entity, true);
    print("Entities : $entities");
    for (final childEntity in entities) {
      var entityName = await viewer.getNameForEntity(childEntity);
      print("entityName : $entityName");
      var morphTargetNames =
          await viewer.getMorphTargetNames(entity, entityName!);
      print("morph targets : $morphTargetNames");
    }
  });

  while (true) {
    await Future.delayed(Duration(seconds: 1));
  }
}

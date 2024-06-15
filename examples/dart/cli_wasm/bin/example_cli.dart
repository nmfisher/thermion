import 'package:thermion_dart/thermion_dart/compatibility/compatibility.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'package:animation_tools_dart/animation_tools_dart.dart';

void main(List<String> args) async {
  final resourceLoader = thermion_dart_web_get_resource_loader_wrapper();
  var viewer = FilamentViewer(resourceLoader: resourceLoader.cast<Void>());
  viewer.initialized.then((_) async {
    var entity = await viewer.loadGlb(
        "/Users/nickfisher/Documents/polyvox/apps/packages/thermion_flutter/thermion_flutter_federated/thermion_flutter/example/assets/shapes/shapes.glb");
    var entities = await viewer.getChildEntities(entity, true);
    for (final childEntity in entities) {
      final childName = await viewer.getNameForEntity(childEntity);
      var morphTargetNames =
          await viewer.getMorphTargetNames(entity, childEntity!);
      if (morphTargetNames.isNotEmpty) {
        await viewer.setMorphTargetWeights(
            childEntity, List<double>.filled(morphTargetNames.length, 1.0));
      }
      var animationData = MorphAnimationData(
          List.generate(
              10, (_) => List<double>.filled(morphTargetNames.length, 1.0)),
          morphTargetNames);

      await viewer.setMorphAnimationData(entity, animationData,
          targetMeshNames: [childName!]);
    }
  });

  while (true) {
    await Future.delayed(Duration(seconds: 1));
  }
}

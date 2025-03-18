import 'package:thermion_dart/src/viewer/src/thermion_viewer_base.dart';

abstract class Scene {
  Future add(covariant ThermionAsset asset);
  Future remove(covariant ThermionAsset asset);
}

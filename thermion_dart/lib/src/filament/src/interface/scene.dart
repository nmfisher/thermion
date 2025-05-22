import 'package:thermion_dart/thermion_dart.dart';

abstract class Scene {
  Future add(covariant ThermionAsset asset);
  Future addEntity(ThermionEntity entity);
  Future remove(covariant ThermionAsset asset);
}

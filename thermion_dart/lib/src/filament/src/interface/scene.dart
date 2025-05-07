import 'package:thermion_dart/thermion_dart.dart';

abstract class Scene {
  Future add(covariant ThermionAsset asset);
  Future remove(covariant ThermionAsset asset);
}

import '../../../viewer.dart';

class ThermionWasmMaterialInstance extends MaterialInstance {
  final int pointer;

  ThermionWasmMaterialInstance(this.pointer);
  @override
  Future setDepthCullingEnabled(bool enabled) {
    // TODO: implement setDepthCullingEnabled
    throw UnimplementedError();
  }

  @override
  Future setDepthWriteEnabled(bool enabled) {
    // TODO: implement setDepthWriteEnabled
    throw UnimplementedError();
  }
}

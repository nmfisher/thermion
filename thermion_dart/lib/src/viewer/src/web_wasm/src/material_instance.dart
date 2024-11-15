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
  
  @override
  Future setParameterFloat2(String name, double x, double y) {
    // TODO: implement setParameterFloat2
    throw UnimplementedError();
  }
  
  @override
  Future setParameterFloat(String name, double x) {
    // TODO: implement setParameterFloat
    throw UnimplementedError();
  }
  
  @override
  Future setDepthFunc(SampleCompareFunction depthFunc) {
    // TODO: implement setDepthFunc
    throw UnimplementedError();
  }
  
  @override
  Future setParameterFloat4(String name, double x, double y, double z, double w) {
    // TODO: implement setParameterFloat4
    throw UnimplementedError();
  }
  
  @override
  Future setParameterInt(String name, int value) {
    // TODO: implement setParameterInt
    throw UnimplementedError();
  }
}

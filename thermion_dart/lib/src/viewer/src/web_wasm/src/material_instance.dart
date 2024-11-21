import '../../../viewer.dart';

class ThermionWasmMaterialInstance extends MaterialInstance {
  final int pointer;

  ThermionWasmMaterialInstance(this.pointer);
  
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
  Future setDepthFunc(SamplerCompareFunction depthFunc) {
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
  
  @override
  Future setDepthCullingEnabled(enabled) {
    // TODO: implement setDepthCullingEnabled
    throw UnimplementedError();
  }
  
  @override
  Future setDepthWriteEnabled(enabled) {
    // TODO: implement setDepthWriteEnabled
    throw UnimplementedError();
  }
  
  @override
  Future setStencilCompareFunction(SamplerCompareFunction func, [StencilFace face = StencilFace.FRONT_AND_BACK]) {
    // TODO: implement setStencilCompareFunction
    throw UnimplementedError();
  }
  
  @override
  Future setStencilOpDepthFail(StencilOperation op, [StencilFace face = StencilFace.FRONT_AND_BACK]) {
    // TODO: implement setStencilOpDepthFail
    throw UnimplementedError();
  }
  
  @override
  Future setStencilOpDepthStencilPass(StencilOperation op, [StencilFace face = StencilFace.FRONT_AND_BACK]) {
    // TODO: implement setStencilOpDepthStencilPass
    throw UnimplementedError();
  }
  
  @override
  Future setStencilOpStencilFail(StencilOperation op, [StencilFace face = StencilFace.FRONT_AND_BACK]) {
    // TODO: implement setStencilOpStencilFail
    throw UnimplementedError();
  }
  
  @override
  Future setStencilReferenceValue(int value, [StencilFace face = StencilFace.FRONT_AND_BACK]) {
    // TODO: implement setStencilReferenceValue
    throw UnimplementedError();
  }
  
  @override
  Future<bool> isStencilWriteEnabled() {
    // TODO: implement isStencilWriteEnabled
    throw UnimplementedError();
  }
  
  @override
  Future setCullingMode(CullingMode cullingMode) {
    // TODO: implement setCullingMode
    throw UnimplementedError();
  }
  
  @override
  Future setStencilWriteEnabled(bool enabled) {
    // TODO: implement setStencilWriteEnabled
    throw UnimplementedError();
  }
}

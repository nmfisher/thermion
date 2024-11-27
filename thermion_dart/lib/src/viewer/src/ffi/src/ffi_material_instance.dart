import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:thermion_dart/src/viewer/src/ffi/src/thermion_dart.g.dart';
import 'package:thermion_dart/thermion_dart.dart';

class ThermionFFIMaterialInstance extends MaterialInstance {
  final Pointer<TMaterialInstance> pointer;
  final Pointer<TSceneManager> sceneManager;

  ThermionFFIMaterialInstance(this.pointer, this.sceneManager) {
    if (pointer == nullptr) {
      throw Exception("MaterialInstance not found");
    }
  }

  @override
  Future setDepthCullingEnabled(bool enabled) async {
    MaterialInstance_setDepthCulling(this.pointer, enabled);
  }

  @override
  Future setDepthWriteEnabled(bool enabled) async {
    MaterialInstance_setDepthWrite(this.pointer, enabled);
  }

  @override
  Future setParameterFloat4(
      String name, double x, double y, double z, double w) async {
    MaterialInstance_setParameterFloat4(
        pointer, name.toNativeUtf8().cast<Char>(), x, y, z, w);
  }

  @override
  Future setParameterFloat2(String name, double x, double y) async {
    MaterialInstance_setParameterFloat2(
        pointer, name.toNativeUtf8().cast<Char>(), x, y);
  }

  @override
  Future setParameterFloat(String name, double value) async {
    MaterialInstance_setParameterFloat(
        pointer, name.toNativeUtf8().cast<Char>(), value);
  }

  @override
  Future setParameterInt(String name, int value) async {
    MaterialInstance_setParameterInt(
        pointer, name.toNativeUtf8().cast<Char>(), value);
  }

  @override
  Future setDepthFunc(SamplerCompareFunction depthFunc) async {
    MaterialInstance_setDepthFunc(
        pointer, TSamplerCompareFunc.values[depthFunc.index]);
  }

  @override
  Future setStencilCompareFunction(SamplerCompareFunction func,
      [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    MaterialInstance_setStencilCompareFunction(
        pointer,
        TSamplerCompareFunc.values[func.index],
        TStencilFace.values[face.index]);
  }

  @override
  Future setStencilOpDepthFail(StencilOperation op,
      [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    MaterialInstance_setStencilOpDepthFail(pointer,
        TStencilOperation.values[op.index], TStencilFace.values[face.index]);
  }

  @override
  Future setStencilOpDepthStencilPass(StencilOperation op,
      [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    MaterialInstance_setStencilOpDepthStencilPass(pointer,
        TStencilOperation.values[op.index], TStencilFace.values[face.index]);
  }

  @override
  Future setStencilOpStencilFail(StencilOperation op,
      [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    MaterialInstance_setStencilOpStencilFail(pointer,
        TStencilOperation.values[op.index], TStencilFace.values[face.index]);
  }

  @override
  Future setStencilReferenceValue(int value,
      [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    MaterialInstance_setStencilReferenceValue(
        pointer, value, TStencilFace.values[face.index]);
  }

  @override
  Future setStencilWriteEnabled(bool enabled) async {
    MaterialInstance_setStencilWrite(pointer, enabled);
  }

  @override
  Future setCullingMode(CullingMode cullingMode) async {
    MaterialInstance_setCullingMode(
        pointer, TCullingMode.values[cullingMode.index]);
  }

  @override
  Future<bool> isStencilWriteEnabled() async {
    return MaterialInstance_isStencilWriteEnabled(pointer);
  }

  @override
  Future setStencilReadMask(int mask) async {
    MaterialInstance_setStencilReadMask(pointer, mask);
  }

  @override
  Future setStencilWriteMask(int mask) async {
    MaterialInstance_setStencilWriteMask(pointer, mask);
  }

  Future dispose() async {
    SceneManager_destroyMaterialInstance(sceneManager, pointer);
  }
}

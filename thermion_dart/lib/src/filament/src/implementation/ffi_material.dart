import 'dart:async';
import 'package:thermion_dart/src/filament/src/implementation/ffi_filament_app.dart';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/thermion_dart.dart';

class FFIMaterial extends Material {
  final FFIFilamentApp app;
  final Pointer<TMaterial> pointer;

  FFIMaterial(this.pointer, this.app);

  @override
  Future<MaterialInstance> createInstance() async {
    var ptr = await withPointerCallback<TMaterialInstance>((cb) {
      Material_createInstanceRenderThread(pointer, cb);
    });
    return FFIMaterialInstance(ptr, this.app);
  }

  Future destroy() async {
    await withVoidCallback((requestId, cb) {
      Engine_destroyMaterialRenderThread(app.engine, pointer, requestId, cb);
    });
  }

  @override
  Future<bool> hasParameter(String propertyName) async {
    return Material_hasParameter(
        pointer, propertyName.toNativeUtf8().cast<Char>());
  }
}

class FFIMaterialInstance extends MaterialInstance<Pointer<TMaterialInstance>> {
  final Pointer<TMaterialInstance> pointer;
  final FFIFilamentApp app;

  FFIMaterialInstance(this.pointer, this.app) {
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
  Future setParameterFloat(String name, double value) async {
    MaterialInstance_setParameterFloat(
        pointer, name.toNativeUtf8().cast<Char>(), value);
  }

  @override
  Future setParameterFloat2(String name, double x, double y) async {
    MaterialInstance_setParameterFloat2(
        pointer, name.toNativeUtf8().cast<Char>(), x, y);
  }

  @override
  Future setParameterFloat3(String name, double x, double y, double z) async {
    MaterialInstance_setParameterFloat3(
        pointer, name.toNativeUtf8().cast<Char>(), x, y, z);
  }

  @override
  Future setParameterFloat3Array(String name, List<Vector3> array) async {
    late Pointer stackPtr;
    if (FILAMENT_WASM) {
      //stackPtr = stackSave();
    }
    final ptr = name.toNativeUtf8().cast<Char>();
    final data = Float64List(array.length * 3);
    int i = 0;
    for (final item in array) {
      data[i] = item.x;
      data[i + 1] = item.y;
      data[i + 2] = item.z;
      i += 3;
    }
    MaterialInstance_setParameterFloat3Array(
        pointer, ptr, data.address, array.length * 3);

    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
      data.free();
    }
  }

  @override
  Future setParameterFloat4(
      String name, double x, double y, double z, double w) async {
    MaterialInstance_setParameterFloat4(
        pointer, name.toNativeUtf8().cast<Char>(), x, y, z, w);
  }

  @override
  Future setParameterInt(String name, int value) async {
    MaterialInstance_setParameterInt(
        pointer, name.toNativeUtf8().cast<Char>(), value);
  }

  @override
  Future setDepthFunc(SamplerCompareFunction depthFunc) async {
    MaterialInstance_setDepthFunc(pointer, depthFunc.index);
  }

  @override
  Future setStencilCompareFunction(SamplerCompareFunction func,
      [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    MaterialInstance_setStencilCompareFunction(
        pointer, func.index, face.toFFI());
  }

  @override
  Future setStencilOpDepthFail(StencilOperation op,
      [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    MaterialInstance_setStencilOpDepthFail(pointer, op.index, face.toFFI());
  }

  @override
  Future setStencilOpDepthStencilPass(StencilOperation op,
      [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    MaterialInstance_setStencilOpDepthStencilPass(
        pointer, op.index, face.toFFI());
  }

  @override
  Future setStencilOpStencilFail(StencilOperation op,
      [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    MaterialInstance_setStencilOpStencilFail(pointer, op.index, face.toFFI());
  }

  @override
  Future setStencilReferenceValue(int value,
      [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    MaterialInstance_setStencilReferenceValue(pointer, value, face.toFFI());
  }

  @override
  Future setStencilWriteEnabled(bool enabled) async {
    MaterialInstance_setStencilWrite(pointer, enabled);
  }

  @override
  Future setCullingMode(CullingMode cullingMode) async {
    MaterialInstance_setCullingMode(pointer, cullingMode.index);
    ;
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

  Future destroy() async {
    await withVoidCallback((requestId, cb) {
      Engine_destroyMaterialInstanceRenderThread(
          app.engine, this.pointer, requestId, cb);
    });
  }

  @override
  Future setTransparencyMode(TransparencyMode mode) async {
    MaterialInstance_setTransparencyMode(pointer, mode.index);
  }

  @override
  Future setParameterTexture(String name, covariant FFITexture texture,
      covariant FFITextureSampler sampler) async {
    MaterialInstance_setParameterTexture(pointer,
        name.toNativeUtf8().cast<Char>(), texture.pointer, sampler.pointer);
  }

  @override
  Future setParameterBool(String name, bool value) async {
    MaterialInstance_setParameterBool(
        pointer, name.toNativeUtf8().cast<Char>(), value);
  }

  @override
  Future setParameterMat4(String name, Matrix4 matrix) async {
    MaterialInstance_setParameterMat4(
        pointer, name.toNativeUtf8().cast<Char>(), matrix.storage.address);
  }

  @override
  T getNativeHandle<T>() {
    return pointer as T;
  }
}

extension TStencilFaceExt on StencilFace {
  int toFFI() {
    return switch (this) {
      StencilFace.FRONT => TStencilFace.STENCIL_FACE_FRONT,
      StencilFace.BACK => TStencilFace.STENCIL_FACE_BACK,
      StencilFace.FRONT_AND_BACK => TStencilFace.STENCIL_FACE_FRONT_AND_BACK
    };
  }
}

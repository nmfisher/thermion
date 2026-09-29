import 'dart:async';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/thermion_dart.dart';

/// Allocates [name] as a native UTF-8 string for the duration of one
/// synchronous native call, then releases it (free on native, stackRestore on
/// wasm, where toNativeUtf8 is a stack allocation). [body] must be synchronous
/// and must not retain the pointer.
R _withParameterName<R>(String name, R Function(Pointer<Char> ptr) body) {
  late Pointer stackPtr;
  if (FILAMENT_WASM) {
    stackPtr = stackSave();
  }
  final ptr = name.toNativeUtf8().cast<Char>();
  try {
    return body(ptr);
  } finally {
    if (FILAMENT_WASM) {
      stackRestore(stackPtr);
    } else {
      free(ptr);
    }
  }
}

class FFIMaterial extends Material<Pointer<TMaterial>> {
  final Pointer<TMaterial> pointer;

  final FilamentApp _app;

  FFIMaterial(this.pointer, this._app);

  @override
  Future<MaterialInstance> createInstance() async {
    var ptr = await withPointerCallback<TMaterialInstance>((cb) {
      Material_createInstanceRenderThread(pointer, cb);
    });
    return FFIMaterialInstance(ptr, _app);
  }

  Future destroy() async {
    await withVoidCallback((requestId, cb) {
      Engine_destroyMaterialRenderThread(_app.engine, pointer, requestId, cb);
    });
  }

  @override
  Future<bool> hasParameter(String propertyName) async {
    return _withParameterName(propertyName, (ptr) => Material_hasParameter(pointer, ptr));
  }

  @override
  Future<BlendingMode> getBlendingMode() async {
    return BlendingMode.values[Material_getBlendingMode(pointer)];
  }

  @override
  Pointer<TMaterial> getNativeHandle() {
    return pointer;
  }
}

class FFIMaterialInstance extends MaterialInstance<Pointer<TMaterialInstance>> {
  final Pointer<TMaterialInstance> pointer;

  final FilamentApp _app;

  FFIMaterialInstance(this.pointer, this._app) {
    if (pointer == nullptr) {
      throw Exception("MaterialInstance not found");
    }
  }

  Future setDoubleSided(bool doubleSided) async {
    MaterialInstance_setDoubleSided(this.pointer, doubleSided);
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
    _withParameterName(name, (ptr) => MaterialInstance_setParameterFloat(pointer, ptr, value));
  }

  @override
  Future setParameterFloat2(String name, double x, double y) async {
    _withParameterName(name, (ptr) => MaterialInstance_setParameterFloat2(pointer, ptr, x, y));
  }

  @override
  Future setParameterFloat3(String name, double x, double y, double z) async {
    _withParameterName(name, (ptr) => MaterialInstance_setParameterFloat3(pointer, ptr, x, y, z));
  }

  @override
  Future setParameterFloat3Array(String name, List<Vector3> array) async {
    final data = Float64List(array.length * 3);
    int i = 0;
    for (final item in array) {
      data[i] = item.x;
      data[i + 1] = item.y;
      data[i + 2] = item.z;
      i += 3;
    }
    _withParameterName(
      name,
      (ptr) => MaterialInstance_setParameterFloat3Array(pointer, ptr, data.address, array.length * 3),
    );

    if (FILAMENT_WASM) {
      data.free();
    }
  }

  @override
  Future setParameterFloat4(String name, double x, double y, double z, double w) async {
    _withParameterName(name, (ptr) => MaterialInstance_setParameterFloat4(pointer, ptr, x, y, z, w));
  }

  @override
  Future setParameterInt(String name, int value) async {
    _withParameterName(name, (ptr) => MaterialInstance_setParameterInt(pointer, ptr, value));
  }

  @override
  Future setDepthFunc(SamplerCompareFunction depthFunc) async {
    MaterialInstance_setDepthFunc(pointer, depthFunc.index);
  }

  @override
  Future setStencilCompareFunction(SamplerCompareFunction func, [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    MaterialInstance_setStencilCompareFunction(pointer, func.index, face.toFFI());
  }

  @override
  Future setStencilOpDepthFail(StencilOperation op, [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    MaterialInstance_setStencilOpDepthFail(pointer, op.index, face.toFFI());
  }

  @override
  Future setStencilOpDepthStencilPass(StencilOperation op, [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    MaterialInstance_setStencilOpDepthStencilPass(pointer, op.index, face.toFFI());
  }

  @override
  Future setStencilOpStencilFail(StencilOperation op, [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    MaterialInstance_setStencilOpStencilFail(pointer, op.index, face.toFFI());
  }

  @override
  Future setStencilReferenceValue(int value, [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
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
      Engine_destroyMaterialInstanceRenderThread(_app.engine, this.pointer, requestId, cb);
    });
  }

  @override
  Future setTransparencyMode(TransparencyMode mode) async {
    MaterialInstance_setTransparencyMode(pointer, mode.index);
  }

  @override
  Future<TransparencyMode> getTransparencyMode() async {
    return TransparencyMode.values[MaterialInstance_getTransparencyMode(pointer)];
  }

  @override
  Future setParameterTexture(String name, covariant FFITexture texture, covariant FFITextureSampler sampler) async {
    _withParameterName(
      name,
      (ptr) => MaterialInstance_setParameterTexture(pointer, ptr, texture.pointer, sampler.pointer),
    );
  }

  @override
  Future setParameterBool(String name, bool value) async {
    _withParameterName(name, (ptr) => MaterialInstance_setParameterBool(pointer, ptr, value));
  }

  @override
  Future setParameterMat3(String name, Matrix3 matrix) async {
    _withParameterName(name, (ptr) => MaterialInstance_setParameterMat3(pointer, ptr, matrix.storage.address));

    if (FILAMENT_WASM) {
      matrix.storage.free();
    }
  }

  @override
  Future setParameterMat4(String name, Matrix4 matrix) async {
    _withParameterName(name, (ptr) => MaterialInstance_setParameterMat4(pointer, ptr, matrix.storage.address));
  }

  @override
  Pointer<TMaterialInstance> getNativeHandle() {
    return pointer;
  }
}

extension TStencilFaceExt on StencilFace {
  int toFFI() {
    return switch (this) {
      StencilFace.FRONT => TStencilFace.STENCIL_FACE_FRONT,
      StencilFace.BACK => TStencilFace.STENCIL_FACE_BACK,
      StencilFace.FRONT_AND_BACK => TStencilFace.STENCIL_FACE_FRONT_AND_BACK,
    };
  }
}

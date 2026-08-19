import 'dart:async';
import 'package:thermion_dart/src/filament/src/implementation/ffi_texture.dart';
import 'package:thermion_dart/thermion_dart.dart';
import 'ffi_filament_app.dart';
import 'material_shadow_state.dart';

class FFIMaterial extends Material<Pointer<TMaterial>> {
  final Pointer<TMaterial> pointer;

  final FilamentApp _app;

  ///
  /// Every instance created from this material via [createInstance].
  ///
  /// Instances cannot be re-parented to another material in Filament, so
  /// hot-reloading a material means creating replacement instances. This list
  /// lets the app find (and retire) the instances of a material being swapped
  /// out, including ones not currently attached to any renderable.
  ///
  final List<FFIMaterialInstance> createdInstances = [];

  FFIMaterial(this.pointer, this._app);

  @override
  Future<MaterialInstance> createInstance() async {
    var ptr = await withPointerCallback<TMaterialInstance>((cb) {
      Material_createInstanceRenderThread(pointer, cb);
    });
    final instance = FFIMaterialInstance(ptr, _app);
    // Register with the app so later lookups of this native instance return
    // this wrapper (and keep its shadow recording). The registry is FFI-app
    // internal state, not part of the FilamentApp interface.
    (_app as FFIFilamentApp).adoptMaterialInstance(instance);
    createdInstances.add(instance);
    return instance;
  }

  Future destroy() async {
    await withVoidCallback((requestId, cb) {
      Engine_destroyMaterialRenderThread(_app.engine, pointer, requestId, cb);
    });
  }

  @override
  Future<bool> hasParameter(String propertyName) async {
    return Material_hasParameter(pointer, propertyName.toNativeUtf8().cast<Char>());
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

  ///
  /// Shadow copy of every parameter/raster-state mutation applied through
  /// this wrapper. Filament instances are write-only, so this recording is
  /// the only way to carry state across to a replacement instance when a
  /// material is hot-reloaded. See [MaterialInstanceShadowState].
  ///
  final MaterialInstanceShadowState shadow = MaterialInstanceShadowState();

  bool _destroyed = false;

  FFIMaterialInstance(this.pointer, this._app) {
    if (pointer == nullptr) {
      throw Exception("MaterialInstance not found");
    }
  }

  Future setDoubleSided(bool doubleSided) async {
    shadow.doubleSided = doubleSided;
    MaterialInstance_setDoubleSided(this.pointer, doubleSided);
  }

  @override
  Future setDepthCullingEnabled(bool enabled) async {
    shadow.depthCullingEnabled = enabled;
    MaterialInstance_setDepthCulling(this.pointer, enabled);
  }

  @override
  Future setDepthWriteEnabled(bool enabled) async {
    shadow.depthWriteEnabled = enabled;
    MaterialInstance_setDepthWrite(this.pointer, enabled);
  }

  @override
  Future setParameterFloat(String name, double value) async {
    shadow.parameters[name] = value;
    MaterialInstance_setParameterFloat(pointer, name.toNativeUtf8().cast<Char>(), value);
  }

  @override
  Future setParameterFloat2(String name, double x, double y) async {
    shadow.parameters[name] = [x, y];
    MaterialInstance_setParameterFloat2(pointer, name.toNativeUtf8().cast<Char>(), x, y);
  }

  @override
  Future setParameterFloat3(String name, double x, double y, double z) async {
    shadow.parameters[name] = [x, y, z];
    MaterialInstance_setParameterFloat3(pointer, name.toNativeUtf8().cast<Char>(), x, y, z);
  }

  @override
  Future setParameterFloat3Array(String name, List<Vector3> array) async {
    shadow.parameters[name] = List<Vector3>.of(array);
    final ptr = name.toNativeUtf8().cast<Char>();
    final data = Float64List(array.length * 3);
    int i = 0;
    for (final item in array) {
      data[i] = item.x;
      data[i + 1] = item.y;
      data[i + 2] = item.z;
      i += 3;
    }
    MaterialInstance_setParameterFloat3Array(pointer, ptr, data.address, array.length * 3);

    if (FILAMENT_WASM) {
      //stackRestore(stackPtr);
      data.free();
    }
  }

  @override
  Future setParameterFloat4(String name, double x, double y, double z, double w) async {
    shadow.parameters[name] = [x, y, z, w];
    MaterialInstance_setParameterFloat4(pointer, name.toNativeUtf8().cast<Char>(), x, y, z, w);
  }

  @override
  Future setParameterInt(String name, int value) async {
    shadow.parameters[name] = value;
    MaterialInstance_setParameterInt(pointer, name.toNativeUtf8().cast<Char>(), value);
  }

  @override
  Future setDepthFunc(SamplerCompareFunction depthFunc) async {
    shadow.depthFunc = depthFunc;
    MaterialInstance_setDepthFunc(pointer, depthFunc.index);
  }

  @override
  Future setStencilCompareFunction(SamplerCompareFunction func, [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    shadow.stencilCompareFunction[face] = func;
    MaterialInstance_setStencilCompareFunction(pointer, func.index, face.toFFI());
  }

  @override
  Future setStencilOpDepthFail(StencilOperation op, [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    shadow.stencilOpDepthFail[face] = op;
    MaterialInstance_setStencilOpDepthFail(pointer, op.index, face.toFFI());
  }

  @override
  Future setStencilOpDepthStencilPass(StencilOperation op, [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    shadow.stencilOpDepthStencilPass[face] = op;
    MaterialInstance_setStencilOpDepthStencilPass(pointer, op.index, face.toFFI());
  }

  @override
  Future setStencilOpStencilFail(StencilOperation op, [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    shadow.stencilOpStencilFail[face] = op;
    MaterialInstance_setStencilOpStencilFail(pointer, op.index, face.toFFI());
  }

  @override
  Future setStencilReferenceValue(int value, [StencilFace face = StencilFace.FRONT_AND_BACK]) async {
    shadow.stencilReferenceValue[face] = value;
    MaterialInstance_setStencilReferenceValue(pointer, value, face.toFFI());
  }

  @override
  Future setStencilWriteEnabled(bool enabled) async {
    shadow.stencilWriteEnabled = enabled;
    MaterialInstance_setStencilWrite(pointer, enabled);
  }

  @override
  Future setCullingMode(CullingMode cullingMode) async {
    shadow.cullingMode = cullingMode;
    MaterialInstance_setCullingMode(pointer, cullingMode.index);
    ;
  }

  @override
  Future<bool> isStencilWriteEnabled() async {
    return MaterialInstance_isStencilWriteEnabled(pointer);
  }

  @override
  Future setStencilReadMask(int mask) async {
    shadow.stencilReadMask = mask;
    MaterialInstance_setStencilReadMask(pointer, mask);
  }

  @override
  Future setStencilWriteMask(int mask) async {
    shadow.stencilWriteMask = mask;
    MaterialInstance_setStencilWriteMask(pointer, mask);
  }

  /// Destroys the native instance. Safe to call more than once; later calls
  /// are no-ops (Filament objects can be released as part of destroying a
  /// parent, and a repeated destroy would otherwise touch a freed pointer).
  Future destroy() async {
    if (_destroyed) {
      return;
    }
    _destroyed = true;
    await withVoidCallback((requestId, cb) {
      Engine_destroyMaterialInstanceRenderThread(_app.engine, this.pointer, requestId, cb);
    });
    (_app as FFIFilamentApp).forgetMaterialInstance(this);
  }

  @override
  Future setTransparencyMode(TransparencyMode mode) async {
    shadow.transparencyMode = mode;
    MaterialInstance_setTransparencyMode(pointer, mode.index);
  }

  @override
  Future<TransparencyMode> getTransparencyMode() async {
    return TransparencyMode.values[MaterialInstance_getTransparencyMode(pointer)];
  }

  @override
  Future setParameterTexture(String name, covariant FFITexture texture, covariant FFITextureSampler sampler) async {
    shadow.parameters[name] = MaterialInstanceTextureBinding(texture, sampler);
    MaterialInstance_setParameterTexture(pointer, name.toNativeUtf8().cast<Char>(), texture.pointer, sampler.pointer);
  }

  @override
  Future setParameterBool(String name, bool value) async {
    shadow.parameters[name] = value;
    MaterialInstance_setParameterBool(pointer, name.toNativeUtf8().cast<Char>(), value);
  }

  @override
  Future setParameterMat3(String name, Matrix3 matrix) async {
    shadow.parameters[name] = matrix.clone();
    MaterialInstance_setParameterMat3(pointer, name.toNativeUtf8().cast<Char>(), matrix.storage.address);

    if (FILAMENT_WASM) {
      matrix.storage.free();
    }
  }

  @override
  Future setParameterMat4(String name, Matrix4 matrix) async {
    shadow.parameters[name] = matrix.clone();
    MaterialInstance_setParameterMat4(pointer, name.toNativeUtf8().cast<Char>(), matrix.storage.address);
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

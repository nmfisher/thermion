import 'package:thermion_dart/thermion_dart.dart';

import 'ffi_material.dart';
import 'ffi_texture.dart';

/// A texture bound to a material parameter, plus the sampler it was bound
/// with. Kept as a record so [MaterialInstanceShadowState] can re-bind the
/// exact pair onto a replacement instance.
class MaterialInstanceTextureBinding {
  final FFITexture texture;
  final FFITextureSampler sampler;

  MaterialInstanceTextureBinding(this.texture, this.sampler);
}

/// Shadow copy of every mutation applied to a [MaterialInstance].
///
/// Filament's MaterialInstance API is write-only: parameter values and raster
/// state cannot be read back. So each Dart setter records the call here, and
/// [applyTo] replays the recording onto a fresh instance. This is what lets
/// reloadMaterialFromBytes rebuild instances that behave identically to the
/// ones they replace.
///
/// Only the *latest* value of each parameter is kept (a map, not a log); the
/// raster-state fields likewise hold the last value written. Setters that are
/// queries rather than mutations (isStencilWriteEnabled, getTransparencyMode)
/// are not recorded.
class MaterialInstanceShadowState {
  /// name -> value. Insertion-ordered so replay matches the order the
  /// application originally applied values in.
  ///
  /// Value types, matching the setter that produced them:
  ///  - double (float), List&lt;double&gt; of length 2/3/4 (float2/3/4)
  ///  - List&lt;Vector3&gt; (float3 array)
  ///  - int, bool
  ///  - Matrix3, Matrix4
  ///  - [MaterialInstanceTextureBinding]
  final Map<String, Object> parameters = {};

  bool? doubleSided;
  bool? depthCullingEnabled;
  bool? depthWriteEnabled;
  SamplerCompareFunction? depthFunc;
  bool? stencilWriteEnabled;
  int? stencilReadMask;
  int? stencilWriteMask;
  CullingMode? cullingMode;
  TransparencyMode? transparencyMode;

  /// Per-face stencil state. Keyed by face because the setters accept a face
  /// argument; FRONT_AND_BACK entries are recorded under their own key.
  final Map<StencilFace, SamplerCompareFunction> stencilCompareFunction = {};
  final Map<StencilFace, StencilOperation> stencilOpDepthFail = {};
  final Map<StencilFace, StencilOperation> stencilOpDepthStencilPass = {};
  final Map<StencilFace, StencilOperation> stencilOpStencilFail = {};
  final Map<StencilFace, int> stencilReferenceValue = {};

  /// Replays every recorded mutation onto [target], in the order recorded
  /// (parameters first, then raster state). Recording on [target] is a side
  /// effect of calling its setters, so the target ends up with its own copy of
  /// this state.
  Future<void> applyTo(covariant FFIMaterialInstance target) async {
    for (final entry in parameters.entries) {
      final value = entry.value;
      if (value is double) {
        await target.setParameterFloat(entry.key, value);
      } else if (value is List<double>) {
        switch (value.length) {
          case 2:
            await target.setParameterFloat2(entry.key, value[0], value[1]);
          case 3:
            await target.setParameterFloat3(entry.key, value[0], value[1], value[2]);
          case 4:
            await target.setParameterFloat4(entry.key, value[0], value[1], value[2], value[3]);
          default:
            throw StateError("Cannot replay float parameter ${entry.key} of ${value.length} components");
        }
      } else if (value is List<Vector3>) {
        await target.setParameterFloat3Array(entry.key, value);
      } else if (value is int) {
        await target.setParameterInt(entry.key, value);
      } else if (value is bool) {
        await target.setParameterBool(entry.key, value);
      } else if (value is Matrix3) {
        await target.setParameterMat3(entry.key, value);
      } else if (value is Matrix4) {
        await target.setParameterMat4(entry.key, value);
      } else if (value is MaterialInstanceTextureBinding) {
        await target.setParameterTexture(entry.key, value.texture, value.sampler);
      } else {
        throw StateError("Cannot replay parameter ${entry.key} of type ${value.runtimeType}");
      }
    }

    // Use ?. to skip state never set on the source instance.
    final doubleSided = this.doubleSided;
    if (doubleSided != null) {
      await target.setDoubleSided(doubleSided);
    }
    final depthCullingEnabled = this.depthCullingEnabled;
    if (depthCullingEnabled != null) {
      await target.setDepthCullingEnabled(depthCullingEnabled);
    }
    final depthWriteEnabled = this.depthWriteEnabled;
    if (depthWriteEnabled != null) {
      await target.setDepthWriteEnabled(depthWriteEnabled);
    }
    final depthFunc = this.depthFunc;
    if (depthFunc != null) {
      await target.setDepthFunc(depthFunc);
    }
    final stencilWriteEnabled = this.stencilWriteEnabled;
    if (stencilWriteEnabled != null) {
      await target.setStencilWriteEnabled(stencilWriteEnabled);
    }
    final stencilReadMask = this.stencilReadMask;
    if (stencilReadMask != null) {
      await target.setStencilReadMask(stencilReadMask);
    }
    final stencilWriteMask = this.stencilWriteMask;
    if (stencilWriteMask != null) {
      await target.setStencilWriteMask(stencilWriteMask);
    }
    final cullingMode = this.cullingMode;
    if (cullingMode != null) {
      await target.setCullingMode(cullingMode);
    }
    final transparencyMode = this.transparencyMode;
    if (transparencyMode != null) {
      await target.setTransparencyMode(transparencyMode);
    }
    for (final entry in stencilCompareFunction.entries) {
      await target.setStencilCompareFunction(entry.value, entry.key);
    }
    for (final entry in stencilOpDepthFail.entries) {
      await target.setStencilOpDepthFail(entry.value, entry.key);
    }
    for (final entry in stencilOpDepthStencilPass.entries) {
      await target.setStencilOpDepthStencilPass(entry.value, entry.key);
    }
    for (final entry in stencilOpStencilFail.entries) {
      await target.setStencilOpStencilFail(entry.value, entry.key);
    }
    for (final entry in stencilReferenceValue.entries) {
      await target.setStencilReferenceValue(entry.value, entry.key);
    }
  }

  /// Copies this state into a fresh [MaterialInstanceShadowState] without
  /// touching any instance. Used when a material is reloaded and the caller
  /// wants to keep a hand-made recording for the next reload.
  MaterialInstanceShadowState clone() {
    final copy = MaterialInstanceShadowState();
    copy.parameters.addAll(parameters);
    copy.doubleSided = doubleSided;
    copy.depthCullingEnabled = depthCullingEnabled;
    copy.depthWriteEnabled = depthWriteEnabled;
    copy.depthFunc = depthFunc;
    copy.stencilWriteEnabled = stencilWriteEnabled;
    copy.stencilReadMask = stencilReadMask;
    copy.stencilWriteMask = stencilWriteMask;
    copy.cullingMode = cullingMode;
    copy.transparencyMode = transparencyMode;
    copy.stencilCompareFunction.addAll(stencilCompareFunction);
    copy.stencilOpDepthFail.addAll(stencilOpDepthFail);
    copy.stencilOpDepthStencilPass.addAll(stencilOpDepthStencilPass);
    copy.stencilOpStencilFail.addAll(stencilOpStencilFail);
    copy.stencilReferenceValue.addAll(stencilReferenceValue);
    return copy;
  }
}

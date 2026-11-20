import '../../../bindings/src/thermion_dart_ffi.g.dart'
    if (dart.library.js_interop) '../../../bindings/src/thermion_dart_js_interop.g.dart'
    show TBuiltInMaterial;

/// Helper materials available through the build configuration.
enum BuiltInMaterial {
  image(TBuiltInMaterial.BUILT_IN_IMAGE, 'image'),
  grid(TBuiltInMaterial.BUILT_IN_GRID, 'grid'),
  gizmo(TBuiltInMaterial.BUILT_IN_GIZMO, 'gizmo'),
  translationAxis(TBuiltInMaterial.BUILT_IN_TRANSLATION_AXIS, 'translation_axis'),
  boneOverlay(TBuiltInMaterial.BUILT_IN_BONE_OVERLAY, 'bone_overlay'),
  silhouette(TBuiltInMaterial.BUILT_IN_SILHOUETTE, 'silhouette'),
  edgeOutline(TBuiltInMaterial.BUILT_IN_EDGE_OUTLINE, 'edge_outline'),
  wireframe(TBuiltInMaterial.BUILT_IN_WIREFRAME, 'wireframe'),
  normalColor(TBuiltInMaterial.BUILT_IN_NORMAL_COLOR, 'normal_color'),
  sharpEdge(TBuiltInMaterial.BUILT_IN_SHARP_EDGE, 'sharp_edge'),
  captureUv(TBuiltInMaterial.BUILT_IN_CAPTURE_UV, 'capture_uv'),
  linearDepth(TBuiltInMaterial.BUILT_IN_LINEAR_DEPTH, 'linear_depth'),
  unlitFixedSize(TBuiltInMaterial.BUILT_IN_UNLIT_FIXED_SIZE, 'unlit_fixed_size');

  const BuiltInMaterial(this.nativeId, this.key);

  /// Stable FFI value, independent of enum order.
  final int nativeId;

  /// Key under hooks.user_defines.thermion_dart.materials.
  final String key;

  /// Whether the build hook compiles this material from its packaged source.
  bool get compiledOnDemand => this == normalColor || this == sharpEdge;
}

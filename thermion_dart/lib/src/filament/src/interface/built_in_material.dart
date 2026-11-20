// Generated from materials/built_in_materials.json by make bindings.

/// Helper materials that can be embedded by the build.
enum BuiltInMaterial {
  image(1, 'image'),
  grid(2, 'grid'),
  gizmo(3, 'gizmo'),
  translationAxis(4, 'translation_axis'),
  boneOverlay(5, 'bone_overlay'),
  silhouette(6, 'silhouette'),
  edgeOutline(7, 'edge_outline'),
  wireframe(8, 'wireframe'),
  normalColor(9, 'normal_color'),
  sharpEdge(10, 'sharp_edge'),
  captureUv(11, 'capture_uv'),
  linearDepth(12, 'linear_depth'),
  unlitFixedSize(13, 'unlit_fixed_size');

  const BuiltInMaterial(this.nativeId, this.key);

  /// Stable FFI value, independent of enum order.
  final int nativeId;

  /// Key under hooks.user_defines.thermion_dart.materials.
  final String key;
}

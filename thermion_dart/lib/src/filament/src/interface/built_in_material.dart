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

  /// Visualizes world-space normals. Set the int `useAbsoluteValue` to 1 for
  /// absolute components, or adjust the float `opacity` (default 1).
  normalColor(TBuiltInMaterial.BUILT_IN_NORMAL_COLOR, 'normal_color'),

  /// Draws the triangle edges selected by the mask in `CUSTOM0.w`.
  /// Set `edgeColor` and `baseColor` as RGBA float4s and `edgeWidth` in pixels.
  sharpEdge(TBuiltInMaterial.BUILT_IN_SHARP_EDGE, 'sharp_edge'),
  captureUv(TBuiltInMaterial.BUILT_IN_CAPTURE_UV, 'capture_uv'),
  linearDepth(TBuiltInMaterial.BUILT_IN_LINEAR_DEPTH, 'linear_depth'),
  unlitFixedSize(TBuiltInMaterial.BUILT_IN_UNLIT_FIXED_SIZE, 'unlit_fixed_size'),

  /// Backs [FilamentApp.createUnlitMaterialInstance] in
  /// `features.gltf: false` builds. Not user-selectable through
  /// `materials.*`: the build hook compiles and links it automatically
  /// when glTF support is off (UNLIT_FALLBACK_ENABLED), and never in
  /// default builds. [FilamentApp.createBuiltInMaterial] rejects it with a
  /// [StateError] pointing at [FilamentApp.createUnlitMaterialInstance].
  unlitFallback(TBuiltInMaterial.BUILT_IN_UNLIT_FALLBACK, 'unlit_fallback');

  const BuiltInMaterial(this.nativeId, this.key);

  /// Stable FFI value, independent of enum order.
  final int nativeId;

  /// Key under hooks.user_defines.thermion_dart.materials.
  final String key;

  String get wasmSectionName => 'thermion.material.$key';

  /// Resgen symbol prefix used when compiling into native builds.
  ///
  /// `gizmo` uses `gizmo_material` to avoid a case-insensitive `.obj`
  /// collision with `scene/Gizmo.cpp` on Windows.
  String get resgenPrefix => this == gizmo ? 'gizmo_material' : key;
}

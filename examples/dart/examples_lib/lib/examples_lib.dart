/// Shared scene-setup functions for the Thermion Dart examples.
///
/// Each example contributes a top-level `setup<Name>` function with the
/// [ExampleSetup] signature. The function sets up a scene on a ready
/// [ThermionViewer] (camera, lights, geometry, materials) but performs NO
/// platform-specific work -- no `dart:io`, no `capture()`, no render loop. That
/// makes each setup reusable from both the headless CLI runner (which captures a
/// PNG) and the web gallery (which renders live to a canvas).
library;

export 'src/registry.dart';
export 'src/bone_animation.dart';
export 'src/camera_basics.dart';
export 'src/custom_geometry.dart';
export 'src/game_effects_shared.dart';
export 'src/game_effects_hit_flash.dart';
export 'src/game_effects_hologram.dart';
export 'src/game_effects_force_field.dart';
export 'src/game_effects_dissolve_burn.dart';
export 'src/game_effects_water.dart';
export 'src/game_effects_smoke.dart';
export 'src/gltf_animation.dart';
export 'src/gizmo_basics.dart';
export 'src/headless_capture.dart';
export 'src/highlight_effects.dart';
export 'src/input_handlers.dart';
export 'src/instancing.dart';
export 'src/lighting_setup.dart';
export 'src/load_gltf.dart';
export 'src/materials_pbr.dart';
export 'src/morph_targets.dart';
export 'src/picking.dart';
export 'src/post_processing.dart';
export 'src/render_targets.dart';
export 'src/shadows.dart';
export 'src/skybox_and_background.dart';
export 'src/texture_from_scratch.dart';
export 'src/transforms_and_hierarchy.dart';
export 'src/wireframe_and_flat_shading.dart';
export 'src/geometry_primitives.dart';

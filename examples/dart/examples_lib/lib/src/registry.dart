import 'package:thermion_dart/thermion_dart.dart';

import 'bone_animation.dart';
import 'camera_basics.dart';
import 'custom_geometry.dart';
import 'gizmo_basics.dart';
import 'headless_capture.dart';
import 'highlight_effects.dart';
import 'input_handlers.dart';
import 'instancing.dart';
import 'materials_and_lighting.dart';
import 'materials_pbr.dart';
import 'morph_targets.dart';
import 'picking.dart';
import 'post_processing.dart';
import 'render_targets.dart';
import 'scene_animation.dart';
import 'scene_basics.dart';
import 'scene_effects.dart';
import 'scene_geometry.dart';
import 'texture_from_scratch.dart';
import 'transforms_and_hierarchy.dart';
import 'wireframe_and_flat_shading.dart';
import 'geometry_primitives.dart';
import 'gltf_animation.dart';
import 'lighting_setup.dart';
import 'load_gltf.dart';
import 'load_via_assimp.dart';
import 'shadows.dart';
import 'skybox_and_background.dart';
import 'game_effects_hit_flash.dart';
import 'game_effects_hologram.dart';
import 'game_effects_force_field.dart';
import 'game_effects_dissolve_burn.dart';
import 'game_effects_water.dart';
import 'game_effects_smoke.dart';
import 'game_effects_fire.dart';
import 'game_effects_lava.dart';
import 'game_effects_shockwave.dart';
import 'game_effects_shore_waves.dart';
import 'game_effects_wetness.dart';
import 'game_effects_crystal_ice.dart';
import 'game_effects_snow_accumulation.dart';
import 'game_effects_damage_decals.dart';
import 'game_effects_portal_rift.dart';
import 'game_effects_electricity.dart';
import 'game_effects_invisibility_cloak.dart';
import 'game_effects_energy_weapon.dart';

/// A scene-setup function: configures a scene on a ready [ThermionViewer].
typedef ExampleSetup = Future<void> Function(
  ThermionViewer viewer, {
  required String assetsDir,
});

/// Maps an example name (used as the `?example=` query parameter on the web
/// gallery) to its setup function.
final Map<String, ExampleSetup> registry = {
  'bone_animation': setupBoneAnimation,
  'camera_basics': setupCameraBasics,
  'custom_geometry': setupCustomGeometry,
  'game_effects_hit_flash': setupHitFlash,
  'game_effects_hologram': setupHologram,
  'game_effects_force_field': setupForceField,
  'game_effects_dissolve_burn': setupDissolveBurn,
  'game_effects_water': setupWater,
  'game_effects_smoke': setupSmoke,
  'game_effects_fire': setupFire,
  'game_effects_lava': setupLava,
  'game_effects_shockwave': setupShockwave,
  'game_effects_shore_waves': setupShoreWaves,
  'game_effects_wetness': setupWetness,
  'game_effects_crystal_ice': setupCrystalIce,
  'game_effects_snow_accumulation': setupSnowAccumulation,
  'game_effects_damage_decals': setupDamageDecals,
  'game_effects_portal_rift': setupPortalRift,
  'game_effects_electricity': setupElectricity,
  'game_effects_invisibility_cloak': setupInvisibilityCloak,
  'game_effects_energy_weapon': setupEnergyWeapon,
  'geometry_primitives': setupGeometryPrimitives,
  'gizmo_basics': setupGizmoBasics,
  'gltf_animation': setupGltfAnimation,
  'headless_capture': setupHeadlessCapture,
  'highlight_effects': setupHighlightEffects,
  'input_handlers': setupInputHandlers,
  'instancing': setupInstancing,
  'lighting_setup': setupLightingSetup,
  'load_gltf': setupLoadGltf,
  'load_via_assimp': setupLoadViaAssimp,
  'materials_pbr': setupMaterialsPbr,
  'morph_targets': setupMorphTargets,
  'picking': setupPicking,
  'post_processing': setupPostProcessing,
  'render_targets': setupRenderTargets,
  'shadows': setupShadows,
  'skybox_and_background': setupSkyboxAndBackground,
  'texture_from_scratch': setupTextureFromScratch,
  'transforms_and_hierarchy': setupTransformsAndHierarchy,
  'wireframe_and_flat_shading': setupWireframeAndFlatShading,
};

/// Consolidated composite scenes used by the web gallery (one rich scene per
/// concept area). The original per-concept setups in [registry] stay available
/// for the headless CLI runner's PNG reference.
final Map<String, ExampleSetup> galleryScenes = {
  'basics': setupBasics,
  'geometry': setupGeometry,
  'materials_and_lighting': setupMaterialsAndLighting,
  'animation': setupAnimation,
  'effects': setupEffects,
};

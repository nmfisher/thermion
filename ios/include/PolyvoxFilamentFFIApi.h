#ifndef _POLYVOX_FILAMENT_FFI_API_H
#define _POLYVOX_FILAMENT_FFI_API_H

/// 
/// This header replicates most of the methods in PolyvoxFilamentApi.h, and is only intended to be used to generate client FFI bindings.
/// The intention is that calling one of these methods will call its respective method in PolyvoxFilamentApi.h, but wrapped in some kind of thread runner to ensure thread safety. 
/// 

#include "PolyvoxFilamentApi.h"

typedef int32_t EntityId;

FLUTTER_PLUGIN_EXPORT void* const create_filament_viewer_ffi(void* const context, void* const platform, const ResourceLoaderWrapper* const loader, void (*renderCallback)(void* const renderCallbackOwner), void* const renderCallbackOwner);
FLUTTER_PLUGIN_EXPORT void create_swap_chain_ffi(void* const viewer, void* const surface, uint32_t width, uint32_t height);
FLUTTER_PLUGIN_EXPORT void create_render_target_ffi(void* const viewer, uint32_t nativeTextureId, uint32_t width, uint32_t height);
FLUTTER_PLUGIN_EXPORT void destroy_filament_viewer_ffi(void* const viewer);
FLUTTER_PLUGIN_EXPORT void render_ffi(void* const viewer);
FLUTTER_PLUGIN_EXPORT void set_rendering_ffi(void* const viewer, bool rendering);
FLUTTER_PLUGIN_EXPORT void set_frame_interval_ffi(float frameInterval);
FLUTTER_PLUGIN_EXPORT void update_viewport_and_camera_projection_ffi(void* const viewer, const uint32_t width, const uint32_t height, const float scaleFactor);
FLUTTER_PLUGIN_EXPORT void set_background_color_ffi(void* const viewer, const float r, const float g, const float b, const float a);
FLUTTER_PLUGIN_EXPORT void clear_background_image_ffi(void* const viewer);
FLUTTER_PLUGIN_EXPORT void set_background_image_ffi(void* const viewer, const char *path, bool fillHeight);
FLUTTER_PLUGIN_EXPORT void set_background_image_position_ffi(void* const viewer, float x, float y, bool clamp);
FLUTTER_PLUGIN_EXPORT void set_tone_mapping_ffi(void* const viewer, int toneMapping);
FLUTTER_PLUGIN_EXPORT void set_bloom_ffi(void* const viewer, float strength);
FLUTTER_PLUGIN_EXPORT void load_skybox_ffi(void* const viewer, const char *skyboxPath);
FLUTTER_PLUGIN_EXPORT void load_ibl_ffi(void* const viewer, const char *iblPath, float intensity);
FLUTTER_PLUGIN_EXPORT void remove_skybox_ffi(void* const viewer);
FLUTTER_PLUGIN_EXPORT void remove_ibl_ffi(void* const viewer);
FLUTTER_PLUGIN_EXPORT EntityId add_light_ffi(void* const viewer, uint8_t type, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows);
FLUTTER_PLUGIN_EXPORT void remove_light_ffi(void* const viewer, EntityId entityId);
FLUTTER_PLUGIN_EXPORT void clear_lights_ffi(void* const viewer);
FLUTTER_PLUGIN_EXPORT EntityId load_glb_ffi(void* const assetManager, const char *assetPath, bool unlit);
FLUTTER_PLUGIN_EXPORT EntityId load_gltf_ffi(void* const assetManager, const char *assetPath, const char *relativePath);
FLUTTER_PLUGIN_EXPORT void remove_asset_ffi(void* const viewer, EntityId asset);
FLUTTER_PLUGIN_EXPORT void clear_assets_ffi(void* const viewer);
FLUTTER_PLUGIN_EXPORT bool set_camera_ffi(void* const viewer, EntityId asset, const char *nodeName);
FLUTTER_PLUGIN_EXPORT void apply_weights_ffi(
					     void* const assetManager,
					     EntityId asset, 
					     const char *const entityName, 
					     float *const weights, 
					     int count
					 );
FLUTTER_PLUGIN_EXPORT void set_morph_target_weights_ffi(
					     void* const assetManager,
					     EntityId asset,
					     const char *const entityName,
					     const float *const morphData,
					     int numWeights
					 );
FLUTTER_PLUGIN_EXPORT bool set_morph_animation_ffi(
					     void* const assetManager,
					     EntityId asset,
					     const char *const entityName,
					     const float *const morphData,
					     const int* const morphIndices,
					     int numMorphTargets,
					     int numFrames,
					     float frameLengthInMs);
FLUTTER_PLUGIN_EXPORT 
FLUTTER_PLUGIN_EXPORT void set_bone_animation_ffi(
					     void* const assetManager,
					     EntityId asset, 
					     const float* const frameData,
					     int numFrames, 
					     int numBones,
					     const char** const boneNames,
					     const char** const meshName,
					     int numMeshTargets,
                         float frameLengthInMs);
FLUTTER_PLUGIN_EXPORT void play_animation_ffi(void* const assetManager, EntityId asset, int index, bool loop, bool reverse, bool replaceActive, float crossfade);
FLUTTER_PLUGIN_EXPORT void set_animation_frame_ffi(void* const assetManager, EntityId asset, int animationIndex, int animationFrame);
FLUTTER_PLUGIN_EXPORT void stop_animation_ffi(void* const assetManager, EntityId asset, int index);
FLUTTER_PLUGIN_EXPORT int get_animation_count_ffi(void* const assetManager, EntityId asset);
FLUTTER_PLUGIN_EXPORT void get_animation_name_ffi(void* const assetManager, EntityId asset, char *const outPtr, int index);
FLUTTER_PLUGIN_EXPORT float get_animation_duration_ffi(void* const assetManager, EntityId asset, int index);
FLUTTER_PLUGIN_EXPORT void get_morph_target_name_ffi(void* const assetManager, EntityId asset, const char *meshName, char *const outPtr, int index);
FLUTTER_PLUGIN_EXPORT int get_morph_target_name_count_ffi(void* const assetManager, EntityId asset, const char *meshName);

FLUTTER_PLUGIN_EXPORT void ios_dummy_ffi();

#endif // _POLYVOX_FILAMENT_FFI_API_H

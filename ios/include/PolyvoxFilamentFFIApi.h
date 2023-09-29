#ifndef _POLYVOX_FILAMENT_FFI_API_H
#define _POLYVOX_FILAMENT_FFI_API_H

/// 
/// This header replicates most of the methods in PolyvoxFilamentApi.h, and is only intended to be used to generate client FFI bindings.
/// The intention is that calling one of these methods will call its respective method in PolyvoxFilamentApi.h, but wrapped in some kind of thread runner to ensure thread safety. 
/// 

#include "PolyvoxFilamentApi.h"

typedef int32_t EntityId;

void* const create_filament_viewer_ffi(void* const context, const ResourceLoaderWrapper* const loader, void (*renderCallback)(void* const renderCallbackOwner), void* const renderCallbackOwner);
void create_swap_chain_ffi(void* const viewer, void* const surface, uint32_t width, uint32_t height);
void create_render_target_ffi(void* const viewer, uint32_t nativeTextureId, uint32_t width, uint32_t height);
void destroy_filament_viewer_ffi(void* const viewer);
void render_ffi(void* const viewer);
void set_rendering_ffi(void* const viewer, bool rendering);
void set_frame_interval_ffi(float frameInterval);
void update_viewport_and_camera_projection_ffi(void* const viewer, const uint32_t width, const uint32_t height, const float scaleFactor);
void set_background_color_ffi(void* const viewer, const float r, const float g, const float b, const float a);
void clear_background_image_ffi(void* const viewer);
void set_background_image_ffi(void* const viewer, const char *path, bool fillHeight);
void set_background_image_position_ffi(void* const viewer, float x, float y, bool clamp);
void set_tone_mapping_ffi(void* const viewer, int toneMapping);
void set_bloom_ffi(void* const viewer, float strength);
void load_skybox_ffi(void* const viewer, const char *skyboxPath);
void load_ibl_ffi(void* const viewer, const char *iblPath, float intensity);
void remove_skybox_ffi(void* const viewer);
void remove_ibl_ffi(void* const viewer);
EntityId add_light_ffi(void* const viewer, uint8_t type, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows);
void remove_light_ffi(void* const viewer, EntityId entityId);
void clear_lights_ffi(void* const viewer);
EntityId load_glb_ffi(void* const assetManager, const char *assetPath, bool unlit);
EntityId load_gltf_ffi(void* const assetManager, const char *assetPath, const char *relativePath);
void remove_asset_ffi(void* const viewer, EntityId asset);
void clear_assets_ffi(void* const viewer);
bool set_camera_ffi(void* const viewer, EntityId asset, const char *nodeName);
void apply_weights_ffi(
    void* const assetManager,
    EntityId asset, 
    const char *const entityName, 
    float *const weights, 
    int count
);
void set_morph_target_weights_ffi(
    void* const assetManager,
    EntityId asset,
    const char *const entityName,
    const float *const morphData,
    int numWeights
);
bool set_morph_animation_ffi(
    void* const assetManager,
    EntityId asset,
    const char *const entityName,
    const float *const morphData,
    const int* const morphIndices,
    int numMorphTargets,
    int numFrames,
    float frameLengthInMs);

void set_bone_animation_ffi(
    void* const assetManager,
    EntityId asset, 
    const float* const frameData,
    int numFrames, 
    int numBones,
    const char** const boneNames,
    const char** const meshName,
    int numMeshTargets,
    float frameLengthInMs);

void play_animation_ffi(void* const assetManager, EntityId asset, int index, bool loop, bool reverse, bool replaceActive, float crossfade);
void set_animation_frame_ffi(void* const assetManager, EntityId asset, int animationIndex, int animationFrame);
void stop_animation_ffi(void* const assetManager, EntityId asset, int index);
int get_animation_count_ffi(void* const assetManager, EntityId asset);
void get_animation_name_ffi(void* const assetManager, EntityId asset, char *const outPtr, int index);
float get_animation_duration_ffi(void* const assetManager, EntityId asset, int index);
void get_morph_target_name_ffi(void* const assetManager, EntityId asset, const char *meshName, char *const outPtr, int index);
int get_morph_target_name_count_ffi(void* const assetManager, EntityId asset, const char *meshName);

void ios_dummy_ffi();

#endif // _POLYVOX_FILAMENT_FFI_API_H

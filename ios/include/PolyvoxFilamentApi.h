#ifndef _POLYVOX_FILAMENT_API_H
#define _POLYVOX_FILAMENT_API_H

#include "ResourceBuffer.hpp"

typedef int32_t EntityId;

const void* create_filament_viewer(const void* const context, const ResourceLoaderWrapper* const loader);
ResourceLoaderWrapper* make_resource_loader(LoadResourceFromOwner loadFn, FreeResourceFromOwner freeFn, void* owner);
void delete_filament_viewer(const void* const viewer);
void* get_asset_manager(const void* const viewer);
void create_render_target(const void* const viewer, uint32_t textureId, uint32_t width, uint32_t height);
void clear_background_image(const void* const viewer);
void set_background_image(const void* const viewer, const char *path, bool fillHeight);
void set_background_image_position(const void* const viewer, float x, float y, bool clamp);
void set_background_color(const void* const viewer, const float r, const float g, const float b, const float a);
void set_tone_mapping(const void* const viewer, int toneMapping);
void set_bloom(const void* const viewer, float strength);
void load_skybox(const void* const viewer, const char *skyboxPath);
void load_ibl(const void* const viewer, const char *iblPath, float intensity);
void remove_skybox(const void* const viewer);
void remove_ibl(const void* const viewer);
EntityId add_light(const void* const viewer, uint8_t type, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows);
void remove_light(const void* const viewer, EntityId entityId);
void clear_lights(const void* const viewer);
EntityId load_glb(void *assetManager, const char *assetPath, bool unlit);
EntityId load_gltf(void *assetManager, const char *assetPath, const char *relativePath);
bool set_camera(const void* const viewer, EntityId asset, const char *nodeName);
void render(const void* const viewer, uint64_t frameTimeInNanos);
void create_swap_chain(const void* const viewer, const void* const window, uint32_t width, uint32_t height);
void destroy_swap_chain(const void* const viewer);
void set_frame_interval(const void* const viewer, float interval);
void update_viewport_and_camera_projection(const void* const viewer, uint32_t width, uint32_t height, float scaleFactor);
void scroll_begin(const void* const viewer);
void scroll_update(const void* const viewer, float x, float y, float z);
void scroll_end(const void* const viewer);
void grab_begin(const void* const viewer, float x, float y, bool pan);
void grab_update(const void* const viewer, float x, float y);
void grab_end(const void* const viewer);
void apply_weights(
    void* assetManager,
    EntityId asset, 
    const char *const entityName, 
    float *const weights, 
    int count
);
void set_morph_target_weights(
    void* assetManager,
    EntityId asset,
    const char *const entityName,
    const float *const morphData,
    int numWeights
);
bool set_morph_animation(
    void* assetManager,
    EntityId asset,
    const char *const entityName,
    const float *const morphData,
    const int* const morphIndices,
    int numMorphTargets,
    int numFrames,
    float frameLengthInMs);

void set_bone_animation(
    void* assetManager,
    EntityId asset, 
    const float* const frameData,
    int numFrames, 
    int numBones,
    const char** const boneNames,
    const char** const meshName,
    int numMeshTargets,
    float frameLengthInMs);

void play_animation(void* assetManager, EntityId asset, int index, bool loop, bool reverse, bool replaceActive, float crossfade);
void set_animation_frame(void* assetManager, EntityId asset, int animationIndex, int animationFrame);
void stop_animation(void* assetManager, EntityId asset, int index);
int get_animation_count(void* assetManager, EntityId asset);
void get_animation_name(void* assetManager, EntityId asset, char *const outPtr, int index);
float get_animation_duration(void* assetManager, EntityId asset, int index);
void get_morph_target_name(void* assetManager, EntityId asset, const char *meshName, char *const outPtr, int index);
int get_morph_target_name_count(void* assetManager, EntityId asset, const char *meshName);
void remove_asset(const void* const viewer, EntityId asset);
void clear_assets(const void* const viewer);
void load_texture(void* assetManager, EntityId asset, const char *assetPath, int renderableIndex);
void set_texture(void* assetManager, EntityId asset);
bool set_material_color(void* assetManager, EntityId asset, const char* meshName, int materialIndex, const float r, const float g, const float b, const float a);
void transform_to_unit_cube(void* assetManager, EntityId asset);
void set_position(void* assetManager, EntityId asset, float x, float y, float z);
void set_rotation(void* assetManager, EntityId asset, float rads, float x, float y, float z);
void set_scale(void* assetManager, EntityId asset, float scale);
void move_camera_to_asset(const void* const viewer, EntityId asset);
void set_camera_exposure(const void* const viewer, float aperture, float shutterSpeed, float sensitivity);
void set_camera_position(const void* const viewer, float x, float y, float z);
void set_camera_rotation(const void* const viewer, float rads, float x, float y, float z);
void set_camera_model_matrix(const void* const viewer, const float *const matrix);
void set_camera_focal_length(const void* const viewer, float focalLength);
void set_camera_focus_distance(const void* const viewer, float focusDistance);
int hide_mesh(void* assetManager, EntityId asset, const char* meshName);
int reveal_mesh(void* assetManager, EntityId asset, const char* meshName);
void ios_dummy();


#endif

#ifndef _POLYVOX_FILAMENT_API_H
#define _POLYVOX_FILAMENT_API_H

#include "ResourceBuffer.hpp"

#include <stddef.h>

typedef int32_t EntityId;

void* create_filament_viewer(void *context, ResourceLoaderWrapper* loader);
ResourceLoaderWrapper* make_resource_loader(LoadResourceFromOwner loadFn, FreeResourceFromOwner freeFn, void* owner);
void delete_filament_viewer(void *viewer);
void* get_asset_manager(void* viewer);
void create_render_target(void *viewer, uint32_t textureId, uint32_t width, uint32_t height);
void clear_background_image(void *viewer);
void set_background_image(void *viewer, const char *path);
void set_background_image_position(void *viewer, float x, float y, bool clamp);
void set_background_color(void *viewer, const float r, const float g, const float b, const float a);
void load_skybox(void *viewer, const char *skyboxPath);
void load_ibl(void *viewer, const char *iblPath, float intensity);
void remove_skybox(void *viewer);
void remove_ibl(void *viewer);
EntityId add_light(void *viewer, uint8_t type, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows);
void remove_light(void *viewer, EntityId entityId);
void clear_lights(void *viewer);
EntityId load_glb(void *assetManager, const char *assetPath, bool unlit);
EntityId load_gltf(void *assetManager, const char *assetPath, const char *relativePath);
bool set_camera(void *viewer, EntityId asset, const char *nodeName);
void render(void *viewer, uint64_t frameTimeInNanos);
void create_swap_chain(void *viewer, void *surface, uint32_t width, uint32_t height);
void destroy_swap_chain(void *viewer);
void set_frame_interval(void *viewer, float interval);
void* get_renderer(void *viewer);
void update_viewport_and_camera_projection(void *viewer, int width, int height, float scaleFactor);
void scroll_begin(void *viewer);
void scroll_update(void *viewer, float x, float y, float z);
void scroll_end(void *viewer);

void grab_begin(void *viewer, float x, float y, bool pan);
void grab_update(void *viewer, float x, float y);
void grab_end(void *viewer);

void apply_weights(
    void* assetManager,
    EntityId asset, 
    const char *const entityName, 
    float *const weights, 
    int count
);

bool set_morph_animation(
    void* assetManager,
    EntityId asset,
    const char *const entityName,
    const float *const morphData,
    int numMorphWeights,
    int numFrames,
    float frameLengthInMs);

void set_bone_animation(
    void* assetManager,
    EntityId asset, 
    const float* const frameData,
    int numFrames, 
    int numBones,
    const char** const boneNames,
    const char* const meshName,
    float frameLengthInMs);

void play_animation(void* assetManager, EntityId asset, int index, bool loop, bool reverse);
void set_animation_frame(void* assetManager, EntityId asset, int animationIndex, int animationFrame);
void stop_animation(void* assetManager, EntityId asset, int index);
int get_animation_count(void* assetManager, EntityId asset);
void get_animation_name(void* assetManager, EntityId asset, char *const outPtr, int index);
void get_morph_target_name(void* assetManager, EntityId asset, const char *meshName, char *const outPtr, int index);
int get_morph_target_name_count(void* assetManager, EntityId asset, const char *meshName);
void remove_asset(void *viewer, EntityId asset);
void clear_assets(void *viewer);
void load_texture(void* assetManager, EntityId asset, const char *assetPath, int renderableIndex);
void set_texture(void* assetManager, EntityId asset);
void transform_to_unit_cube(void* assetManager, EntityId asset);
void set_position(void* assetManager, EntityId asset, float x, float y, float z);
void set_rotation(void* assetManager, EntityId asset, float rads, float x, float y, float z);
void set_scale(void* assetManager, EntityId asset, float scale);
void set_camera_exposure(void *viewer, float aperture, float shutterSpeed, float sensitivity);
void set_camera_position(void *viewer, float x, float y, float z);
void set_camera_rotation(void *viewer, float rads, float x, float y, float z);
void set_camera_model_matrix(void *viewer, const float *const matrix);
void set_camera_focal_length(void *viewer, float focalLength);
void set_camera_focus_distance(void *viewer, float focusDistance);
void ios_dummy();

#endif

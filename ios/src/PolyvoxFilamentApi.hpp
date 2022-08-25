#ifndef _POLYVOX_FILAMENT_API_H
#define _POLYVOX_FILAMENT_API_H

#include "ResourceBuffer.hpp"

typedef struct ResourceBuffer ResourceBuffer;

//ResourceBuffer create_resource_buffer(const void* data, const uint32_t size, const uint32_t id);
void* filament_viewer_new(void* texture, void* loadResource, void* freeResource);
void* filament_viewer_delete(void* viewer);
void set_background_image(void* viewer, const char* path);
void load_skybox(void* viewer, const char* skyboxPath);
void load_ibl(void* viewer, const char* iblPath);
void remove_skybox(void* viewer);
void remove_ibl(void* viewer);
void* load_glb(void* viewer, const char* assetPath);
void* load_gltf(void* viewer, const char* assetPath, const char* relativePath);
bool set_camera(void* viewer, void* asset, const char* nodeName);
void render(void* viewer);
void destroy_swap_chain(void* viewer);
void* get_renderer(void* viewer);
void update_viewport_and_camera_projection(void* viewer, int width, int height, float scaleFactor);
   
void scroll(void* viewer, float x, float y , float z);
    
void grab_begin(void* viewer, int x, int y, bool pan);
void grab_update(void* viewer, int x, int y);
    
void grab_end(void* viewer);
    
void apply_weights(void* asset, float* const weights, int count);
    
void animate_weights(void* asset, float* data, int numWeights, int numFrames,  float frameRate);
    
void play_animation(void* asset, int index, bool loop);

int get_animation_count(void* asset);
    
void get_animation_name(void* asset, char* const outPtr, int index);

void get_target_name(void* asset, const char* meshName, char* const outPtr, int index );

int get_target_name_count(void* asset, const char* meshName);
    
void remove_asset(void* viewer, void* asset);
    
void clear_assets(void* viewer);
    
void load_texture(void* asset, const char* assetPath, int renderableIndex);
void set_texture(void* asset);
    
void transform_to_unit_cube(void* asset);
    
void set_position(void* asset, float x, float y, float z);
    
void set_rotation(void* asset, float rads, float x, float y, float z);

void stop_animation(void* asset, int index);

void set_camera_position(void* viewer, float x, float y, float z);

void set_camera_rotation(void* viewer, float rads, float x, float y, float z);
void set_camera_focal_length(void* viewer, float focalLength);
void set_camera_focus_distance(void* viewer, float focusDistance);
      
#endif

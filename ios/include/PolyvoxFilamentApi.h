#ifndef _POLYVOX_FILAMENT_API_H
#define _POLYVOX_FILAMENT_API_H

#include "ResourceBuffer.hpp"

typedef struct ResourceBuffer ResourceBuffer;

//ResourceBuffer create_resource_buffer(const void* data, const uint32_t size, const uint32_t id);
void* filament_viewer_new(void* context, ResourceBuffer (*loadResource)(const char*), void (*freeResource)(uint32_t));
void* filament_viewer_delete(void* viewer);
void create_render_target(void* viewer, uint32_t textureId, uint32_t width, uint32_t height);
void set_background_image(void* viewer, const char* path);
void set_background_image_position(void* viewer, float x, float y, bool clamp);
void load_skybox(void* viewer, const char* skyboxPath);
void load_ibl(void* viewer, const char* iblPath);
void remove_skybox(void* viewer);
void remove_ibl(void* viewer);
int32_t add_light(void* viewer, uint8_t type, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows);
void remove_light(void* viewer, int32_t entityId);
void clear_lights(void* viewer);
void* load_glb(void* viewer, const char* assetPath);
void* load_gltf(void* viewer, const char* assetPath, const char* relativePath);
bool set_camera(void* viewer, void* asset, const char* nodeName);
void render(void* viewer, uint64_t frameTimeInNanos);
void create_swap_chain(void* viewer, void* surface, uint32_t width, uint32_t height);
void destroy_swap_chain(void* viewer);
void set_frame_interval(void* viewer, float interval);
void* get_renderer(void* viewer);
void update_viewport_and_camera_projection(void* viewer, int width, int height, float scaleFactor);
   
void scroll_begin(void* viewer);
void scroll_update(void* viewer, float x, float y , float z);
void scroll_end(void* viewer);
    
void grab_begin(void* viewer, float x, float y, bool pan);
void grab_update(void* viewer, float x, float y);
void grab_end(void* viewer);

void apply_weights(void* asset, float* const weights, int count);
    
void animate_weights(void* asset, float* data, int numWeights, int numFrames,  float frameRate);
    
void play_animation(void* asset, int index, bool loop, bool reverse);
void stop_animation(void* asset, int index);

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
void set_scale(void* asset, float scale);

void set_camera_position(void* viewer, float x, float y, float z);
void set_camera_rotation(void* viewer, float rads, float x, float y, float z);
void set_camera_focal_length(void* viewer, float focalLength);
void set_camera_focus_distance(void* viewer, float focusDistance);
      
#endif

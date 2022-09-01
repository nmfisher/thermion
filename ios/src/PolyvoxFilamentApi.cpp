#ifndef _POLYVOX_FILAMENT_API_H
#define _POLYVOX_FILAMENT_API_H

#include "ResourceBuffer.hpp"
#include "FilamentViewer.hpp"
#include "Log.hpp"

using namespace polyvox;

extern "C" {
//  ResourceBuffer create_resource_buffer(const void* data, const uint32_t size, const uint32_t id) {
//    return ResourceBuffer {data, size, id };
//  }

  void* filament_viewer_new(void* texture, ResourceBuffer (*loadResource)(const char*), void (*freeResource)(uint32_t)) {
    return nullptr;
  }
  
  void filament_viewer_delete(void* viewer) {
    delete((FilamentViewer*)viewer);
    Log(
      "deleted"
    );
  }

  void set_background_image(void* viewer, const char* path) {
    ((FilamentViewer*)viewer)->setBackgroundImage(path);
  }

  void load_skybox(void* viewer, const char* skyboxPath) {
    ((FilamentViewer*)viewer)->loadSkybox(skyboxPath);
  }

  void load_ibl(void* viewer, const char* iblPath) {
    ((FilamentViewer*)viewer)->loadIbl(iblPath);
  }

  void remove_skybox(void* viewer) {
    ((FilamentViewer*)viewer)->removeSkybox();
  }

  
  void remove_ibl(void* viewer) {
    ((FilamentViewer*)viewer)->removeIbl();
  }

  void* load_glb(void* viewer, const char* assetPath) {
    return ((FilamentViewer*)viewer)->loadGlb(assetPath);
  }

  void* load_gltf(void* viewer, const char* assetPath, const char* relativePath) {
    return ((FilamentViewer*)viewer)->loadGltf(assetPath, relativePath);
  }

  bool set_camera(void* viewer, void* asset, const char* nodeName) {
    return ((FilamentViewer*)viewer)->setCamera((SceneAsset*)asset, nodeName);
  }

  void set_camera_position(void* viewer, float x, float y, float z) {
    ((FilamentViewer*)viewer)->setCameraPosition(x, y, z);
  }

  void set_camera_rotation(void* viewer, float rads, float x, float y, float z) {
    ((FilamentViewer*)viewer)->setCameraRotation(rads, x, y, z);
  }

  void set_camera_focal_length(void* viewer, float focalLength) {
    ((FilamentViewer*)viewer)->setCameraFocalLength(focalLength);
  }

  void render(
    void* viewer
  ) {
    ((FilamentViewer*)viewer)->render();
  }

  void destroy_swap_chain(void* viewer) {
    ((FilamentViewer*)viewer)->destroySwapChain();
  }

  void* get_renderer(void* viewer) {
    return ((FilamentViewer*)viewer)->getRenderer();
  }

  void update_viewport_and_camera_projection(void* viewer, int width, int height, float scaleFactor) {
    return ((FilamentViewer*)viewer)->updateViewportAndCameraProjection(width, height, scaleFactor);
    
  }

  void scroll(void* viewer, float x, float y, float delta) {
    return ((FilamentViewer*)viewer)->scroll(x, y, delta);
  }

  void grab_begin(void* viewer, float x, float y, bool pan) {

    ((FilamentViewer*)viewer)->grabBegin(x, y, pan);
  }

  void grab_update(void* viewer, float x, float y) {
    ((FilamentViewer*)viewer)->grabUpdate(x, y);
  }

  void grab_end(void* viewer) {
    ((FilamentViewer*)viewer)->grabEnd();
  }

  void apply_weights(void* asset, float* const weights, int count) {
    ((SceneAsset*)asset)->applyWeights(weights, count);
  }

  void animate_weights(void* asset, float* data, int numWeights, int numFrames,  float frameRate) {
    ((SceneAsset*)asset)->animateWeights((float*)data, numWeights, numFrames, frameRate);
  }

  void play_animation(void* asset, int index, bool loop) {
    ((SceneAsset*)asset)->playAnimation(index, loop);
  }

  int get_animation_count(void* asset) {
    auto names = ((SceneAsset*)asset)->getAnimationNames();
    return names->size();
  }

  void get_animation_name(void* asset, char* const outPtr, int index) {
    auto names = ((SceneAsset*)asset)->getAnimationNames();
    string name = names->at(index);
    strcpy(outPtr, name.c_str());
  }
  
  int get_target_name_count(void* asset, const char* meshName) {
    unique_ptr<vector<string>> names = ((SceneAsset*)asset)->getTargetNames(meshName);
    return names->size();
  }

  void get_target_name(void* asset, const char* meshName, char* const outPtr, int index ) {
    unique_ptr<vector<string>> names = ((SceneAsset*)asset)->getTargetNames(meshName);
    string name = names->at(index);
    strcpy(outPtr, name.c_str());
  }

  void remove_asset(void* viewer, void* asset) {
    ((FilamentViewer*)viewer)->removeAsset((SceneAsset*)asset);
  }

  void clear_assets(void* viewer) {
    ((FilamentViewer*)viewer)->clearAssets();
  }

  void load_texture(void* asset, const char* assetPath, int renderableIndex) {
    ((SceneAsset*)asset)->loadTexture(assetPath, renderableIndex);
  }

  void set_texture(void* asset) {
    ((SceneAsset*)asset)->setTexture();
  }

  void transform_to_unit_cube(void* asset) {
    ((SceneAsset*)asset)->transformToUnitCube();
  }

  void set_position(void* asset, float x, float y, float z) {
     ((SceneAsset*)asset)->setPosition(x, y, z);
  }

   void set_rotation(void* asset, float rads, float x, float y, float z) {
     ((SceneAsset*)asset)->setRotation(rads, x, y, z);
   }

  void set_scale(void* asset, float scale) {
     ((SceneAsset*)asset)->setScale(scale);
   }

  void stop_animation(void* asset, int index) {
     ((SceneAsset*)asset)->stopAnimation(index);
  }
  
}

#endif

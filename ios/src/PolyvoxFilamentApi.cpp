#include "ResourceBuffer.hpp"
#include "FilamentViewer.hpp"
#include "filament/LightManager.h"
#include "Log.hpp"

using namespace polyvox;

extern "C" {
//  ResourceBuffer create_resource_buffer(const void* data, const uint32_t size, const uint32_t id) {
//    return ResourceBuffer {data, size, id };
//  }

  void* filament_viewer_new(void* context, ResourceBuffer (*loadResource)(char const*), void (*freeResource)(unsigned int)) {
    FilamentViewer* v = new FilamentViewer(context, loadResource, freeResource);
    return (void*)v;
  }

  void create_render_target(void* viewer, uint32_t textureId, uint32_t width, uint32_t height) {
    ((FilamentViewer*)viewer)->createRenderTarget(textureId, width, height);
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

  void set_background_image_position(void* viewer, float x, float y, bool clamp) {
  ((FilamentViewer*)viewer)->setBackgroundImagePosition(x, y, clamp);
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

  int32_t add_light(void* viewer, uint8_t type, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows) { 
    return ((FilamentViewer*)viewer)->addLight((LightManager::Type)type, colour, intensity, posX, posY, posZ, dirX, dirY, dirZ, shadows);
  }

  void remove_light(void* viewer, int32_t entityId) {
    ((FilamentViewer*)viewer)->removeLight(entityId);
  }

  void clear_lights(void* viewer) {
    ((FilamentViewer*)viewer)->clearLights();
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
    void* viewer,
    uint64_t frameTimeInNanos
  ) {
    ((FilamentViewer*)viewer)->render(frameTimeInNanos);
  }

  void set_frame_interval(
    void* viewer,
    float frameInterval
  ) {
    ((FilamentViewer*)viewer)->setFrameInterval(frameInterval);
  }

  void destroy_swap_chain(void* viewer) {
    ((FilamentViewer*)viewer)->destroySwapChain();
  }

  void create_swap_chain(void* viewer, void* surface=nullptr, uint32_t width=0, uint32_t height=0) {
    ((FilamentViewer*)viewer)->createSwapChain(surface, width, height);
  }

  void* get_renderer(void* viewer) {
    return ((FilamentViewer*)viewer)->getRenderer();
  }

  void update_viewport_and_camera_projection(void* viewer, int width, int height, float scaleFactor) {
    return ((FilamentViewer*)viewer)->updateViewportAndCameraProjection(width, height, scaleFactor);
  }

  void scroll_update(void* viewer, float x, float y, float delta) {
    ((FilamentViewer*)viewer)->scrollUpdate(x, y, delta);
  }

  void scroll_begin(void* viewer) {
    ((FilamentViewer*)viewer)->scrollBegin();
  }

  void scroll_end(void* viewer) {
    ((FilamentViewer*)viewer)->scrollEnd();
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
    ((SceneAsset*)asset)->setMorphTargetWeights(weights, count);
  }

  void set_animation(
    void* asset, 
    float* morphData, 
    int numMorphWeights, 
    float* boneData, 
    const char** boneNames, 
    const char** meshNames, 
    int numBones, 
    int numFrames, 
    float frameLengthInMs) {
    ((SceneAsset*)asset)->setAnimation(
      morphData, 
      numMorphWeights, 
      boneData, 
      boneNames, 
      meshNames,
      numBones, 
      numFrames, 
      frameLengthInMs
    );
  }


  void set_bone_transform(
    void* asset, 
    const char* boneName, 
    const char* entityName,
    float transX, 
    float transY, 
    float transZ, 
    float quatX,
    float quatY,
    float quatZ,
    float quatW
) {
    ((SceneAsset*)asset)->setBoneTransform(
        boneName, 
        entityName, 
        transX, 
        transY, 
        transZ, 
        quatX, 
        quatY, 
        quatZ, 
        quatW
    );

  }


  void play_animation(void* asset, int index, bool loop, bool reverse) {
    ((SceneAsset*)asset)->playAnimation(index, loop, reverse);
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
  
  int get_morph_target_name_count(void* asset, const char* meshName) {
    unique_ptr<vector<string>> names = ((SceneAsset*)asset)->getMorphTargetNames(meshName);
    return names->size();
  }

  void get_morph_target_name(void* asset, const char* meshName, char* const outPtr, int index ) {
    unique_ptr<vector<string>> names = ((SceneAsset*)asset)->getMorphTargetNames(meshName);
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

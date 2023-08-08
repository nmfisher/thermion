#include "ResourceBuffer.hpp"

#include "FilamentViewer.hpp"
#include "filament/LightManager.h"
#include "Log.hpp"
#include "ThreadPool.hpp"

#include <thread>
#include <functional>

using namespace polyvox;

#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))

extern "C" {

  #include "PolyvoxFilamentApi.h"

  FLUTTER_PLUGIN_EXPORT const void* create_filament_viewer(const void* context, const ResourceLoaderWrapper* const loader) {
      return (void*) new FilamentViewer(context, loader);
  }

  FLUTTER_PLUGIN_EXPORT ResourceLoaderWrapper* make_resource_loader(LoadResourceFromOwner loadFn, FreeResourceFromOwner freeFn, void* const owner) {
    return new ResourceLoaderWrapper(loadFn, freeFn, owner);
  }

  FLUTTER_PLUGIN_EXPORT void create_render_target(const void* const viewer, uint32_t textureId, uint32_t width, uint32_t height) {
      ((FilamentViewer*)viewer)->createRenderTarget(textureId, width, height);
  }
  
  FLUTTER_PLUGIN_EXPORT void delete_filament_viewer(const void* const viewer) {
    delete((FilamentViewer*)viewer);
  }

  FLUTTER_PLUGIN_EXPORT void set_background_color(const void* const viewer, const float r, const float g, const float b, const float a) {
      ((FilamentViewer*)viewer)->setBackgroundColor(r, g, b, a);
  }

  FLUTTER_PLUGIN_EXPORT void clear_background_image(const void* const viewer) {
      ((FilamentViewer*)viewer)->clearBackgroundImage();
  }

  FLUTTER_PLUGIN_EXPORT void set_background_image(const void* const viewer, const char* path) {
      ((FilamentViewer*)viewer)->setBackgroundImage(path);
  }

  FLUTTER_PLUGIN_EXPORT void set_background_image_position(const void* const viewer, float x, float y, bool clamp) {
      ((FilamentViewer*)viewer)->setBackgroundImagePosition(x, y, clamp);
  }

  FLUTTER_PLUGIN_EXPORT void load_skybox(const void* const viewer, const char* skyboxPath) {
      ((FilamentViewer*)viewer)->loadSkybox(skyboxPath);
  }

  FLUTTER_PLUGIN_EXPORT void load_ibl(const void* const viewer, const char* iblPath, float intensity) {
      ((FilamentViewer*)viewer)->loadIbl(iblPath, intensity);
  }

  FLUTTER_PLUGIN_EXPORT void remove_skybox(const void* const viewer) {
      ((FilamentViewer*)viewer)->removeSkybox();
  }
  
  FLUTTER_PLUGIN_EXPORT void remove_ibl(const void* const viewer) {
      ((FilamentViewer*)viewer)->removeIbl();
  }

  FLUTTER_PLUGIN_EXPORT EntityId add_light(const void* const viewer, uint8_t type, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows) { 
      return ((FilamentViewer*)viewer)->addLight((LightManager::Type)type, colour, intensity, posX, posY, posZ, dirX, dirY, dirZ, shadows);
  }

  FLUTTER_PLUGIN_EXPORT void remove_light(const void* const viewer, int32_t entityId) {
      ((FilamentViewer*)viewer)->removeLight(entityId);
  }

  FLUTTER_PLUGIN_EXPORT void clear_lights(const void* const viewer) {
      ((FilamentViewer*)viewer)->clearLights();
  }

  FLUTTER_PLUGIN_EXPORT EntityId load_glb(void* assetManager, const char* assetPath, bool unlit) {
      return ((AssetManager*)assetManager)->loadGlb(assetPath, unlit);
  }

  FLUTTER_PLUGIN_EXPORT EntityId load_gltf(void* assetManager, const char* assetPath, const char* relativePath) {
      return ((AssetManager*)assetManager)->loadGltf(assetPath, relativePath);
  }

  FLUTTER_PLUGIN_EXPORT bool set_camera(const void* const viewer, EntityId asset, const char* nodeName) {
      return ((FilamentViewer*)viewer)->setCamera(asset, nodeName);
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_focus_distance(const void* const viewer, float distance) {
      ((FilamentViewer*)viewer)->setCameraFocusDistance(distance);
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_exposure(const void* const viewer, float aperture, float shutterSpeed, float sensitivity) {
      ((FilamentViewer*)viewer)->setCameraExposure(aperture, shutterSpeed, sensitivity);
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_position(const void* const viewer, float x, float y, float z) {
      ((FilamentViewer*)viewer)->setCameraPosition(x, y, z);
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_rotation(const void* const viewer, float rads, float x, float y, float z) {
      ((FilamentViewer*)viewer)->setCameraRotation(rads, x, y, z);
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_model_matrix(const void* const viewer, const float* const matrix) {
      ((FilamentViewer*)viewer)->setCameraModelMatrix(matrix);
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_focal_length(const void* const viewer, float focalLength) {
      ((FilamentViewer*)viewer)->setCameraFocalLength(focalLength);
  }

  FLUTTER_PLUGIN_EXPORT void render(
    const void* const viewer,
    uint64_t frameTimeInNanos
  ) {
      ((FilamentViewer*)viewer)->render(frameTimeInNanos);
  }

  FLUTTER_PLUGIN_EXPORT void set_frame_interval(
    const void* const viewer,
    float frameInterval
  ) {
      ((FilamentViewer*)viewer)->setFrameInterval(frameInterval);
  }

  FLUTTER_PLUGIN_EXPORT void destroy_swap_chain(const void* const viewer) {
      ((FilamentViewer*)viewer)->destroySwapChain();
  }

  FLUTTER_PLUGIN_EXPORT void create_swap_chain(const void* const viewer, const void* const surface=nullptr, uint32_t width=0, uint32_t height=0) {
      ((FilamentViewer*)viewer)->createSwapChain(surface, width, height);
  }

  FLUTTER_PLUGIN_EXPORT void update_viewport_and_camera_projection(const void* const viewer, int width, int height, float scaleFactor) {
      return ((FilamentViewer*)viewer)->updateViewportAndCameraProjection(width, height, scaleFactor);
  }

  FLUTTER_PLUGIN_EXPORT void scroll_update(const void* const viewer, float x, float y, float delta) {
      ((FilamentViewer*)viewer)->scrollUpdate(x, y, delta);
  }

  FLUTTER_PLUGIN_EXPORT void scroll_begin(const void* const viewer) {
      ((FilamentViewer*)viewer)->scrollBegin();
  }

  FLUTTER_PLUGIN_EXPORT void scroll_end(const void* const viewer) {
      ((FilamentViewer*)viewer)->scrollEnd();
  }

  FLUTTER_PLUGIN_EXPORT void grab_begin(const void* const viewer, float x, float y, bool pan) {
      ((FilamentViewer*)viewer)->grabBegin(x, y, pan);
  }

  FLUTTER_PLUGIN_EXPORT void grab_update(const void* const viewer, float x, float y) {
      ((FilamentViewer*)viewer)->grabUpdate(x, y);
  }

  FLUTTER_PLUGIN_EXPORT void grab_end(const void* const viewer) {
      ((FilamentViewer*)viewer)->grabEnd();
  }

  FLUTTER_PLUGIN_EXPORT void* get_asset_manager(const void* const viewer) {
      return (void*)((FilamentViewer*)viewer)->getAssetManager();
  }

  FLUTTER_PLUGIN_EXPORT void apply_weights(
    void* assetManager,
    EntityId asset, 
    const char* const entityName, 
    float* const weights, 
    int count) {
    // ((AssetManager*)assetManager)->setMorphTargetWeights(asset, entityName, weights, count);
  }

  FLUTTER_PLUGIN_EXPORT void set_morph_target_weights(
    void* assetManager,
    EntityId asset, 
    const char* const entityName,
    const float* const weights,
    const int numWeights
  ) {

      return ((AssetManager*)assetManager)->setMorphTargetWeights(
        asset, 
        entityName,
        weights,
        numWeights
      );
  }

  FLUTTER_PLUGIN_EXPORT bool set_morph_animation(
    void* assetManager,
    EntityId asset, 
    const char* const entityName,
    const float* const morphData,
    int numMorphWeights, 
    int numFrames, 
    float frameLengthInMs) {

      return ((AssetManager*)assetManager)->setMorphAnimationBuffer(
        asset, 
        entityName,
        morphData, 
        numMorphWeights, 
        numFrames, 
        frameLengthInMs
      );
  }

  FLUTTER_PLUGIN_EXPORT void set_bone_animation(
    void* assetManager,
    EntityId asset, 
    const float* const frameData,
    int numFrames, 
    int numBones,
    const char** const boneNames,
    const char** const meshNames,
    int numMeshTargets,
    float frameLengthInMs) {
      ((AssetManager*)assetManager)->setBoneAnimationBuffer(
        asset, 
        frameData,
        numFrames,
        numBones,
        boneNames, 
        meshNames,
        numMeshTargets,
        frameLengthInMs
      );
    }



//   void set_bone_transform(
//     EntityId asset, 
//     const char* boneName, 
//     const char* entityName,
//     float transX, 
//     float transY, 
//     float transZ, 
//     float quatX,
//     float quatY,
//     float quatZ,
//     float quatW
// ) {
//     ((AssetManager*)assetManager)->setBoneTransform(
//         boneName, 
//         entityName, 
//         transX, 
//         transY, 
//         transZ, 
//         quatX, 
//         quatY, 
//         quatZ, 
//         quatW,
//         false
//     );

//   }


  FLUTTER_PLUGIN_EXPORT void play_animation(
    void* assetManager,
    EntityId asset, 
    int index, 
    bool loop, 
    bool reverse,
    float crossfade) {
      ((AssetManager*)assetManager)->playAnimation(asset, index, loop, reverse, crossfade);
  }

  FLUTTER_PLUGIN_EXPORT void set_animation_frame(
    void* assetManager,
    EntityId asset, 
    int animationIndex, 
    int animationFrame) {
    // ((AssetManager*)assetManager)->setAnimationFrame(asset, animationIndex, animationFrame);
  }


  FLUTTER_PLUGIN_EXPORT float get_animation_duration(void* assetManager, EntityId asset, int animationIndex) {
    return ((AssetManager*)assetManager)->getAnimationDuration(asset, animationIndex);
  }

  FLUTTER_PLUGIN_EXPORT int get_animation_count(
    void* assetManager,
    EntityId asset) {
      auto names = ((AssetManager*)assetManager)->getAnimationNames(asset);
      return names->size();
  }

  FLUTTER_PLUGIN_EXPORT void get_animation_name(
    void* assetManager,
    EntityId asset, 
    char* const outPtr, 
    int index
  ) {
      auto names = ((AssetManager*)assetManager)->getAnimationNames(asset);
      string name = names->at(index);
      strcpy(outPtr, name.c_str());
  }
  
  FLUTTER_PLUGIN_EXPORT int get_morph_target_name_count(void* assetManager, EntityId asset, const char* meshName) {
    //std::packaged_task<int()> lambda([=]() mutable  {
      unique_ptr<vector<string>> names = ((AssetManager*)assetManager)->getMorphTargetNames(asset, meshName);
      return names->size();
    

    //return fut.get();
  }

  FLUTTER_PLUGIN_EXPORT void get_morph_target_name(void* assetManager, EntityId asset, const char* meshName, char* const outPtr, int index ) {
      unique_ptr<vector<string>> names = ((AssetManager*)assetManager)->getMorphTargetNames(asset, meshName);
      string name = names->at(index);
      strcpy(outPtr, name.c_str());
  }

  FLUTTER_PLUGIN_EXPORT void remove_asset(const void* const viewer, EntityId asset) {
      ((FilamentViewer*)viewer)->removeAsset(asset);
  }

  FLUTTER_PLUGIN_EXPORT void clear_assets(const void* const viewer) {
      ((FilamentViewer*)viewer)->clearAssets();
  }

  FLUTTER_PLUGIN_EXPORT void load_texture(void* assetManager, EntityId asset, const char* assetPath, int renderableIndex) {
    // ((AssetManager*)assetManager)->loadTexture(assetPath, renderableIndex);
  }

  FLUTTER_PLUGIN_EXPORT void set_texture(void* assetManager, EntityId asset) {
    // ((AssetManager*)assetManager)->setTexture();
  }

  FLUTTER_PLUGIN_EXPORT void transform_to_unit_cube(void* assetManager, EntityId asset) {
      ((AssetManager*)assetManager)->transformToUnitCube(asset);
  }

  FLUTTER_PLUGIN_EXPORT void set_position(void* assetManager, EntityId asset, float x, float y, float z) {
      ((AssetManager*)assetManager)->setPosition(asset, x, y, z);
  }

  FLUTTER_PLUGIN_EXPORT void set_rotation(void* assetManager, EntityId asset, float rads, float x, float y, float z) {
      ((AssetManager*)assetManager)->setRotation(asset, rads, x, y, z);
   }

  FLUTTER_PLUGIN_EXPORT void set_scale(void* assetManager, EntityId asset, float scale) {
      ((AssetManager*)assetManager)->setScale(asset, scale);
  }

  FLUTTER_PLUGIN_EXPORT void stop_animation(void* assetManager, EntityId asset, int index) {
      ((AssetManager*)assetManager)->stopAnimation(asset, index);
  }

  FLUTTER_PLUGIN_EXPORT int hide_mesh(void* assetManager, EntityId asset, const char* meshName) {
      return ((AssetManager*)assetManager)->hide(asset, meshName);
  }

  FLUTTER_PLUGIN_EXPORT int reveal_mesh(void* assetManager, EntityId asset, const char* meshName) {
      return ((AssetManager*)assetManager)->reveal(asset, meshName);
  }

  FLUTTER_PLUGIN_EXPORT void ios_dummy() {
    Log("Dummy called");
  }
}

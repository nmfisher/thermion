#include "ResourceBuffer.hpp"

#include "FilamentViewer.hpp"
#include "filament/LightManager.h"
#include "Log.hpp"
#include "ThreadPool.hpp"

#include <thread>
#include <functional>

using namespace polyvox;

#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))



// static ThreadPool* _tp;

extern "C" {

  #include "PolyvoxFilamentApi.h"

  FLUTTER_PLUGIN_EXPORT void* create_filament_viewer(void* context, ResourceLoaderWrapper* loader) {
    loader->load("foo");
    // if(!_tp) {
    //   _tp = new ThreadPool();
    // }
    // //std::packaged_task<void*()> lambda([=]() mutable  {
      return (void*) new FilamentViewer(context, loader);
    // });
    // auto fut = _tp->add_task(lambda);
    // fut.wait();
    // //return fut.get();
  }

  FLUTTER_PLUGIN_EXPORT ResourceLoaderWrapper* make_resource_loader(LoadResourceFromOwner loadFn, FreeResourceFromOwner freeFn, void* const owner) {
      return new ResourceLoaderWrapper(loadFn, freeFn, owner);
//      ResourceLoaderWrapper* lod(loadFn, freeFn, owner);
//      return &lod;
  }

  FLUTTER_PLUGIN_EXPORT void create_render_target(void* viewer, uint32_t textureId, uint32_t width, uint32_t height) {
    // //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->createRenderTarget(textureId, width, height);
    // });
    // auto fut = _tp->add_task(lambda);
    // fut.wait();
  }
  
  FLUTTER_PLUGIN_EXPORT void delete_filament_viewer(void* viewer) {
    delete((FilamentViewer*)viewer);
  }

  FLUTTER_PLUGIN_EXPORT void set_background_color(void* viewer, const float r, const float g, const float b, const float a) {
    // //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->setBackgroundColor(r, g, b, a);
    // });
    // auto fut = _tp->add_task(lambda);
    // fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void clear_background_image(void* viewer) {
    // //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->clearBackgroundImage();
    // });
    // auto fut = _tp->add_task(lambda);
    // fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void set_background_image(void* viewer, const char* path) {
    // //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->setBackgroundImage(path);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void set_background_image_position(void* viewer, float x, float y, bool clamp) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->setBackgroundImagePosition(x, y, clamp);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void load_skybox(void* viewer, const char* skyboxPath) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->loadSkybox(skyboxPath);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void load_ibl(void* viewer, const char* iblPath, float intensity) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->loadIbl(iblPath, intensity);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void remove_skybox(void* viewer) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->removeSkybox();
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }
  
  FLUTTER_PLUGIN_EXPORT void remove_ibl(void* viewer) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->removeIbl();
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT EntityId add_light(void* viewer, uint8_t type, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows) { 
    //std::packaged_task<EntityId()> lambda([=]() mutable  {
      return ((FilamentViewer*)viewer)->addLight((LightManager::Type)type, colour, intensity, posX, posY, posZ, dirX, dirY, dirZ, shadows);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
    //return fut.get();
  }

  FLUTTER_PLUGIN_EXPORT void remove_light(void* viewer, int32_t entityId) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->removeLight(entityId);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void clear_lights(void* viewer) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->clearLights();
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT EntityId load_glb(void* assetManager, const char* assetPath, bool unlit) {
    //std::packaged_task<EntityId()> lambda([=]() mutable  {
      return ((AssetManager*)assetManager)->loadGlb(assetPath, unlit);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
    //return fut.get();
  }

  FLUTTER_PLUGIN_EXPORT EntityId load_gltf(void* assetManager, const char* assetPath, const char* relativePath) {
    //std::packaged_task<EntityId()> lambda([=]() mutable  {
      return ((AssetManager*)assetManager)->loadGltf(assetPath, relativePath);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
    //return fut.get();
  }

  FLUTTER_PLUGIN_EXPORT bool set_camera(void* viewer, EntityId asset, const char* nodeName) {
    //std::packaged_task<bool()> lambda([=]() mutable  {
      return ((FilamentViewer*)viewer)->setCamera(asset, nodeName);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
    //return fut.get();
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_exposure(void* viewer, float aperture, float shutterSpeed, float sensitivity) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->setCameraExposure(aperture, shutterSpeed, sensitivity);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_position(void* viewer, float x, float y, float z) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->setCameraPosition(x, y, z);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_rotation(void* viewer, float rads, float x, float y, float z) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->setCameraRotation(rads, x, y, z);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_model_matrix(void* viewer, const float* const matrix) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->setCameraModelMatrix(matrix);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_focal_length(void* viewer, float focalLength) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->setCameraFocalLength(focalLength);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void render(
    void* viewer,
    uint64_t frameTimeInNanos
  ) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->render(frameTimeInNanos);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void set_frame_interval(
    void* viewer,
    float frameInterval
  ) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->setFrameInterval(frameInterval);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void destroy_swap_chain(void* viewer) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->destroySwapChain();
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void create_swap_chain(void* viewer, void* surface=nullptr, uint32_t width=0, uint32_t height=0) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->createSwapChain(surface, width, height);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void* get_renderer(void* viewer) {
    //std::packaged_task<void*()> lambda([=]() mutable  {
      return ((FilamentViewer*)viewer)->getRenderer();
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
    //return fut.get();
  }

  FLUTTER_PLUGIN_EXPORT void update_viewport_and_camera_projection(void* viewer, int width, int height, float scaleFactor) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      return ((FilamentViewer*)viewer)->updateViewportAndCameraProjection(width, height, scaleFactor);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void scroll_update(void* viewer, float x, float y, float delta) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->scrollUpdate(x, y, delta);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void scroll_begin(void* viewer) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->scrollBegin();
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void scroll_end(void* viewer) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->scrollEnd();
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void grab_begin(void* viewer, float x, float y, bool pan) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->grabBegin(x, y, pan);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void grab_update(void* viewer, float x, float y) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->grabUpdate(x, y);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void grab_end(void* viewer) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->grabEnd();
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void* get_asset_manager(void* viewer) {
    //std::packaged_task<void*()> lambda([=]() mutable  {
      return (void*)((FilamentViewer*)viewer)->getAssetManager();
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
    //return fut.get();
  }

  FLUTTER_PLUGIN_EXPORT void apply_weights(
    void* assetManager,
    EntityId asset, 
    const char* const entityName, 
    float* const weights, 
    int count) {
    // //std::packaged_task<void()> lambda([=]() mutable  {
    // ((AssetManager*)assetManager)->setMorphTargetWeights(asset, entityName, weights, count);
    // });
    // auto fut = _tp->add_task(lambda);
    // fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT bool set_morph_animation(
    void* assetManager,
    EntityId asset, 
    const char* const entityName,
    const float* const morphData,
    int numMorphWeights, 
    int numFrames, 
    float frameLengthInMs) {

    //std::packaged_task<void()> lambda([=]() mutable  {
      return ((AssetManager*)assetManager)->setMorphAnimationBuffer(
        asset, 
        entityName,
        morphData, 
        numMorphWeights, 
        numFrames, 
        frameLengthInMs
      );
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
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
    //std::packaged_task<void()> lambda([=]() mutable  {
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
      //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
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
    bool reverse) {
    
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((AssetManager*)assetManager)->playAnimation(asset, index, loop, reverse);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void set_animation_frame(
    void* assetManager,
    EntityId asset, 
    int animationIndex, 
    int animationFrame) {
    // //std::packaged_task<void()> lambda([=]() mutable  {
    // ((AssetManager*)assetManager)->setAnimationFrame(asset, animationIndex, animationFrame);
    // });
    // auto fut = _tp->add_task(lambda);
    // fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT int get_animation_count(
    void* assetManager,
    EntityId asset) {
    //std::packaged_task<int()> lambda([=]() mutable  {
      auto names = ((AssetManager*)assetManager)->getAnimationNames(asset);
      return names->size();
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
    //return fut.get();
  }

  FLUTTER_PLUGIN_EXPORT void get_animation_name(
    void* assetManager,
    EntityId asset, 
    char* const outPtr, 
    int index
  ) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      auto names = ((AssetManager*)assetManager)->getAnimationNames(asset);
      string name = names->at(index);
      strcpy(outPtr, name.c_str());
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }
  
  FLUTTER_PLUGIN_EXPORT int get_morph_target_name_count(void* assetManager, EntityId asset, const char* meshName) {
    //std::packaged_task<int()> lambda([=]() mutable  {
      unique_ptr<vector<string>> names = ((AssetManager*)assetManager)->getMorphTargetNames(asset, meshName);
      return names->size();
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
    //return fut.get();
  }

  FLUTTER_PLUGIN_EXPORT void get_morph_target_name(void* assetManager, EntityId asset, const char* meshName, char* const outPtr, int index ) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      unique_ptr<vector<string>> names = ((AssetManager*)assetManager)->getMorphTargetNames(asset, meshName);
      string name = names->at(index);
      strcpy(outPtr, name.c_str());
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void remove_asset(void* viewer, EntityId asset) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->removeAsset(asset);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void clear_assets(void* viewer) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((FilamentViewer*)viewer)->clearAssets();
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void load_texture(void* assetManager, EntityId asset, const char* assetPath, int renderableIndex) {
    // ((AssetManager*)assetManager)->loadTexture(assetPath, renderableIndex);
  }

  FLUTTER_PLUGIN_EXPORT void set_texture(void* assetManager, EntityId asset) {
    // ((AssetManager*)assetManager)->setTexture();
  }

  FLUTTER_PLUGIN_EXPORT void transform_to_unit_cube(void* assetManager, EntityId asset) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((AssetManager*)assetManager)->transformToUnitCube(asset);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void set_position(void* assetManager, EntityId asset, float x, float y, float z) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((AssetManager*)assetManager)->setPosition(asset, x, y, z);
     //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void set_rotation(void* assetManager, EntityId asset, float rads, float x, float y, float z) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((AssetManager*)assetManager)->setRotation(asset, rads, x, y, z);
     //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
   }

  FLUTTER_PLUGIN_EXPORT void set_scale(void* assetManager, EntityId asset, float scale) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((AssetManager*)assetManager)->setScale(asset, scale);
    //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void stop_animation(void* assetManager, EntityId asset, int index) {
    //std::packaged_task<void()> lambda([=]() mutable  {
      ((AssetManager*)assetManager)->stopAnimation(asset, index);
     //});
//    auto fut = _tp->add_task(lambda);
//    fut.wait();
  }

  FLUTTER_PLUGIN_EXPORT void ios_dummy() {
    Log("Dummy called");
  }
}

#include "ResourceBuffer.hpp"

#include "FilamentViewer.hpp"
#include "filament/LightManager.h"
#include "Log.hpp"
#include "ThreadPool.hpp"

#include <thread>
#include <functional>

using namespace polyvox;


extern "C" {

  #include "PolyvoxFilamentApi.h"

  const void* create_filament_viewer(const void* context, const ResourceLoaderWrapper* const loader, void* const platform) {
      return (const void*) new FilamentViewer(context, loader, platform);
  }

  ResourceLoaderWrapper* make_resource_loader(LoadFilamentResourceFromOwner loadFn, FreeFilamentResourceFromOwner freeFn, void* const owner) {
    return new ResourceLoaderWrapper(loadFn, freeFn, owner);
  }

  void create_render_target(const void* const viewer, uint32_t textureId, uint32_t width, uint32_t height) {
      ((FilamentViewer*)viewer)->createRenderTarget(textureId, width, height);
  }
  
  void delete_filament_viewer(const void* const viewer) {
    delete((FilamentViewer*)viewer);
  }

  void set_background_color(const void* const viewer, const float r, const float g, const float b, const float a) {
      ((FilamentViewer*)viewer)->setBackgroundColor(r, g, b, a);
  }

  void clear_background_image(const void* const viewer) {
      ((FilamentViewer*)viewer)->clearBackgroundImage();
  }

  void set_background_image(const void* const viewer, const char* path, bool fillHeight) {
      ((FilamentViewer*)viewer)->setBackgroundImage(path, fillHeight);
  }

  void set_background_image_position(const void* const viewer, float x, float y, bool clamp) {
      ((FilamentViewer*)viewer)->setBackgroundImagePosition(x, y, clamp);
  }

  void set_tone_mapping(const void* const viewer, int toneMapping) {
      ((FilamentViewer*)viewer)->setToneMapping((ToneMapping)toneMapping);
  }

  void set_bloom(const void* const viewer, float strength) {
        Log("Setting bloom to %f", strength);
      ((FilamentViewer*)viewer)->setBloom(strength);
  }

  void load_skybox(const void* const viewer, const char* skyboxPath) {
      ((FilamentViewer*)viewer)->loadSkybox(skyboxPath);
  }

  void load_ibl(const void* const viewer, const char* iblPath, float intensity) {
      ((FilamentViewer*)viewer)->loadIbl(iblPath, intensity);
  }

  void remove_skybox(const void* const viewer) {
      ((FilamentViewer*)viewer)->removeSkybox();
  }
  
  void remove_ibl(const void* const viewer) {
      ((FilamentViewer*)viewer)->removeIbl();
  }

  EntityId add_light(const void* const viewer, uint8_t type, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows) { 
      return ((FilamentViewer*)viewer)->addLight((LightManager::Type)type, colour, intensity, posX, posY, posZ, dirX, dirY, dirZ, shadows);
  }

  void remove_light(const void* const viewer, int32_t entityId) {
      ((FilamentViewer*)viewer)->removeLight(entityId);
  }

  void clear_lights(const void* const viewer) {
      ((FilamentViewer*)viewer)->clearLights();
  }

  EntityId load_glb(void* assetManager, const char* assetPath, bool unlit) {
      return ((AssetManager*)assetManager)->loadGlb(assetPath, unlit);
  }

  EntityId load_gltf(void* assetManager, const char* assetPath, const char* relativePath) {
      return ((AssetManager*)assetManager)->loadGltf(assetPath, relativePath);
  }

  bool set_camera(const void* const viewer, EntityId asset, const char* nodeName) {
      return ((FilamentViewer*)viewer)->setCamera(asset, nodeName);
  }

  void move_camera_to_asset(const void* const viewer, EntityId asset) {
      ((FilamentViewer*)viewer)->moveCameraToAsset(asset);
  }

  void set_view_frustum_culling(const void* const viewer, bool enabled) {
      ((FilamentViewer*)viewer)->setViewFrustumCulling(enabled);
  }  

  void set_camera_focus_distance(const void* const viewer, float distance) {
      ((FilamentViewer*)viewer)->setCameraFocusDistance(distance);
  }

  void set_camera_exposure(const void* const viewer, float aperture, float shutterSpeed, float sensitivity) {
      ((FilamentViewer*)viewer)->setCameraExposure(aperture, shutterSpeed, sensitivity);
  }

  void set_camera_position(const void* const viewer, float x, float y, float z) {
      ((FilamentViewer*)viewer)->setCameraPosition(x, y, z);
  }

  void set_camera_rotation(const void* const viewer, float rads, float x, float y, float z) {
      ((FilamentViewer*)viewer)->setCameraRotation(rads, x, y, z);
  }

  void set_camera_model_matrix(const void* const viewer, const float* const matrix) {
      ((FilamentViewer*)viewer)->setCameraModelMatrix(matrix);
  }

  void set_camera_focal_length(const void* const viewer, float focalLength) {
      ((FilamentViewer*)viewer)->setCameraFocalLength(focalLength);
  }

  void render(
    const void* const viewer,
    uint64_t frameTimeInNanos,
    void* pixelBuffer, 
    void (*callback)(void *buf, size_t size, void *data), 
    void* data) {
      ((FilamentViewer*)viewer)->render(frameTimeInNanos, pixelBuffer, callback, data);
  }

  void set_frame_interval(
    const void* const viewer,
    float frameInterval
  ) {
      ((FilamentViewer*)viewer)->setFrameInterval(frameInterval);
  }

  void destroy_swap_chain(const void* const viewer) {
      ((FilamentViewer*)viewer)->destroySwapChain();
  }

  void create_swap_chain(const void* const viewer, const void* const window, uint32_t width, uint32_t height) {
      ((FilamentViewer*)viewer)->createSwapChain(window, width, height);
  }

  void update_viewport_and_camera_projection(const void* const viewer, uint32_t width, uint32_t height, float scaleFactor) {
      return ((FilamentViewer*)viewer)->updateViewportAndCameraProjection(width, height, scaleFactor);
  }

  void scroll_update(const void* const viewer, float x, float y, float delta) {
      ((FilamentViewer*)viewer)->scrollUpdate(x, y, delta);
  }

  void scroll_begin(const void* const viewer) {
      ((FilamentViewer*)viewer)->scrollBegin();
  }

  void scroll_end(const void* const viewer) {
      ((FilamentViewer*)viewer)->scrollEnd();
  }

  void grab_begin(const void* const viewer, float x, float y, bool pan) {
      ((FilamentViewer*)viewer)->grabBegin(x, y, pan);
  }

  void grab_update(const void* const viewer, float x, float y) {
      ((FilamentViewer*)viewer)->grabUpdate(x, y);
  }

  void grab_end(const void* const viewer) {
      ((FilamentViewer*)viewer)->grabEnd();
  }

  void* get_asset_manager(const void* const viewer) {
      return (void*)((FilamentViewer*)viewer)->getAssetManager();
  }

  void apply_weights(
    void* assetManager,
    EntityId asset, 
    const char* const entityName, 
    float* const weights, 
    int count) {
    // ((AssetManager*)assetManager)->setMorphTargetWeights(asset, entityName, weights, count);
  }

  void set_morph_target_weights(
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



  bool set_morph_animation(
    void* assetManager,
    EntityId asset, 
    const char* const entityName,
    const float* const morphData,
    const int* const morphIndices,
    int numMorphTargets, 
    int numFrames, 
    float frameLengthInMs) {

      return ((AssetManager*)assetManager)->setMorphAnimationBuffer(
        asset, 
        entityName,
        morphData, 
        morphIndices,
        numMorphTargets,
        numFrames, 
        frameLengthInMs
      );
  }

  void set_bone_animation(
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


  void play_animation(
    void* assetManager,
    EntityId asset, 
    int index, 
    bool loop, 
    bool reverse,
    bool replaceActive,
    float crossfade) {
      ((AssetManager*)assetManager)->playAnimation(asset, index, loop, reverse, replaceActive, crossfade);
  }

  void set_animation_frame(
    void* assetManager,
    EntityId asset, 
    int animationIndex, 
    int animationFrame) {
    // ((AssetManager*)assetManager)->setAnimationFrame(asset, animationIndex, animationFrame);
  }


  float get_animation_duration(void* assetManager, EntityId asset, int animationIndex) {
    return ((AssetManager*)assetManager)->getAnimationDuration(asset, animationIndex);
  }

  int get_animation_count(
    void* assetManager,
    EntityId asset) {
      auto names = ((AssetManager*)assetManager)->getAnimationNames(asset);
      return names->size();
  }

  void get_animation_name(
    void* assetManager,
    EntityId asset, 
    char* const outPtr, 
    int index
  ) {
      auto names = ((AssetManager*)assetManager)->getAnimationNames(asset);
      string name = names->at(index);
      strcpy(outPtr, name.c_str());
  }
  
  int get_morph_target_name_count(void* assetManager, EntityId asset, const char* meshName) {
    //std::packaged_task<int()> lambda([=]() mutable  {
      unique_ptr<vector<string>> names = ((AssetManager*)assetManager)->getMorphTargetNames(asset, meshName);
      return names->size();

    //return fut.get();
  }

  void get_morph_target_name(void* assetManager, EntityId asset, const char* meshName, char* const outPtr, int index ) {
      unique_ptr<vector<string>> names = ((AssetManager*)assetManager)->getMorphTargetNames(asset, meshName);
      string name = names->at(index);
      strcpy(outPtr, name.c_str());
  }

  void remove_asset(const void* const viewer, EntityId asset) {
      ((FilamentViewer*)viewer)->removeAsset(asset);
  }

  void clear_assets(const void* const viewer) {
      ((FilamentViewer*)viewer)->clearAssets();
  }

  void load_texture(void* assetManager, EntityId asset, const char* assetPath, int renderableIndex) {
    // ((AssetManager*)assetManager)->loadTexture(assetPath, renderableIndex);
  }

  void set_texture(void* assetManager, EntityId asset) {
    // ((AssetManager*)assetManager)->setTexture();
  }

  bool set_material_color(void* assetManager, EntityId asset, const char* meshName, int materialIndex, const float r, const float g, const float b, const float a) {
    return ((AssetManager*)assetManager)->setMaterialColor(asset, meshName, materialIndex, r, g, b, a);
  }

  void transform_to_unit_cube(void* assetManager, EntityId asset) {
      ((AssetManager*)assetManager)->transformToUnitCube(asset);
  }

  void set_position(void* assetManager, EntityId asset, float x, float y, float z) {
      ((AssetManager*)assetManager)->setPosition(asset, x, y, z);
  }

  void set_rotation(void* assetManager, EntityId asset, float rads, float x, float y, float z) {
      ((AssetManager*)assetManager)->setRotation(asset, rads, x, y, z);
   }

  void set_scale(void* assetManager, EntityId asset, float scale) {
      ((AssetManager*)assetManager)->setScale(asset, scale);
  }

  void stop_animation(void* assetManager, EntityId asset, int index) {
      ((AssetManager*)assetManager)->stopAnimation(asset, index);
  }

  int hide_mesh(void* assetManager, EntityId asset, const char* meshName) {
      return ((AssetManager*)assetManager)->hide(asset, meshName);
  }

  int reveal_mesh(void* assetManager, EntityId asset, const char* meshName) {
      return ((AssetManager*)assetManager)->reveal(asset, meshName);
  }

  void ios_dummy() {
    Log("Dummy called");
  }
}

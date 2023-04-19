#include "ResourceBuffer.hpp"

#include "FilamentViewer.hpp"
#include "filament/LightManager.h"
#include "Log.hpp"

using namespace polyvox;

#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))

extern "C" {

  #include "PolyvoxFilamentApi.h"

  FLUTTER_PLUGIN_EXPORT void* create_filament_viewer(void* context, ResourceBuffer (*loadResource)(char const*), void (*freeResource)(unsigned int)) {
    FilamentViewer* v = new FilamentViewer(context, loadResource, freeResource);
    return (void*)v;
  }

  FLUTTER_PLUGIN_EXPORT void create_render_target(void* viewer, uint32_t textureId, uint32_t width, uint32_t height) {
    ((FilamentViewer*)viewer)->createRenderTarget(textureId, width, height);
  }
  
  FLUTTER_PLUGIN_EXPORT void delete_filament_viewer(void* viewer) {
    delete((FilamentViewer*)viewer);
  }

  FLUTTER_PLUGIN_EXPORT void set_background_color(void* viewer, const float r, const float g, const float b, const float a) {
    ((FilamentViewer*)viewer)->setBackgroundColor(r, g, b, a);
  }

  FLUTTER_PLUGIN_EXPORT void clear_background_image(void* viewer) {
    ((FilamentViewer*)viewer)->clearBackgroundImage();
  }

  FLUTTER_PLUGIN_EXPORT void set_background_image(void* viewer, const char* path) {
    ((FilamentViewer*)viewer)->setBackgroundImage(path);
  }

  FLUTTER_PLUGIN_EXPORT void set_background_image_position(void* viewer, float x, float y, bool clamp) {
  ((FilamentViewer*)viewer)->setBackgroundImagePosition(x, y, clamp);
  }

  FLUTTER_PLUGIN_EXPORT void load_skybox(void* viewer, const char* skyboxPath) {
    ((FilamentViewer*)viewer)->loadSkybox(skyboxPath);
  }

  FLUTTER_PLUGIN_EXPORT void load_ibl(void* viewer, const char* iblPath, float intensity) {
    ((FilamentViewer*)viewer)->loadIbl(iblPath, intensity);
  }

  FLUTTER_PLUGIN_EXPORT void remove_skybox(void* viewer) {
    ((FilamentViewer*)viewer)->removeSkybox();
  }
  
  FLUTTER_PLUGIN_EXPORT void remove_ibl(void* viewer) {
    ((FilamentViewer*)viewer)->removeIbl();
  }

  FLUTTER_PLUGIN_EXPORT int32_t add_light(void* viewer, uint8_t type, float colour, float intensity, float posX, float posY, float posZ, float dirX, float dirY, float dirZ, bool shadows) { 
    return ((FilamentViewer*)viewer)->addLight((LightManager::Type)type, colour, intensity, posX, posY, posZ, dirX, dirY, dirZ, shadows);
  }

  FLUTTER_PLUGIN_EXPORT void remove_light(void* viewer, int32_t entityId) {
    ((FilamentViewer*)viewer)->removeLight(entityId);
  }

  FLUTTER_PLUGIN_EXPORT void clear_lights(void* viewer) {
    ((FilamentViewer*)viewer)->clearLights();
  }

  FLUTTER_PLUGIN_EXPORT EntityId load_glb(void* assetManager, const char* assetPath, bool unlit) {
    return ((AssetManager*)assetManager)->loadGlb(assetPath, unlit);
  }

  FLUTTER_PLUGIN_EXPORT EntityId load_gltf(void* assetManager, const char* assetPath, const char* relativePath) {
    return ((AssetManager*)assetManager)->loadGltf(assetPath, relativePath);
  }

  FLUTTER_PLUGIN_EXPORT bool set_camera(void* viewer, EntityId asset, const char* nodeName) {
    return ((FilamentViewer*)viewer)->setCamera(asset, nodeName);
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_exposure(void* viewer, float aperture, float shutterSpeed, float sensitivity) {
    ((FilamentViewer*)viewer)->setCameraExposure(aperture, shutterSpeed, sensitivity);
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_position(void* viewer, float x, float y, float z) {
    ((FilamentViewer*)viewer)->setCameraPosition(x, y, z);
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_rotation(void* viewer, float rads, float x, float y, float z) {
    ((FilamentViewer*)viewer)->setCameraRotation(rads, x, y, z);
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_model_matrix(void* viewer, const float* const matrix) {
    ((FilamentViewer*)viewer)->setCameraModelMatrix(matrix);
  }

  FLUTTER_PLUGIN_EXPORT void set_camera_focal_length(void* viewer, float focalLength) {
    ((FilamentViewer*)viewer)->setCameraFocalLength(focalLength);
  }

  FLUTTER_PLUGIN_EXPORT void render(
    void* viewer,
    uint64_t frameTimeInNanos
  ) {
    ((FilamentViewer*)viewer)->render(frameTimeInNanos);
  }

  FLUTTER_PLUGIN_EXPORT void set_frame_interval(
    void* viewer,
    float frameInterval
  ) {
    ((FilamentViewer*)viewer)->setFrameInterval(frameInterval);
  }

  FLUTTER_PLUGIN_EXPORT void destroy_swap_chain(void* viewer) {
    ((FilamentViewer*)viewer)->destroySwapChain();
  }

  FLUTTER_PLUGIN_EXPORT void create_swap_chain(void* viewer, void* surface=nullptr, uint32_t width=0, uint32_t height=0) {
    ((FilamentViewer*)viewer)->createSwapChain(surface, width, height);
  }

  FLUTTER_PLUGIN_EXPORT void* get_renderer(void* viewer) {
    return ((FilamentViewer*)viewer)->getRenderer();
  }

  FLUTTER_PLUGIN_EXPORT void update_viewport_and_camera_projection(void* viewer, int width, int height, float scaleFactor) {
    return ((FilamentViewer*)viewer)->updateViewportAndCameraProjection(width, height, scaleFactor);
  }

  FLUTTER_PLUGIN_EXPORT void scroll_update(void* viewer, float x, float y, float delta) {
    ((FilamentViewer*)viewer)->scrollUpdate(x, y, delta);
  }

  FLUTTER_PLUGIN_EXPORT void scroll_begin(void* viewer) {
    ((FilamentViewer*)viewer)->scrollBegin();
  }

  FLUTTER_PLUGIN_EXPORT void scroll_end(void* viewer) {
    ((FilamentViewer*)viewer)->scrollEnd();
  }

  FLUTTER_PLUGIN_EXPORT void grab_begin(void* viewer, float x, float y, bool pan) {
    ((FilamentViewer*)viewer)->grabBegin(x, y, pan);
  }

  FLUTTER_PLUGIN_EXPORT void grab_update(void* viewer, float x, float y) {
    ((FilamentViewer*)viewer)->grabUpdate(x, y);
  }

  FLUTTER_PLUGIN_EXPORT void grab_end(void* viewer) {
    ((FilamentViewer*)viewer)->grabEnd();
  }

  FLUTTER_PLUGIN_EXPORT void* get_asset_manager(void* viewer) {
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

  FLUTTER_PLUGIN_EXPORT void set_morph_animation(
    void* assetManager,
    EntityId asset, 
    const char* const entityName,
    const float* const morphData,
    int numMorphWeights, 
    int numFrames, 
    float frameLengthInMs) {
    ((AssetManager*)assetManager)->setMorphAnimationBuffer(
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
    int length,
    const char** const boneNames,
    const char** const meshNames,
    const float* const frameData,
    int numFrames, 
    float frameLengthInMs) {
    ((AssetManager*)assetManager)->setBoneAnimationBuffer(
      asset, 
      length,
      boneNames, 
      meshNames,
      frameData,
      numFrames, 
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
    bool reverse) {
    ((AssetManager*)assetManager)->playAnimation(asset, index, loop, reverse);
  }

  FLUTTER_PLUGIN_EXPORT void set_animation_frame(
    void* assetManager,
    EntityId asset, 
    int animationIndex, 
    int animationFrame) {
    // ((AssetManager*)assetManager)->setAnimationFrame(asset, animationIndex, animationFrame);
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
    unique_ptr<vector<string>> names = ((AssetManager*)assetManager)->getMorphTargetNames(asset, meshName);
    return names->size();
  }

  FLUTTER_PLUGIN_EXPORT void get_morph_target_name(void* assetManager, EntityId asset, const char* meshName, char* const outPtr, int index ) {
    unique_ptr<vector<string>> names = ((AssetManager*)assetManager)->getMorphTargetNames(asset, meshName);
    string name = names->at(index);
    strcpy(outPtr, name.c_str());
  }

  FLUTTER_PLUGIN_EXPORT void remove_asset(void* viewer, EntityId asset) {
    ((FilamentViewer*)viewer)->removeAsset(asset);
  }

  FLUTTER_PLUGIN_EXPORT void clear_assets(void* viewer) {
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
  
}

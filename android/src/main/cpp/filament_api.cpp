#include "FilamentViewer.hpp"
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <android/native_window_jni.h>
#include <android/log.h>
#include <android/native_activity.h>

using namespace polyvox;
using namespace std;

static AAssetManager* am;

vector<AAsset*> _assets;
uint64_t id = -1;

static polyvox::ResourceBuffer loadResource(const char* name) {

    id++;
  
    AAsset *asset = AAssetManager_open(am, name, AASSET_MODE_BUFFER);
    if(asset == nullptr) {
      __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Couldn't locate asset [ %s ]", name);
      return polyvox::ResourceBuffer(nullptr, 0, 0);
    }
    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Loading asset [ %s ]", name);
    off_t length = AAsset_getLength(asset);
    const void * buffer = AAsset_getBuffer(asset);
    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Read [ %lu ] bytes into buffer", length);
    _assets.push_back(asset);
    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Loaded asset [ %s ] of length %zu", name, length);
    return ResourceBuffer(buffer, length, id);

}

static void freeResource(ResourceBuffer rb) {
  AAsset_close(_assets.at(rb.id));
}

extern "C" {

  void load_skybox(void* viewer, const char* skyboxPath, const char* iblPath) {
    ((FilamentViewer*)viewer)->loadSkybox(skyboxPath, iblPath, am);
  }

  void load_glb(void* viewer, const char* assetPath) {
    ((FilamentViewer*)viewer)->loadGlb(assetPath);
  }

  void load_gltf(void* viewer, const char* assetPath, const char* relativePath) {
    ((FilamentViewer*)viewer)->loadGltf(assetPath, relativePath);
  }

  bool set_camera(void* viewer, const char* nodeName) {
    return ((FilamentViewer*)viewer)->setCamera(nodeName);
  }

  void* filament_viewer_new(
    jobject surface,
    const char* opaqueShaderPath, 
    const char* fadeShaderPath,
    JNIEnv* env,
    jobject assetManager
  ) {
    ANativeWindow* layer = ANativeWindow_fromSurface(env, surface);
    am = AAssetManager_fromJava(env, assetManager);
    
    return new FilamentViewer((void*)layer, opaqueShaderPath, fadeShaderPath, loadResource, freeResource);
  }

  void render(
    void* viewer
  ) {
    ((FilamentViewer*)viewer)->render();
  }

  void destroy_swap_chain(void* viewer) {
    ((FilamentViewer*)viewer)->destroySwapChain();
  }

  void create_swap_chain(void* viewer, jobject surface, JNIEnv* env) {
    ANativeWindow* layer = ANativeWindow_fromSurface(env, surface);
    if(!layer) {
      __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Couldn't get native window from surface");     
      return;
    }
    ((FilamentViewer*)viewer)->createSwapChain(layer);
  }

  void* get_renderer(void* viewer) {
    return ((FilamentViewer*)viewer)->getRenderer();
  }

  void update_viewport_and_camera_projection(void* viewer, int width, int height, float scaleFactor) {
    return ((FilamentViewer*)viewer)->updateViewportAndCameraProjection(width, height, scaleFactor);
    
  }

  void scroll(void* viewer, float x, float y , float z) {
    return ((FilamentViewer*)viewer)->manipulator->scroll(x, y, z);
  }

  void grab_begin(void* viewer, int x, int y, bool pan) {
      __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Grab begin at %d %d %d", x, y, pan);     
    ((FilamentViewer*)viewer)->manipulator->grabBegin(x, y, pan);

  }

  void grab_update(void* viewer, int x, int y) {
    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Grab update at %d %d %d", x, y);     
    ((FilamentViewer*)viewer)->manipulator->grabUpdate(x, y);
  }

  void grab_end(void* viewer) {
    ((FilamentViewer*)viewer)->manipulator->grabEnd();
  }

  void apply_weights(void* viewer, float* weights, int count) {
    ((FilamentViewer*)viewer)->applyWeights(weights, count);
  }

  void animate_weights(void* viewer, float* data, int numWeights, int numFrames,  float frameRate) {
    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Animating %d frames, each with %d weights", numFrames, numWeights);     
    ((FilamentViewer*)viewer)->animateWeights((float*)data, numWeights, numFrames, frameRate);
  }

  void play_animation(void* viewer, int index) {
    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Playing embedded animation %d", index);     
    ((FilamentViewer*)viewer)->playAnimation(index);
  }

  char** get_animation_names(void* viewer, int* countPtr) {
    auto names = ((FilamentViewer*)viewer)->getAnimationNames();
    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Got %d animation names", names->size());     
    char** names_c;
    names_c = new char*[names->size()];
    for(int i = 0; i < names->size(); i++) {
      names_c[i] = (char*) names->at(i).c_str();
      __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Alloced animation name %s ", (char*) names->at(i).c_str());     
    }
    (*countPtr) = names->size();
    return names_c;
  }

  char** get_target_names(void* viewer, char* meshName, int* countPtr ) {
    StringList names = ((FilamentViewer*)viewer)->getTargetNames(meshName);

    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Got %d names", names.count);     
         
    *countPtr = names.count;

    char** retval;
    retval = new char*[names.count];

    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Allocated char* array of size %d", names.count);     

    for(int i =0; i < names.count; i++) {
      retval[i] = (char*)names.strings[i];  
    }
    return retval;
  }

  void free_pointer(char** ptr, int num) {
    free(ptr);
  }

  void release_source_assets(void* viewer) {
    ((FilamentViewer*)viewer)->releaseSourceAssets();
  }
  
}

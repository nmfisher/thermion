#include "FilamentViewer.hpp"
#include "SceneAsset.hpp"
#include "ResourceBuffer.hpp"
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <android/native_window_jni.h>
#include <android/log.h>
#include <android/native_activity.h>

using namespace polyvox;
using namespace std;

static AAssetManager* am;
static vector<AAsset*> _assets;
uint64_t id = -1;

static ResourceBuffer loadResource(const char* name) {

    id++;
  
    AAsset *asset = AAssetManager_open(am, name, AASSET_MODE_BUFFER);
    if(asset == nullptr) {
      __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Couldn't locate asset [ %s ]", name);
      return ResourceBuffer(nullptr, 0, 0);
    }
    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Loading asset [ %s ]", name);
    off_t length = AAsset_getLength(asset);
    const void * buffer = AAsset_getBuffer(asset);

    uint8_t *buf = new uint8_t[length ];
    memcpy(buf,buffer,  length);
    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Read [ %lu ] bytes into buffer", length);
    _assets.push_back(asset);
    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Loaded asset [ %s ] of length %zu", name, length);
    return ResourceBuffer(buf, length, id);

}

static void freeResource(uint32_t id) {
  __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Freeing loaded resource at index [ %d ] ", id);
  AAsset* asset = _assets[id];
  if(asset) {
    AAsset_close(asset);
  } else {
    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Attempting to free resource at index [ %d ] that has already been released.", id);
  }
  _assets[id] = nullptr;
}

extern "C" {

  void* filament_viewer_new_android(
    jobject surface,
    JNIEnv* env,
    jobject assetManager
  ) {
    ANativeWindow* layer = ANativeWindow_fromSurface(env, surface);
    am = AAssetManager_fromJava(env, assetManager);
    return new FilamentViewer((void*)layer, loadResource, freeResource);
  }



  
}

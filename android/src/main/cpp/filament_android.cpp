#include "FilamentViewer.hpp"
#include "SceneAsset.hpp"
#include "ResourceBuffer.hpp"
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <android/native_window_jni.h>
#include <android/log.h>
#include <android/native_activity.h>

#include <map>

using namespace polyvox;
using namespace std;

static AAssetManager* am;
static map<uint32_t, AAsset*> _apk_assets;
static map<uint32_t, void*> _file_assets;
static uint32_t _i = 0;

static ResourceBuffer loadResource(const char* name) {


    string name_str(name);
    auto id = _i++;
    
    if (name_str.rfind("file://", 0) == 0) {
      streampos length;
      ifstream is(name_str.substr(7), ios::binary);
      is.seekg (0, ios::end);
      length = is.tellg();
      char * buffer;
      buffer = new char [length];
      is.seekg (0, ios::beg);
      is.read (buffer, length);
      is.close();      
      _file_assets[id] = buffer;
      return ResourceBuffer(buffer, length, id);
    } else {
      AAsset *asset = AAssetManager_open(am, name, AASSET_MODE_BUFFER);
      if(asset == nullptr) {
        __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Couldn't locate asset [ %s ]", name);
        return ResourceBuffer(nullptr, 0, 0);
      }
      __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Loading asset [ %s ]", name);

      off_t length = AAsset_getLength(asset);
      const void * buffer = AAsset_getBuffer(asset);

      __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Read [ %lu ] bytes into buffer", length);
      
      _apk_assets[id] = asset;
      __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Loaded asset [ %s ] of length %zu at index %d", name, length, id);
      return ResourceBuffer(buffer, length, id);
    }
}

static void freeResource(uint32_t id) {
  __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Freeing loaded resource at index [ %d ] ", id);
  auto apk_it = _apk_assets.find(id);
  if (apk_it != _apk_assets.end()) {
    AAsset_close(apk_it->second);
    __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Closed Android asset");
  } else {
    auto file_it = _file_assets.find(id);
    if (file_it != _file_assets.end()) {
      free(file_it->second);
      __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "Freed asset from filesystem.");
    } else {
      __android_log_print(ANDROID_LOG_VERBOSE, "filament_api", "FATAL - could not find Android or filesystem (hot reload) asset under id %d", id);
    }
  }

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

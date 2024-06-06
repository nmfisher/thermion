#include <android/native_window_jni.h>
#include <android/native_activity.h>

#include "DartFilamentFFIApi.h"

extern "C" {
  void* get_native_window_from_surface(
    jobject surface,
    JNIEnv* env
  ) {
    void* window = ANativeWindow_fromSurface(env, surface);
    return window;
  }

  ResourceLoaderWrapper* make_resource_loader_wrapper_android(LoadFilamentResourceFromOwner loadFn, FreeFilamentResourceFromOwner freeFn, void* owner) {
    ResourceLoaderWrapper *rlw = (ResourceLoaderWrapper *)malloc(sizeof(ResourceLoaderWrapper));
    rlw->loadToOut = nullptr;
    rlw->freeResource = nullptr;
    rlw->loadResource = nullptr;
    rlw->loadFromOwner = loadFn;
    rlw->freeFromOwner = freeFn;
    rlw->owner = owner;
    return rlw;
  }

  // this does nothing, but we need it for JNA to return the correct pointer 
  FilamentRenderCallback make_render_callback_fn_pointer(FilamentRenderCallback callback) {
    return callback;
  }
  
}

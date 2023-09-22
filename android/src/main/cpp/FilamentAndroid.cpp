#include <android/native_window_jni.h>
#include <android/native_activity.h>

extern "C" {

  #include "PolyvoxFilamentApi.h"

  const void* create_filament_viewer_android(
          jobject surface, JNIEnv* env, ResourceLoaderWrapper* loaderWrapper
          ) {
    ANativeWindow* window = ANativeWindow_fromSurface(env, surface);
    return create_filament_viewer(window,loaderWrapper);
  }

  void create_swap_chain_android(
    const void* const viewer,
    jobject surface,
    JNIEnv* env,
    uint32_t width,
    uint32_t height
  ) {
    ANativeWindow* window = ANativeWindow_fromSurface(env, surface);
    create_swap_chain(viewer, window, width, height);
  }
  
}

#include <android/native_window_jni.h>
#include <android/native_activity.h>

extern "C" {

  #include "FlutterFilamentFFIApi.h"

  void* get_native_window_from_surface(
    jobject surface,
    JNIEnv* env
  ) {
    void* window = ANativeWindow_fromSurface(env, surface);
    return window;
  }

  // this does nothing, but we need it for JNA to return the correct pointer 
  FilamentRenderCallback make_render_callback_fn_pointer(FilamentRenderCallback callback) {
    return callback;
  }
  
}

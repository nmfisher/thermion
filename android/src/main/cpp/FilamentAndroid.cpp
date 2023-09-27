#include <android/native_window_jni.h>
#include <android/native_activity.h>

extern "C" {

  void* get_native_window_from_surface(
    jobject surface,
    JNIEnv* env
  ) {
    return ANativeWindow_fromSurface(env, surface);
  }
  
}
